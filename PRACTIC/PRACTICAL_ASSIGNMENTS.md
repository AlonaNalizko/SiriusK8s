# Практические задания: Kubernetes для DevOps

## Введение

**Требуемое ПО:**
- Linux хост (Ubuntu 20.04+) или WSL2
- Docker (20.10+)
- Kubernetes (1.24+) кластер или minikube/kind
- kubectl, kubeadm, kubelet
- Git, curl, vim/nano
- trivy, helm (опционально)

---

## БЛОК 1: КОНТЕЙНЕРЫ 

### Задание 1.1: Создание контейнера с нуля (без Docker) — понимание Linux namespaces и cgroups

**Цель:** Разобраться в том, как Docker работает "под капотом", создав изолированное окружение вручную с помощью Linux primitives.

**Описание задания:**

Вместо использования Docker создадим контейнер вручную, используя:
- **Namespaces** (PID, Network, Mount, UTS, IPC) для логической изоляции
- **cgroups** для ограничения ресурсов
- **chroot** для изоляции файловой системы

Контейнер — это не виртуальная машина, а процесс с ограничениями на уровне ОС.

**Пошаговые инструкции:**

1. **Подготовка базовой файловой системы:**

```bash
# Создаём директорию для контейнера
sudo mkdir -p /containers/manual-container/rootfs
cd /containers/manual-container

# Копируем минимальное окружение (busybox или alpine)
sudo apt-get install -y busybox-static

# Создаём базовую FS
sudo mkdir -p rootfs/bin rootfs/sbin rootfs/lib rootfs/etc rootfs/dev rootfs/proc rootfs/sys
sudo cp /bin/busybox rootfs/bin/
sudo cp /bin/sh rootfs/bin/

# Создаём необходимые device файлы
sudo mknod -m 666 rootfs/dev/null c 1 3
sudo mknod -m 666 rootfs/dev/zero c 1 5
sudo mknod -m 666 rootfs/dev/full c 1 7
sudo mknod -m 644 rootfs/dev/random c 1 8
sudo mknod -m 644 rootfs/dev/urandom c 1 9
sudo mknod -m 666 rootfs/dev/tty c 5 0
sudo mknod -m 666 rootfs/dev/console c 5 1
```

2. **Создание PID namespace изолированного процесса:**

```bash
# Создаём простой скрипт для запуска контейнера
cat > /tmp/run_container.sh << 'EOF'
#!/bin/bash
# Запуск процесса в новых namespaces
sudo unshare \
  --pid --uts --ipc --mount --net \
  --root=/containers/manual-container/rootfs \
  /bin/sh
EOF

chmod +x /tmp/run_container.sh
```

3. **Добавление cgroups для ограничения памяти:**

```bash
# Создаём cgroup для контейнера
sudo cgcreate -g memory:/container_group
sudo cgset -r memory.limit_in_bytes=104857600 /container_group  # 100MB

# Запуск процесса в cgroup
sudo cgexec -g memory:/container_group unshare \
  --pid --uts --ipc --mount \
  --root=/containers/manual-container/rootfs \
  /bin/sh
```

4. **Внутри контейнера проверяем изоляцию:**

```bash
# Команды для выполнения ВНУТРИ контейнера
ps aux          # Видим только процессы контейнера
hostname        # Можно изменить имя контейнера
ip addr         # Видим только сетевые интерфейсы этого namespace
df -h           # Видим файловую систему контейнера
cat /proc/meminfo
```

5. **Из хоста проверяем процессы:**

```bash
# В другом терминале на хосте:
ps aux | grep unshare
# Видим процесс контейнера с отдельным PID в host namespace
```

**Критерии оценки:**
- [ ] Успешно создана изолированная файловая система с busybox
- [ ] PID namespace работает (ps aux показывает только процессы контейнера)
- [ ] Memory cgroup применяется (можно запустить `stress` и проверить ограничение)
- [ ] Имя хоста отличается в контейнере
- [ ] Процесс контейнера виден из host namespace с другим PID

**Подсказки для troubleshooting:**

- **Ошибка "unshare: failed to execute /bin/sh"**: Проверьте, что все файлы скопированы в rootfs, включая зависимости динамических библиотек
  ```bash
  ldd /bin/sh  # Проверить зависимости
  # Скопировать необходимые .so файлы в rootfs/lib
  ```

- **Сетевой интерфейс не видно**: Network namespace создан, но виртуальные интерфейсы не соединены. Это нормально для первого упражнения.

- **cgroups не работают**: Проверьте, что cgroup2 или cgroupsv1 смонтированы:
  ```bash
  mount | grep cgroup
  cat /proc/cgroups
  ```

---

### Задание 1.2: Оптимальный Dockerfile с multistage build

**Цель:** Научиться писать эффективные Dockerfile с минимизацией размера образа и количества слоёв.

**Описание задания:**

Создадим два образа для одного приложения (Python и Go) — сначала неоптимизированный, затем с использованием multistage build.

**Пошаговые инструкции:**

1. **Python приложение (FastAPI):**

```bash
mkdir -p /tmp/docker-practice/python-app
cd /tmp/docker-practice/python-app

cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.5.0
EOF

cat > app.py << 'EOF'
from fastapi import FastAPI
app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/hello/{name}")
def hello(name: str):
    return {"message": f"Hello {name}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
```

2. **Неоптимальный Dockerfile (для сравнения):**

```bash
cat > Dockerfile.bad << 'EOF'
FROM python:3.11

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt
COPY app.py .

ENV PYTHONUNBUFFERED=1

EXPOSE 8000
CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0"]
EOF

# Сборка
docker build -f Dockerfile.bad -t python-app:bad .
docker images | grep python-app  # Посмотреть размер (в несколько сотен МБ)
```

3. **Оптимальный Dockerfile с multistage build:**

```bash
cat > Dockerfile << 'EOF'
# Stage 1: Builder
FROM python:3.11-slim as builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY app.py .

ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER nobody
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app:app", "--host", "0.0.0.0"]
EOF

# Сборка оптимального образа
docker build -t python-app:optimized .
docker images | grep python-app  # Проверить размер (должен быть меньше)
```

4. **Go приложение:**

```bash
mkdir -p /tmp/docker-practice/go-app
cd /tmp/docker-practice/go-app

cat > main.go << 'EOF'
package main

import (
    "fmt"
    "net/http"
)

func health(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, `{"status":"ok"}`)
}

func hello(w http.ResponseWriter, r *http.Request) {
    name := r.URL.Query().Get("name")
    fmt.Fprintf(w, `{"message":"Hello %s"}`, name)
}

func main() {
    http.HandleFunc("/health", health)
    http.HandleFunc("/hello", hello)
    http.ListenAndServe(":8000", nil)
}
EOF

cat > Dockerfile << 'EOF'
# Stage 1: Builder
FROM golang:1.21-alpine as builder

WORKDIR /app
COPY main.go .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o app main.go

# Stage 2: Runtime
FROM alpine:3.18

RUN adduser -D -u 65534 nobody

WORKDIR /app
COPY --from=builder /app/app .

USER nobody
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

CMD ["./app"]
EOF

docker build -t go-app:optimized .
docker images | grep go-app
```

5. **Сравнение размеров:**

```bash
docker images | grep -E "python-app|go-app"

# Вывод должен быть примерно:
# python-app    bad          XXXMB
# python-app    optimized    ~300MB
# go-app        optimized    ~50MB
```

**Критерии оценки:**
- [ ] Неоптимальный образ Python больше, чем оптимальный
- [ ] Multistage build использует минимум 2 stage (builder и runtime)
- [ ] Промежуточные слои не включены в финальный образ (проверка через `docker history`)
- [ ] Go образ значительно меньше Python образа
- [ ] Оба образа содержат HEALTHCHECK
- [ ] Оба образа запускают процесс от непривилегированного пользователя

**Подсказки для troubleshooting:**

- **Python образ всё ещё большой**: Убедитесь, что используется `slim` или `alpine` базовый образ, не просто `python:3.11`
  ```bash
  docker image inspect python-app:optimized | grep -A5 "RootFS"
  ```

- **Go приложение не компилируется**: Проверьте версию Go и синтаксис флагов:
  ```bash
  go version
  CGO_ENABLED=0 GOOS=linux go build -help
  ```

---

### Задание 1.3: Сканирование образов на уязвимости (Trivy)

**Цель:** Научиться находить и анализировать CVE уязвимости в Docker образах.

**Описание задания:**

Установим Trivy и просканируем созданные образы на уязвимости, а затем создадим образ с исправленными версиями зависимостей.

**Пошаговые инструкции:**

1. **Установка Trivy:**

```bash
# Скачиваем и устанавливаем
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

trivy version
```

2. **Сканирование созданных образов:**

```bash
# Сканируем Python образ
trivy image python-app:optimized

# Вывод должен быть примерно:
# Total: X vulnerabilities (Y CRITICAL, Z HIGH, ...)
# Layer: sha256:...
```

3. **Детальное сканирование с форматом JSON:**

```bash
trivy image --format json --output scan-report.json python-app:optimized

# Просмотр результатов
cat scan-report.json | jq '.Results[] | select(.Severity=="CRITICAL")'
```

4. **Создание образа с обновлёнными зависимостями:**

```bash
cd /tmp/docker-practice/python-app

cat > requirements-locked.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.5.0
EOF

cat > Dockerfile.secure << 'EOF'
FROM python:3.11-slim

RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements-locked.txt .
RUN pip install --user --no-cache-dir -r requirements-locked.txt

COPY app.py .

ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

USER nobody
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0"]
EOF

docker build -f Dockerfile.secure -t python-app:secure .
```

5. **Повторное сканирование:**

```bash
trivy image python-app:secure

# Сравнение с предыдущим результатом
trivy image --severity CRITICAL,HIGH python-app:optimized
trivy image --severity CRITICAL,HIGH python-app:secure
```

6. **Политика сканирования (опционально):**

```bash
# Игнорирование известных false-positive
cat > .trivyignore << 'EOF'
# CVE-2021-12345  # Причина: не влияет на наше приложение
EOF

trivy image --ignorefile .trivyignore python-app:optimized
```

**Критерии оценки:**
- [ ] Trivy установлен и работает
- [ ] Сканирование успешно выполняется для обоих образов
- [ ] JSON отчёт генерируется и содержит информацию о CVE
- [ ] Обновлённый образ имеет меньше или равное количество уязвимостей
- [ ] Фильтрация по severity работает
- [ ] .trivyignore файл создан и использован

**Подсказки для troubleshooting:**

- **Trivy не найден в PATH**: Убедитесь, что установка завершена:
  ```bash
  which trivy
  /usr/local/bin/trivy version
  ```

- **Сканирование занимает слишком долго**: Первый запуск загружает базу CVE. Последующие будут быстрее. Можно использовать кэш:
  ```bash
  trivy image --skip-db-update python-app:optimized
  ```

- **Много UNKNOWN уязвимостей**: Это нормально для alpine образов. Проверьте только CRITICAL и HIGH:
  ```bash
  trivy image --severity CRITICAL,HIGH python-app:optimized
  ```

---

## БЛОК 2: РАЗВЁРТЫВАНИЕ КЛАСТЕРА K8S (2 часа)

### Задание 2.1: Установка кластера Kubernetes через kubeadm

**Цель:** Развернуть production-like Kubernetes кластер с одним master и двумя worker нодами.

**Описание задания:**

Установим K8s кластер с нуля на трёх виртуальных машинах (или контейнерах) используя kubeadm. Это даст понимание архитектуры K8s и процесса инициализации.

**Требования к окружению:**

- 3 ВМ (или bare metal): master (2CPU, 2GB RAM), worker1 (2CPU, 2GB), worker2 (2CPU, 2GB)
- Ubuntu 20.04 LTS или новее
- Docker или containerd установлены
- Сетевой доступ между ВМ

**Альтернатива для локальной работы:** Используйте `kind` или `minikube` с этими же инструкциями (адаптированными).

**Пошаговые инструкции:**

1. **На всех нодах: подготовка системы:**

```bash
# Обновляем систему (на всех трёх машинах)
sudo apt-get update
sudo apt-get upgrade -y

# Отключаем swap (K8s требует это)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Включаем модули ядра для networking
cat << EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Сетевые параметры
cat << EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

2. **Установка Docker (на всех нодах):**

```bash
# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавляем текущего пользователя в группу docker
sudo usermod -aG docker $USER

# Проверяем
docker --version
docker run hello-world
```

3. **Установка kubeadm, kubelet, kubectl (на всех нодах):**

```bash
# Добавляем репозиторий K8s
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Устанавливаем K8s компоненты
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Зависит версия версии (например 1.27.x)
# sudo apt-get install -y kubelet=1.27.0-00 kubeadm=1.27.0-00 kubectl=1.27.0-00

sudo apt-mark hold kubelet kubeadm kubectl

# Проверяем версии
kubeadm version
kubelet --version
kubectl version --client
```

4. **Инициализация Master ноды:**

```bash
# На MASTER машине:
# Получаем IP адрес master (например 192.168.1.10)
hostname -I

# Инициализируем кластер
sudo kubeadm init \
  --apiserver-advertise-address=192.168.1.10 \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=stable-1

# Вывод будет содержать команду для join worker нод (СОХРАНИТЕ ЭТО!)
# Например: kubeadm join 192.168.1.10:6443 --token ... --discovery-token-ca-cert-hash ...
```

5. **Настройка kubeconfig (на master):**

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Проверяем
kubectl get nodes  # Должен показать master в статусе NotReady (без CNI)
```

6. **Установка CNI — Flannel:**

```bash
# На master:
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Ждём пока Flannel pods запустятся
kubectl get pods -n kube-flannel --watch

# После этого master должен перейти в Ready
kubectl get nodes  # Status should be "Ready"
```

7. **Присоединение Worker нод:**

```bash
# На каждой worker машине выполняем команду из пункта 4:
sudo kubeadm join 192.168.1.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Проверяем на master:
kubectl get nodes  # Должны показаться все 3 ноды в Ready
```

8. **Финальная проверка:**

```bash
# На master:
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl cluster-info

# Должны увидеть:
# - 3 ноды в статусе Ready
# - kube-system pods запущены
# - flannel pods в каждом node
```

**Критерии оценки:**
- [ ] 3 ноды в кластере с статусом Ready
- [ ] `kubectl get nodes` показывает все ноды
- [ ] Все pods в kube-system namespace Running
- [ ] kubeconfig сконфигурирован и работает без sudo
- [ ] Flannel (или другой CNI) установлен
- [ ] Можно запустить простой контейнер: `kubectl run nginx --image=nginx`

**Подсказки для troubleshooting:**

- **Master в статусе NotReady**: Ждите, пока установится CNI плагин
  ```bash
  kubectl get pods -n kube-flannel
  kubectl logs -n kube-flannel <pod-name>
  ```

- **kubeadm join не работает**: Проверьте token на master:
  ```bash
  kubeadm token list
  kubeadm token create --print-join-command
  ```

- **Сетевые проблемы между нодами**: Проверьте firewall и маршруты:
  ```bash
  sudo iptables -L -n
  ip route
  ping <other-node-ip>
  ```

---

### Задание 2.2: Установка CNI и проверка сетевого взаимодействия

**Цель:** Разобраться в том, как работает сетевое взаимодействие в K8s и конфигурировать различные CNI плагины.

**Описание задания:**

Установим несколько CNI плагинов (Flannel, Calico), поймём их различия и проверим сетевую связность.

**Пошаговые инструкции:**

1. **Если Flannel уже установлен — удалим для чистого примера:**

```bash
kubectl delete -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl get pods -n kube-flannel --watch  # Ждём удаления
```

2. **Установка Calico (альтернатива Flannel с NetworkPolicy):**

```bash
# Скачиваем манифесты Calico
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml -o tigera-operator.yaml

# Устанавливаем operator
kubectl apply -f tigera-operator.yaml

# Проверяем установку
kubectl get pods -n tigera-operator --watch

# Создаём Calico Installation манифест
cat << 'EOF' | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - name: default-ipv4-ippool
      blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: vxlan
      natOutgoing: Enabled
EOF

# Ждём пока ноды перейдут в Ready
kubectl get nodes --watch
```

3. **Проверка сетевых параметров:**

```bash
# На каждой ноде проверяем IP адреса
kubectl get nodes -o wide

# На worker ноде проверяем IP адреса интерфейсов
ip addr show
ip route show

# Проверяем tunl0 интерфейс (для vxlan)
ip link show
```

4. **Тестирование сетевой связности между pods:**

```bash
# Запускаем test pods в разных нодах
kubectl run test-pod-1 --image=nicolaka/netshoot -it -- bash
# (В другом терминале)
kubectl run test-pod-2 --image=nicolaka/netshoot -it -- bash

# Внутри первого pod:
kubectl exec -it test-pod-1 -- ping test-pod-2
kubectl exec -it test-pod-1 -- nslookup test-pod-2

# Должна быть связность между pods на разных нодах
```

5. **Проверка DNS разрешения:**

```bash
# Запускаем pod и проверяем DNS
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Внутри pod:
nslookup kubernetes.default
nslookup kube-dns.kube-system

# Проверяем /etc/resolv.conf
cat /etc/resolv.conf
```

6. **Сравнение CNI плагинов (таблица в конце задания):**

```bash
# Информация о установленном CNI
kubectl get daemonset -n kube-system
kubectl logs -n kube-system <cni-pod> --tail=50
```

**Таблица сравнения CNI плагинов:**

| Параметр | Flannel | Calico | Cilium |
|----------|---------|--------|--------|
| **Сложность** | Простой | Средняя | Сложная |
| **Performance** | Хороший | Отличный | Отличный |
| **NetworkPolicy** | Нет | Да | Да |
| **eBPF** | Нет | Опционально | Да (core) |
| **Encapsulation** | VXLAN/UDP | VXLAN/IPIP | Нативный |
| **Production Ready** | Да | Да | Да |

**Критерии оценки:**
- [ ] CNI плагин успешно установлен (Flannel или Calico)
- [ ] Все ноды в статусе Ready
- [ ] Pods могут коммуницировать между нодами
- [ ] DNS разрешение работает для pods
- [ ] Можно проверить logs CNI daemon set
- [ ] Понимание различий между плагинами

**Подсказки для troubleshooting:**

- **Ноды остаются в NotReady**: Проверьте лог kubelet:
  ```bash
  sudo journalctl -u kubelet -n 50
  ```

- **Pods не видят друг друга**: Проверьте сетевые политики и firewall:
  ```bash
  kubectl get networkpolicies --all-namespaces
  sudo iptables -L -n | grep FORWARD
  ```

- **Calico pods не запускаются**: Проверьте логи оператора:
  ```bash
  kubectl logs -n tigera-operator <pod-name>
  kubectl describe pod -n tigera-operator <pod-name>
  ```

---

### Задание 2.3: Диагностика и troubleshooting кластера

**Цель:** Научиться диагностировать и исправлять типичные проблемы в K8s кластере.

**Описание задания:**

Сценарии диагностики и исправления проблем, которые встречаются на production системах.

**Пошаговые инструкции:**

1. **Сценарий 1: Pod не запускается**

```bash
# Создаём pod с ошибкой
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
spec:
  containers:
  - name: app
    image: ubuntu:20.04
    command: ["sh", "-c", "sleep 1 && exit 1"]
EOF

# Диагностирование
kubectl get pods  # Статус CrashLoopBackOff
kubectl describe pod broken-pod
kubectl logs broken-pod  # Пусто или ошибка
kubectl logs broken-pod --previous  # Логи предыдущего контейнера

# Исправление
kubectl delete pod broken-pod
```

2. **Сценарий 2: Недостаточно ресурсов**

```bash
# Создаём pod с большим request
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-hog
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "10Gi"
        cpu: "100"
EOF

# Диагностирование
kubectl describe pod resource-hog  # Status: Pending
kubectl describe node worker1  # Allocated Resources

# Исправление
kubectl delete pod resource-hog

# Смотрим доступные ресурсы
kubectl top nodes
kubectl top pods --all-namespaces
```

3. **Сценарий 3: Проблемы с сетевой связностью**

```bash
# Проверяем кластерную сеть
kubectl get nodes -o wide
kubectl get pods -o wide --all-namespaces

# Диагностирование на ноде
ssh worker1

# На ноде:
docker ps  # Видим контейнеры pods
ip netns list  # Видим network namespaces
ip netns exec <namespace> ip addr  # IP адреса внутри pod

# Проверяем маршруты
ip route show
sudo iptables -t filter -L -n | head -30
```

4. **Сценарий 4: Проблемы с волюмами**

```bash
# Создаём pod с несуществующим волюмом
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: volume-error
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: non-existent-pvc
EOF

# Диагностирование
kubectl describe pod volume-error
kubectl get pvc  # PVC не существует

# Проверяем доступные storage classes
kubectl get storageclass
kubectl get pv

# Исправление
kubectl delete pod volume-error
```

5. **Сценарий 5: Проблемы с RBAC доступом**

```bash
# Создаём сервис аккаунт без прав
kubectl create serviceaccount limited-user
kubectl create rolebinding limited-role --clusterrole=view --serviceaccount=default:limited-user

# Проверяем права
kubectl auth can-i get pods --as=system:serviceaccount:default:limited-user
kubectl auth can-i create pods --as=system:serviceaccount:default:limited-user  # Должен быть no

# Добавляем права
kubectl create rolebinding edit-role --clusterrole=edit --serviceaccount=default:limited-user
kubectl auth can-i create pods --as=system:serviceaccount:default:limited-user  # Должен быть yes
```

6. **Сценарий 6: API Server недоступен**

```bash
# Проверяем состояние компонентов
kubectl get componentstatuses
kubectl get nodes

# Если API недоступен, смотрим логи на master
ssh master
sudo journalctl -u kubelet -n 100
docker logs <api-server-container>

# Проверяем сертификаты (часто истекают)
sudo kubeadm certs check-expiration
sudo kubeadm certs renew all  # Если нужно продлить
```

7. **Утилита для диагностики — kubectl-debug:**

```bash
# Установка (опционально)
kubectl krew install debug

# Подключение к работающему pod'у для отладки
kubectl debug -it <pod-name> --image=nicolaka/netshoot -- bash

# Это создаёт ephemeral container в pod'е
```

**Критерии оценки:**
- [ ] Успешно диагностированы все 6 сценариев
- [ ] Использованы kubectl describe, logs, top команды
- [ ] Смотрели статус компонентов кластера
- [ ] Проверили ресурсы на нодах
- [ ] Успешно исправлены все проблемы

**Подсказки для troubleshooting:**

- **Не видны логи pod'а**: Проверьте, есть ли контейнер вообще:
  ```bash
  kubectl get pod -o jsonpath='{.status.containerStatuses}' <pod-name>
  ```

- **Ноды недоступны**: Проверьте сетевую связность:
  ```bash
  ping <node-ip>
  ssh -v <node>
  sudo systemctl status kubelet
  ```

- **Неустранимые ошибки**: Пересоздайте кластер через kubeadm:
  ```bash
  sudo kubeadm reset
  # Заново инициализируем
  ```

---

## БЛОК 3: ДЕПЛОЙ ПРИЛОЖЕНИЙ (2 часа)

### Задание 3.1: Deployment + Service + Ingress для stateless приложения

**Цель:** Развернуть полноценное приложение с автоматическим масштабированием и внешним доступом.

**Описание задания:**

Создадим многоэкземплярное приложение (nginx с custom HTML), настроим Service для внутреннего доступа и Ingress для внешнего.

**Пошаговые инструкции:**

1. **Создание Deployment с replicas:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: web-html
EOF

# Проверяем статус
kubectl get deployment web-app
kubectl get pods -l app=web-app
```

2. **Создание ConfigMap для HTML:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>K8s Web App</title></head>
    <body>
    <h1>Hello from Kubernetes!</h1>
    <p>Pod: $(hostname)</p>
    <p>Date: $(date)</p>
    </body>
    </html>
EOF
```

3. **Создание ClusterIP Service для внутреннего доступа:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: web-app
EOF

# Проверяем Service
kubectl get service web-service
kubectl describe service web-service

# Тестируем доступ из pod'а
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- curl http://web-service

# Проверяем load balancing (разные pod'ы)
for i in {1..5}; do kubectl run -it --rm debug-$i --image=nicolaka/netshoot --restart=Never -- curl http://web-service; done
```

4. **Создание NodePort Service (опционально):**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  selector:
    app: web-app
EOF

# Тестируем доступ через NodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl http://$NODE_IP:30080
```

5. **Установка Ingress Controller (Nginx):**

```bash
# Установка через Helm (если доступен) или манифесты
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.0/deploy/static/provider/cloud/deploy.yaml

# Ждём пока Ingress Controller запустится
kubectl get pods -n ingress-nginx --watch
```

6. **Создание Ingress ресурса:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
EOF

# Получаем Ingress IP
kubectl get ingress web-ingress
kubectl describe ingress web-ingress

# Для локального тестирования добавляем в /etc/hosts:
# <ingress-ip> example.local

# Тестируем доступ
curl http://example.local
```

7. **Горизонтальное масштабирование вручную:**

```bash
# Увеличиваем replicas
kubectl scale deployment web-app --replicas=5
kubectl get pods -l app=web-app

# Уменьшаем replicas
kubectl scale deployment web-app --replicas=2
kubectl get pods -l app=web-app
```

**Критерии оценки:**
- [ ] Deployment создан с 3+ replicas
- [ ] Все pods Running и Ready
- [ ] ClusterIP Service доступен из других pods
- [ ] Ingress настроен и работает
- [ ] Load balancing распределяет запросы между pods
- [ ] Масштабирование работает

**Подсказки для troubleshooting:**

- **Ingress не получает IP**: Проверьте, установлен ли Ingress Controller:
  ```bash
  kubectl get ingressclass
  kubectl get pods -n ingress-nginx
  ```

- **Service не балансирует**: Проверьте endpoints:
  ```bash
  kubectl get endpoints web-service
  kubectl describe service web-service
  ```

---

### Задание 3.2: StatefulSet для PostgreSQL с PVC

**Цель:** Развернуть stateful приложение с постоянным хранилищем данных.

**Описание задания:**

Создадим PostgreSQL базу через StatefulSet с PersistentVolumeClaim для хранения данных.

**Пошаговые инструкции:**

1. **Создание PersistentVolume (если нет динамического provisioning):**

```bash
# Проверяем доступные storage classes
kubectl get storageclass

# Если необходимо, создаём местное PV (для dev/test)
mkdir -p /mnt/k8s-volumes/{postgres-0,postgres-1,postgres-2}

cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-0
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/k8s-volumes/postgres-0
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-1
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/k8s-volumes/postgres-1
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-2
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/k8s-volumes/postgres-2
EOF

kubectl get pv
```

2. **Создание Secret для PostgreSQL пароля:**

```bash
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD=secretpassword123

# Или в манифесте:
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  POSTGRES_PASSWORD: secretpassword123
EOF
```

3. **Создание Service для StatefulSet:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  clusterIP: None  # Headless service для StatefulSet
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgres
EOF
```

4. **Создание StatefulSet:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_USER
          value: "dbuser"
        - name: POSTGRES_DB
          value: "appdb"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U dbuser
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U dbuser
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
EOF

# Проверяем статус
kubectl get statefulset postgres
kubectl get pods -l app=postgres
kubectl get pvc
```

5. **Подключение к БД и создание таблицы:**

```bash
# Подключаемся к pod'у
kubectl exec -it postgres-0 -- psql -U dbuser -d appdb

# Внутри psql:
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100) UNIQUE
);

INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com');

SELECT * FROM users;

\q  # Выход
```

6. **Проверка персистентности данных:**

```bash
# Удаляем pod (StatefulSet пересоздаст его)
kubectl delete pod postgres-0

# Ждём пока pod перезагрузится
kubectl get pods -l app=postgres --watch

# Подключаемся снова и проверяем данные
kubectl exec -it postgres-0 -- psql -U dbuser -d appdb -c "SELECT * FROM users;"

# Данные должны остаться!
```

7. **Масштабирование StatefulSet:**

```bash
# Увеличиваем replicas (создаст postgres-1, postgres-2 с отдельными PVC)
kubectl scale statefulset postgres --replicas=3
kubectl get pods
kubectl get pvc

# Уменьшаем (удалит postgres-2, postgres-1 но сохранит данные в PVC)
kubectl scale statefulset postgres --replicas=1
```

**Критерии оценки:**
- [ ] StatefulSet создан успешно
- [ ] Pod postgres-0 в статусе Running
- [ ] PVC создана и bound к pod'у
- [ ] Можно подключиться к PostgreSQL
- [ ] Таблица создана и содержит данные
- [ ] Данные персистируются после перезагрузки pod'а
- [ ] Масштабирование работает

**Подсказки для troubleshooting:**

- **Pod не запускается**: Проверьте логи:
  ```bash
  kubectl logs postgres-0
  kubectl describe pod postgres-0
  ```

- **PVC не binds**: Проверьте доступные PV:
  ```bash
  kubectl get pv
  kubectl describe pvc postgres-storage-postgres-0
  ```

- **Не можем подключиться к БД**: Проверьте пароль в Secret:
  ```bash
  kubectl get secret postgres-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
  ```

---

### Задание 3.3: ConfigMap, Secret, Resource limits, Probes

**Цель:** Научиться управлять конфигурацией, секретами и health checks приложений.

**Описание задания:**

Создадим приложение с различными способами передачи конфигурации и мониторинга здоровья.

**Пошаговые инструкции:**

1. **Создание ConfigMap для файлов конфигурации:**

```bash
# ConfigMap из файла
mkdir -p /tmp/config
cat > /tmp/config/app.conf << 'EOF'
DEBUG=false
LOG_LEVEL=info
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=appdb
EOF

kubectl create configmap app-config --from-file=/tmp/config/app.conf

# Или встроенный ConfigMap
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  nginx.conf: |
    worker_processes auto;
    events { worker_connections 1024; }
    http {
      upstream backend { server web-service; }
      server {
        listen 80;
        location / { proxy_pass http://backend; }
      }
    }
  app.properties: |
    app.name=MyApp
    app.version=1.0.0
    app.port=8080
EOF

kubectl get configmap
kubectl describe configmap app-settings
```

2. **Создание Secret для чувствительных данных:**

```bash
# Secret из файла с паролем
echo -n 'admin-password' > /tmp/db-password.txt
kubectl create secret generic db-credentials --from-file=/tmp/db-password.txt

# Secret с несколькими данными
kubectl create secret generic api-keys \
  --from-literal=api_key=abc123xyz789 \
  --from-literal=api_secret=super-secret-xyz

# Docker Registry Secret (для private images)
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=my@email.com

kubectl get secrets
kubectl describe secret api-keys
```

3. **Deployment с ConfigMap и Secret в переменных:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-config
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-config-demo
  template:
    metadata:
      labels:
        app: app-config-demo
    spec:
      containers:
      - name: app
        image: nicolaka/netshoot
        command: ["sleep", "3600"]

        # Переменные из ConfigMap
        env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: app-settings
              key: app.properties
        - name: DEBUG
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: app.conf

        # Переменные из Secret
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: api_key
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: db-password.txt

        # Обычные переменные
        - name: ENVIRONMENT
          value: "production"

        # Информация о pod'е
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP

        # Ресурсы
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

        # Health checks
        livenessProbe:
          exec:
            command: ["sh", "-c", "[ -f /tmp/alive ]"]
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3

        readinessProbe:
          exec:
            command: ["sh", "-c", "[ -f /tmp/ready ]"]
          initialDelaySeconds: 2
          periodSeconds: 5
          timeoutSeconds: 1

        # Startup probe (для медленно стартующих приложений)
        startupProbe:
          exec:
            command: ["sh", "-c", "[ -f /tmp/started ]"]
          initialDelaySeconds: 0
          periodSeconds: 2
          failureThreshold: 30

        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true

      volumes:
      - name: config-volume
        configMap:
          name: app-settings
      - name: secret-volume
        secret:
          secretName: api-keys
EOF

# Проверяем переменные
kubectl exec <pod-name> -- env | grep -E "APP_|API_|DB_|POD_"
```

4. **Проверка ConfigMap и Secret в volume'ах:**

```bash
# Внутри pod'а файлы доступны как файловая система
kubectl exec <pod-name> -- ls -la /etc/config/
kubectl exec <pod-name> -- cat /etc/config/nginx.conf
kubectl exec <pod-name> -- cat /etc/secrets/api_key
```

5. **Resource limits и requests:**

```bash
# Создаём pod с разными ресурсами
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "1", "--memory", "1", "--io", "1", "--timeout", "600s"]

    resources:
      requests:
        cpu: 500m          # гарантированный CPU
        memory: 256Mi      # гарантированная память
      limits:
        cpu: 1000m         # максимум CPU
        memory: 512Mi      # максимум памяти
EOF

# Проверяем использование ресурсов
kubectl top pods
kubectl describe pod resource-demo  # Видим requests/limits

# Pod будет OOMKilled если превысит memory limit
```

6. **HTTP Health checks:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: http-probe-demo
spec:
  containers:
  - name: app
    image: nginx:latest

    livenessProbe:
      httpGet:
        path: /
        port: 80
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 5
      periodSeconds: 10

    readinessProbe:
      httpGet:
        path: /index.html
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 5
      failureThreshold: 2
EOF

kubectl describe pod http-probe-demo
```

**Критерии оценки:**
- [ ] ConfigMap успешно создана и используется
- [ ] Secret успешно создана и используется
- [ ] Переменные окружения доступны в pod'е
- [ ] Volumes с ConfigMap и Secret монтируются
- [ ] Resource requests и limits установлены
- [ ] Health checks работают и могут перезагружать pod
- [ ] kubectl top показывает использование ресурсов

**Подсказки для troubleshooting:**

- **Переменные не видны**: Проверьте имена ключей в ConfigMap/Secret:
  ```bash
  kubectl get configmap app-settings -o yaml
  kubectl get secret api-keys -o yaml
  ```

- **Pod ест слишком много памяти**: Снизьте memory limit или проверьте приложение на утечки
- **Pod часто перезагружается**: Проверьте probe failures: `kubectl describe pod <name>`

---

## БЛОК 4: БЕЗОПАСНОСТЬ (2 часа)

### Задание 4.1: Практика атак на Docker-контейнеры (в учебной среде)

**⚠️ ВАЖНО:** Все эксперименты проводятся в изолированной учебной среде только для образовательных целей!

**Цель:** Понять уязвимости контейнеров и почему security hardening критичен.

**Описание задания:**

Демонстрируем типичные атаки на контейнеры и показываем, как их предотвращать.

**Пошаговые инструкции:**

1. **Атака 1: Escape из контейнера через docker socket:**

```bash
# Уязвимый контейнер с доступом к docker socket
docker run -it -v /var/run/docker.sock:/var/run/docker.sock ubuntu:20.04 bash

# Внутри контейнера (демонстрирует уязвимость):
# Контейнер может создавать другие контейнеры и манипулировать хостом!
# Это критичная уязвимость.

# Проверяем docker доступ
docker ps
docker run --rm -v /:/host ubuntu:20.04 ls -la /host/  # Доступ к файловой системе хоста!

# Выход
exit
```

**Вывод:** Никогда не давайте контейнеру доступ к `/var/run/docker.sock` если не нужна.

2. **Атака 2: Privileged mode escape:**

```bash
# Уязвимый контейнер в privileged режиме
docker run -it --privileged ubuntu:20.04 bash

# Внутри контейнера:
cat /proc/self/cgroup  # Видим host cgroups
ls -la /dev/  # Видим все device'ы хоста
mount  # Можем смонтировать хост файловую систему

# Пример: монтирование хост FS
mkdir /host-fs
mount /dev/sda1 /host-fs  # (если доступен)
ls /host-fs  # Прямой доступ к файловой системе хоста!

exit
```

**Вывод:** `--privileged` флаг дает полный доступ к хосту. Использовать только если необходимо.

3. **Атака 3: Ограничение возможностей (capabilities):**

```bash
# Контейнер с избыточными capabilities
docker run -it ubuntu:20.04 bash

# Внутри контейнера:
cat /proc/self/status | grep Cap

# Контейнер имеет CAP_NET_ADMIN, CAP_SYS_PTRACE и др.
# Может выполнять опасные операции:
ping 127.0.0.1  # Требует CAP_NET_RAW
ip route add default via 0.0.0.0  # Требует CAP_NET_ADMIN

exit
```

**Вывод:** Нужно drop'ить ненужные capabilities.

4. **Атака 4: Работа от root пользователя:**

```bash
# Контейнер запущен от root
docker run -it ubuntu:20.04 whoami  # Выведет: root

# Если в контейнере уязвимость, хакер получает root доступ!
# Пример: создаем файл от root (опасно)
docker run -it --rm -v /tmp:/tmp ubuntu:20.04 bash
# touch /tmp/hacker-was-here  # Файл создан от root!

exit
```

**Вывод:** Контейнеры должны запускаться от непривилегированного пользователя.

5. **Демонстрация secure контейнера:**

```bash
# Защищённый Dockerfile
cat > /tmp/secure-app/Dockerfile << 'EOF'
FROM alpine:3.18

RUN adduser -D -u 1000 appuser

WORKDIR /app
COPY --chown=appuser:appuser app.sh .

USER appuser

HEALTHCHECK CMD wget --no-verbose --tries=1 --spider http://localhost:8000 || exit 1
CMD ["sh", "app.sh"]
EOF

# Создадим простое приложение
echo '#!/bin/sh
python3 -m http.server 8000' > /tmp/secure-app/app.sh

docker build -t secure-app:v1 /tmp/secure-app

# Запуск с ограничениями
docker run -it --rm \
  --user 1000 \
  --read-only \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges:true \
  -v /tmp:/tmp:ro \
  secure-app:v1

# Проверяем что мы не root
docker run --rm secure-app:v1 whoami  # Выведет: appuser
```

6. **Сравнительная таблица:**

| Параметр | Уязвимое | Защищённое | Почему |
|----------|----------|------------|--------|
| Пользователь | root | non-root (1000+) | Ограничивает ущерб при взломе |
| --privileged | true | false | Доступ к хосту |
| docker socket | смонтирован | не смонтирован | Контроль контейнеров |
| --read-only | false | true | Предотвращает модификацию |
| capabilities | по умолчанию | drop ALL + add NET | Минимум привилегий |
| syscalls | все | ограничены | Контроль системных вызовов |

**Критерии оценки:**
- [ ] Понимание уязвимостей docker socket, privileged mode
- [ ] Воспроизведены примеры атак в учебной среде
- [ ] Создан secure Dockerfile с hardening
- [ ] Понимание, как это переносится на K8s

**Подсказки для troubleshooting:**

- **docker socket недоступен**: Это нормально, используйте другой хост
- **Нет доступа к device**: Зависит от версии Docker и kernel

---

### Задание 4.2: Hardening контейнеров в K8s

**Цель:** Применить security best practices в Kubernetes манифестах.

**Описание задания:**

Создадим Kubernetes объекты с полным security hardening.

**Пошаговые инструкции:**

1. **Security Context для Pod'а:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    fsGroupChangePolicy: OnRootMismatch
    seccompProfile:
      type: RuntimeDefault

  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE

    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: tmp
      mountPath: /tmp

  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: tmp
    emptyDir: {}
EOF

# Проверяем
kubectl get pod secure-pod
kubectl describe pod secure-pod  # Видим все security settings
```

2. **SecurityPolicy для запрета привилегированных контейнеров:**

```bash
# Создаём restricted Pod Security Policy
cat << 'EOF' | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  allowedCapabilities: []
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'MustRunAs'
    seLinuxOptions:
      level: "s0:c123,c456"
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  readOnlyRootFilesystem: false
EOF

# ПРИМЕЧАНИЕ: PodSecurityPolicy deprecated в K8s 1.25+, используйте Pod Security Standards
```

3. **Pod Security Standards (новый подход):**

```bash
# Добавляем label на namespace
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted

# Попытка создать unsafe pod будет заблокирована
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unsafe-pod
spec:
  containers:
  - name: app
    image: ubuntu:20.04
    command: ["sleep", "3600"]
EOF

# Вывод: Error from server (Forbidden): ... violates PodSecurityPolicy
```

4. **Network Policy для изоляции трафика:**

```bash
# Запускаем test pods
kubectl run web --image=nginx
kubectl run db --image=postgres:15

# Создаём NetworkPolicy которая блокирует весь входящий трафик по умолчанию
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Теперь ничто не может достучаться до pods

# Разрешаем трафик только между конкретными pods
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-db
spec:
  podSelector:
    matchLabels:
      run: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          run: web
    ports:
    - protocol: TCP
      port: 5432
EOF

# Тестируем (должна быть изоляция)
kubectl run -it --rm test --image=nicolaka/netshoot --restart=Never -- curl http://web  # Не пройдёт
```

5. **Deployment с полным security hardening:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hardened-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hardened
  template:
    metadata:
      labels:
        app: hardened
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: app
        image: nginx:alpine
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
            add:
              - NET_BIND_SERVICE

        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi

        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10

        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        - name: tmp
          mountPath: /tmp

      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
      - name: tmp
        emptyDir: {}
EOF

kubectl get deployment hardened-app
```

**Критерии оценки:**
- [ ] Создан Pod с Security Context
- [ ] readOnlyRootFilesystem: true работает
- [ ] allowPrivilegeEscalation: false применяется
- [ ] capabilities drop'ируются
- [ ] NetworkPolicy ограничивает трафик
- [ ] Pod Security Standards применяются
- [ ] Все контейнеры запускаются от non-root

**Подсказки для troubleshooting:**

- **Pod не запускается с readOnlyRootFilesystem**: Нужны emptyDir volumes для временных файлов
- **NetworkPolicy не работает**: Проверьте, что CNI поддерживает NetworkPolicy (Calico поддерживает, Flannel нет)

---

### Задание 4.3: RBAC (Role-Based Access Control) и его применение

**Цель:** Настроить fine-grained доступ к K8s ресурсам.

**Описание задания:**

Создадим пользователей (Service Accounts) с разными уровнями доступа.

**Пошаговые инструкции:**

1. **Создание Service Accounts для разных ролей:**

```bash
# Service Account для разработчика (может читать и создавать pods)
kubectl create serviceaccount dev-user
kubectl create serviceaccount admin-user
kubectl create serviceaccount readonly-user

kubectl get serviceaccount
```

2. **Создание Role (права в одном namespace):**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods", "pods/logs", "pods/exec"]
  verbs: ["get", "list", "create", "delete"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]  # Только читать, не создавать
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: readonly-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list"]
EOF

kubectl get role
```

3. **Создание ClusterRole (права по всему кластеру):**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admin-cluster-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes/stats", "nodes/metrics"]
  verbs: ["get"]
EOF
```

4. **Привязка Role к Service Account (RoleBinding):**

```bash
# Развер дает разработчику права developer-role в namespace default
cat << 'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-user-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer-role
subjects:
- kind: ServiceAccount
  name: dev-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: readonly-user-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: readonly-role
subjects:
- kind: ServiceAccount
  name: readonly-user
  namespace: default
EOF
```

5. **Привязка ClusterRole к Service Account (ClusterRoleBinding):**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: default
EOF

kubectl get clusterrolebinding | grep admin
```

6. **Проверка прав доступа (auth can-i):**

```bash
# Проверяем права для dev-user
kubectl auth can-i create pods --as=system:serviceaccount:default:dev-user  # yes
kubectl auth can-i delete deployments --as=system:serviceaccount:default:dev-user  # yes
kubectl auth can-i delete nodes --as=system:serviceaccount:default:dev-user  # no

# Проверяем права для readonly-user
kubectl auth can-i list pods --as=system:serviceaccount:default:readonly-user  # yes
kubectl auth can-i create pods --as=system:serviceaccount:default:readonly-user  # no
kubectl auth can-i delete pods --as=system:serviceaccount:default:readonly-user  # no

# Проверяем права для admin-user
kubectl auth can-i "*" "*" --as=system:serviceaccount:default:admin-user  # yes
```

7. **Использование Service Account в Pod'е:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-sa
spec:
  serviceAccountName: dev-user
  containers:
  - name: app
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
EOF

# Внутри pod'а pod'а будут доступны токены
kubectl exec -it pod-with-sa -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/

# Pod может использовать эти токены для доступа к API
kubectl exec -it pod-with-sa -- sh -c 'curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/pods'
```

8. **Лучшие практики RBAC:**

```bash
# Принцип наименьших привилегий (Principle of Least Privilege)
# Вместо:
# verbs: ["*"]
#
# Используйте:
# verbs: ["get", "list"]  # Только необходимые права

# Ограничиваем доступ к Secrets
cat << 'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-deployer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
# Заметьте: нет доступа к Secrets!
EOF
```

**Критерии оценки:**
- [ ] 3+ Service Accounts созданы
- [ ] Role и ClusterRole созданы
- [ ] RoleBinding и ClusterRoleBinding работают
- [ ] auth can-i показывает правильные результаты
- [ ] Pod может использовать Service Account
- [ ] Принцип наименьших привилегий понимается

**Подсказки для troubleshooting:**

- **auth can-i не работает**: Проверьте правильность имени ServiceAccount
- **Pod не может обращаться к API**: Проверьте привязан ли правильный ServiceAccount и есть ли права

---

## БЛОК 5: МОНИТОРИНГ И CI/CD (2 часа)

### Задание 5.1: Развёртывание Prometheus + Grafana через манифесты

**Цель:** Настроить полноценный мониторинг Kubernetes кластера.

**Описание задания:**

Установим Prometheus для сбора метрик и Grafana для визуализации.

**Пошаговые инструкции:**

1. **Создание namespace для мониторинга:**

```bash
kubectl create namespace monitoring
kubectl label namespace monitoring name=monitoring
```

2. **Создание ConfigMap для Prometheus конфигурации:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'k8s-prod'

    scrape_configs:
    - job_name: 'prometheus'
      static_configs:
      - targets: ['localhost:9090']

    - job_name: 'kubernetes-apiservers'
      kubernetes_sd_configs:
      - role: endpoints
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
EOF

kubectl get configmap -n monitoring
```

3. **Создание Service Account для Prometheus:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF
```

4. **Развёртывание Prometheus:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
          name: prometheus
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--storage.tsdb.retention.time=30d'
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        persistentVolumeClaim:
          claimName: prometheus-storage
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: ClusterIP
  ports:
  - port: 9090
    targetPort: 9090
  selector:
    app: prometheus
EOF

# Проверяем
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

5. **Развёртывание Grafana:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
          name: grafana
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        volumeMounts:
        - name: datasources
          mountPath: /etc/grafana/provisioning/datasources
      volumes:
      - name: datasources
        configMap:
          name: grafana-datasources
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: grafana
EOF

kubectl get pods -n monitoring
```

6. **Доступ к Grafana:**

```bash
# Получаем внешний IP (если LoadBalancer)
kubectl get svc -n monitoring grafana
# Если используете NodePort:
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Grafana: http://$NODE_IP:3000"

# Логин: admin, Пароль: admin123

# Или port-forward для доступа
kubectl port-forward -n monitoring svc/grafana 3000:3000
# http://localhost:3000
```

7. **Проверка сбора метрик:**

```bash
# Port-forward к Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# http://localhost:9090/graph
# Введите query: up (покажет статус всех scraped целей)

# Другие полезные метрики:
# - node_cpu_seconds_total
# - node_memory_MemAvailable_bytes
# - container_memory_usage_bytes
# - http_requests_total
```

**Критерии оценки:**
- [ ] Prometheus успешно развёрнут и собирает метрики
- [ ] Grafana доступна и подключена к Prometheus
- [ ] Есть как минимум 10 успешно scraped целей
- [ ] Dashboards в Grafana показывают данные
- [ ] Retention policy установлена на 30 дней

**Подсказки для troubleshooting:**

- **Prometheus не scrapes targets**: Проверьте RBAC права и конфигурацию
  ```bash
  kubectl logs -n monitoring deployment/prometheus
  ```

- **Grafana не видит Prometheus**: Проверьте URL datasource:
  ```bash
  kubectl exec -n monitoring deployment/grafana -- curl http://prometheus:9090/-/healthy
  ```

---

### Задание 5.2: Настройка CI/CD pipeline (GitLab CI) для автоматической сборки и деплоя

**Цель:** Автоматизировать сборку Docker образов и деплой в K8s при коммите.

**Описание задания:**

Создадим GitLab CI/CD pipeline который будет:
1. Собирать Docker образ
2. Пушить в registry
3. Деплоить в Kubernetes

**Пошаговые инструкции:**

1. **Структура проекта:**

```bash
# Проект на GitLab
my-app/
├── src/
│   └── app.py
├── Dockerfile
├── kubernetes/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── .gitlab-ci.yml
```

2. **Создание .gitlab-ci.yml:**

```bash
cat > /tmp/app/.gitlab-ci.yml << 'EOF'
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  IMAGE_LATEST: $CI_REGISTRY_IMAGE:latest

build:docker:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_TAG -t $IMAGE_LATEST .
    - docker push $IMAGE_TAG
    - docker push $IMAGE_LATEST
  only:
    - main
    - develop

test:unit:
  stage: test
  image: python:3.11
  script:
    - pip install -r requirements.txt pytest
    - pytest tests/
  only:
    - main
    - develop

test:docker:scan:
  stage: test
  image: aquasec/trivy:latest
  script:
    - trivy image --severity HIGH,CRITICAL $IMAGE_TAG || true
  only:
    - main
    - develop

deploy:staging:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl config use-context $KUBE_CONTEXT_STAGING
    - kubectl set image deployment/my-app app=$IMAGE_TAG -n staging
    - kubectl rollout status deployment/my-app -n staging
  environment:
    name: staging
    kubernetes:
      namespace: staging
  only:
    - develop

deploy:production:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl config use-context $KUBE_CONTEXT_PROD
    - kubectl set image deployment/my-app app=$IMAGE_TAG -n production
    - kubectl rollout status deployment/my-app -n production
    - kubectl rollout history deployment/my-app -n production
  environment:
    name: production
    kubernetes:
      namespace: production
  when: manual
  only:
    - main
EOF

cat /tmp/app/.gitlab-ci.yml
```

3. **Kubernetes манифесты для деплоя:**

```bash
cat > /tmp/app/kubernetes/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: app
        image: $IMAGE_TAG  # Подставляется CI/CD
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
        env:
        - name: ENVIRONMENT
          value: "production"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
      imagePullSecrets:
      - name: gitlab-registry-secret
EOF

cat > /tmp/app/kubernetes/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8000
  selector:
    app: my-app
EOF

cat > /tmp/app/kubernetes/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: my-app-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
EOF
```

4. **GitLab Runner конфигурация:**

```bash
# На машине где установлен GitLab Runner
# /etc/gitlab-runner/config.toml

cat >> /etc/gitlab-runner/config.toml << 'EOF'
[[runners]]
  name = "kubernetes-runner"
  url = "https://gitlab.example.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "kubernetes"
  [runners.kubernetes]
    host = "https://kubernetes.default.svc.cluster.local"
    bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    [runners.kubernetes.volumes]
      [[runners.kubernetes.volumes.host_path]]
        name = "docker"
        mount_path = "/var/run/docker.sock"
        host_path = "/var/run/docker.sock"
EOF
```

5. **Переменные CI/CD в GitLab:**

```bash
# В GitLab Project Settings → CI/CD → Variables установить:

CI_REGISTRY = registry.gitlab.com
CI_REGISTRY_USER = deploy_token_username
CI_REGISTRY_PASSWORD = deploy_token_password

KUBE_CONTEXT_STAGING = staging-cluster
KUBE_CONTEXT_PROD = production-cluster

DOCKER_AUTH_CONFIG = (для приватных регистри)
```

6. **Пример простого приложения:**

```bash
cat > /tmp/app/src/app.py << 'EOF'
from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/ready")
def ready():
    return {"status": "ready"}

@app.get("/version")
def version():
    return {"version": os.getenv("VERSION", "unknown")}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
```

**Критерии оценки:**
- [ ] .gitlab-ci.yml корректно синтаксически
- [ ] Pipeline имеет 3+ stage
- [ ] Docker образ собирается и пушится в registry
- [ ] Tests выполняются перед деплоем
- [ ] Деплой в K8s работает автоматически
- [ ] Manual approval для production
- [ ] Rollback возможен через kubectl

**Подсказки для troubleshooting:**

- **Runner не может подключиться к K8s**: Проверьте kubeconfig и permissions
- **Docker daemon not accessible**: Используйте docker:dind service
- **Image pull fails**: Проверьте imagePullSecrets и registry credentials

---

### Задание 5.3: ArgoCD и GitOps (опционально, для продвинутых)

**Цель:** Внедрить GitOps подход с ArgoCD для declarative deployment.

**Описание задания:**

ArgoCD автоматически синхронизирует состояние кластера с Git репозиторием.

**Пошаговые инструкции:**

1. **Установка ArgoCD:**

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Ждим пока все pods запустятся
kubectl get pods -n argocd --watch
```

2. **Получение пароля ArgoCD:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Логин: admin
# Пароль: (из вывода выше)
```

3. **Доступ к ArgoCD:**

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# https://localhost:8080
```

4. **Структура Git репозитория для ArgoCD:**

```
my-app-infra/
├── argocd/
│   └── application.yaml
├── apps/
│   └── my-app/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── kustomization.yaml
└── environments/
    ├── staging/
    │   └── kustomization.yaml
    └── production/
        └── kustomization.yaml
```

5. **Создание ArgoCD Application:**

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myuser/my-app-infra.git
    targetRevision: HEAD
    path: apps/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
```

6. **Проверка синхронизации:**

```bash
# В ArgoCD UI: видим Application "my-app" с статусом Synced/OutOfSync
# Если OutOfSync — git состояние отличается от кластера

# Через CLI (если установлен argocd cli)
argocd login localhost:8080
argocd app list
argocd app sync my-app
```

**Критерии оценки:**
- [ ] ArgoCD установлен и доступен
- [ ] Application создана в ArgoCD
- [ ] Git репозиторий правильно структурирован
- [ ] Автоматическая синхронизация работает
- [ ] Изменения в Git автоматически деплоятся в K8s

---

## БОНУСНАЯ СЕКЦИЯ: ПОДГОТОВКА К СОБЕСЕДОВАНИЯМ

### Самооценка: Вопросы для проверки понимания

После прохождения всех 5 блоков ответьте на эти вопросы. Если не уверены в ответе — это показатель, что нужно пересмотреть соответствующий материал.

#### БЛОК 1: КОНТЕЙНЕРЫ

**Уровень: Базовый**

1. Объясните разницу между namespaces и cgroups.
   - Ответ: Namespaces изолируют данные (PID, Network, Mount), cgroups ограничивают ресурсы (CPU, память)

2. Что такое entrypoint и cmd в Dockerfile?
   - Ответ: ENTRYPOINT — команда которая всегда выполняется, CMD — аргументы по умолчанию

3. Почему multistage build уменьшает размер образа?
   - Ответ: Финальный образ содержит только runtime слой, builder слой отбрасывается

4. Что проверяет Trivy?
   - Ответ: CVE уязвимости в зависимостях образов и файловой системе

**Уровень: Средний**

5. Как создать читаемый для пользователя контейнер без Docker?
   - Ответ: Используя unshare (namespaces), cgexec (cgroups), chroot, и мниманиями device файлов

6. Какие слои Dockerfile вы будете оптимизировать в первую очередь?
   - Ответ: Большие dependencies, которые редко меняются (ставьте в начало для кэширования)

7. Как игнорировать false-positive в Trivy?
   - Ответ: Через .trivyignore файл с объяснением причины

**Уровень: Продвинутый**

8. Как минимизировать количество слоёв в Dockerfile?
   - Ответ: Комбинируя команды с && и ; в одном RUN инструкции

9. Какие есть альтернативы Docker для контейнеризации?
   - Ответ: Podman, containerd, CRI-O, LXC

10. Объясните разницу между EXPOSE и порт который слушает приложение.
    - Ответ: EXPOSE — документирует порт (не реально открывает), приложение само слушает порт

---

#### БЛОК 2: KUBERNETES КЛАСТЕР

**Уровень: Базовый**

11. Из каких компонентов состоит Control Plane?
    - Ответ: API Server, Scheduler, Controller Manager, etcd

12. Какова роль kubelet на worker ноде?
    - Ответ: Управляет контейнерами в pod'ах, репортит статус в API Server

13. Что такое CNI и зачем он нужен?
    - Ответ: Network plugin для взаимодействия pods между нодами (Flannel, Calico и др.)

14. Как проверить статус кластера?
    - Ответ: kubectl get nodes, kubectl cluster-info, kubectl get cs (componentstatuses)

**Уровень: Средний**

15. Как куbeadm инициализирует кластер?
    - Ответ: Генерирует сертификаты, статические pod'ы, kubeconfig, инициализирует etcd

16. Почему нужно отключать swap перед kubeadm init?
    - Ответ: K8s использует cgroups для управления памятью, swap нарушает этот механизм

17. Различие между kubelet service файлом и bootstrap token?
    - Ответ: Service файл — systemd юнит, bootstrap token — временный токен для присоединения нод

**Уровень: Продвинутый**

18. Как выполнить upgrade K8s кластера?
    - Ответ: Обновляем kontrolplane (kubeadm upgrade), затем kubelet/kubectl на каждой ноде

19. Как настроить HA (высокую доступность) для Control Plane?
    - Ответ: Несколько master нод с load balancer перед API Server и распределённым etcd

20. Как восстановить кластер если потеряли etcd?
    - Ответ: Из снимка (backup) etcd или переиспользовать snapshot из другого узла

---

#### БЛОК 3: РАЗВЁРТЫВАНИЕ ПРИЛОЖЕНИЙ

**Уровень: Базовый**

21. Разница между Deployment и StatefulSet?
    - Ответ: Deployment — stateless, любой pod можно удалить. StatefulSet — stateful, stable идентификаторы

22. Что делает Service в K8s?
    - Ответ: Предоставляет стабильный IP и DNS имя для доступа к pods

23. Типы Service: ClusterIP, NodePort, LoadBalancer — когда их использовать?
    - Ответ: ClusterIP для внутреннего, NodePort для localhost testing, LoadBalancer для external access

24. Что такое Ingress?
    - Ответ: HTTP(S) router для маршрутизации трафика на Service'ы на основе host/path

**Уровень: Средний**

25. Как обновить образ в Deployment?
    - Ответ: kubectl set image или kubectl edit или patch, используя rolling update по умолчанию

26. Как создать persistent volume для StatefulSet?
    - Ответ: Используя volumeClaimTemplates в StatefulSet spec

27. ConfigMap vs Secret — когда что использовать?
    - Ответ: ConfigMap для некритичной конфигурации, Secret для passwords/tokens (хоть и не зашифрован по умолчанию)

28. Liveness vs Readiness probe?
    - Ответ: Liveness — перезагрузить контейнер, Readiness — исключить из load balancer

**Уровень: Продвинутый**

29. Как выполнить zero-downtime deployment?
    - Ответ: Используя rolling update с readinessProbe и graceful shutdown

30. Как минимизировать startup время контейнера?
    - Ответ: StartupProbe для медленного старта, оптимизация инициализации, caching

---

#### БЛОК 4: БЕЗОПАСНОСТЬ

**Уровень: Базовый**

31. Почему контейнеры не должны запускаться от root?
    - Ответ: Если контейнер скомпрометирован, хакер получит root доступ на хост

32. Что такое capabilities в Linux контейнерах?
    - Ответ: Разделённые привилегии root (CAP_NET_ADMIN, CAP_SYS_TIME и т.д.)

33. Что сделает --privileged флаг?
    - Ответ: Дает контейнеру полный доступ к хосту (очень опасно)

34. Что делает PodSecurityPolicy?
    - Ответ: Контролирует какие security параметры pods могут иметь (deprecated в K8s 1.25+)

**Уровень: Средний**

35. Как запретить привилегированные контейнеры в K8s?
    - Ответ: Через PodSecurityPolicy или Pod Security Standards в namespace label

36. NetworkPolicy — как ограничить трафик между pods?
    - Ответ: Выбираем pods selector и определяем ingress/egress rules

37. Как работает RBAC в K8s?
    - Ответ: ServiceAccount + Role/ClusterRole + RoleBinding/ClusterRoleBinding = доступ

38. Что такое seccomp и selinux?
    - Ответ: seccomp ограничивает syscall'ы, selinux — обязательный контроль доступа

**Уровень: Продвинутый**

39. Как реализовать защиту от docker socket escape в K8s?
    - Ответ: Не монтировать docker.sock, использовать pod security standards, RBAC

40. Как настроить pod security для разных уровней (restricted, baseline, unrestricted)?
    - Ответ: Используя Pod Security Standards labels на namespace (pod-security.kubernetes.io/enforce)

---

#### БЛОК 5: МОНИТОРИНГ И CI/CD

**Уровень: Базовый**

41. Что собирает Prometheus?
    - Ответ: Метрики (pull модель) с targets'ов в формате .prom

42. Какие типы метрик в Prometheus?
    - Ответ: Gauge (текущее значение), Counter (только растёт), Histogram (распределение), Summary

43. Что такое scrape_interval в Prometheus?
    - Ответ: Периодичность опроса метрик с targets'ов

44. Для чего используется Grafana?
    - Ответ: Визуализация метрик с графиками и dashboard'ами

**Уровень: Средний**

45. Как настроить service discovery в Prometheus?
    - Ответ: Используя kubernetes_sd_configs с role: pod, node, ingress, etc.

46. Что такое CI/CD pipeline?
    - Ответ: Автоматизированный процесс build → test → deploy при коммитах

47. Как GitLab CI авторизуется в K8s?
    - Ответ: Используя kubeconfig или service account token с правильным RBAC

48. Что такое GitOps?
    - Ответ: Git как source of truth для infrastructure и application состояния

**Уровень: Продвинутый**

49. Как выполнить canary deployment с Prometheus метриками?
    - Ответ: Запустить новую версию на подмножестве pods, мониторить метрики, постепенно увеличивать

50. Как настроить auto-rollback если deployment failed?
    - Ответ: Используя healthcheck метрики в Prometheus и custom scripts в CI/CD

---

### Практические сценарии на собеседованиях

**Сценарий 1: Миграция приложения в K8s**

Задача: "У вас есть монолитное приложение на Python которое хранит файлы в /tmp. Как его контейнеризировать и развернуть в K8s?"

Ответ (краткий план):
1. Создать Dockerfile с multistage build
2. Использовать persistent volume для /tmp
3. Добавить healthcheck probes
4. Создать Deployment + Service + Ingress
5. Настроить HPA для масштабирования

---

**Сценарий 2: Troubleshooting упавшего pod'а**

Задача: "Pod находится в CrashLoopBackOff. Как диагностировать проблему?"

Ответ (краткий процесс):
1. `kubectl describe pod <name>` — смотрим events
2. `kubectl logs <pod>` — смотрим stdout/stderr
3. `kubectl logs <pod> --previous` — если pod рестартился
4. `kubectl exec <pod> -- bash` — заходим в pod
5. Проверяем resource limits, probes, permissions

---

**Сценарий 3: Оптимизация performance**

Задача: "Приложение медленно стартует в K8s. Как оптимизировать?"

Ответ:
1. Уменьшить Docker образ (multistage, alpine base)
2. Добавить startupProbe если initialization slow
3. Использовать init containers для подготовки
4. Увеличить resource requests если недостаточно CPU/память
5. Проверить disk I/O и network latency

---

**Сценарий 4: Security audit**

Задача: "Проверить K8s кластер на уязвимости. С чего начать?"

Ответ:
1. `kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.securityContext}'` — проверить security context
2. `kubectl get networkpolicies --all-namespaces` — проверить сетевые политики
3. `kubectl get rolebindings,clusterrolebindings --all-namespaces` — аудит RBAC
4. `kubectl api-resources --verbs=list --namespaced=true | grep -i psp` — проверить pod security policies
5. Использовать инструменты: kubesec, kube-bench, kubesec.io

---

**Сценарий 5: Disaster recovery**

Задача: "Потеряны все данные в K8s кластере. Как восстановиться?"

Ответ:
1. Если есть backup etcd — восстановить из backup
2. Если нет — пересоздать инфру через IaC (Terraform) + Git manifests
3. Восстановить данные из backup хранилища (S3, NFS и т.д.)
4. Перепроверить все конфигурации и secrets
5. Тестировать recovery procedure регулярно!

---

### Рекомендации для дальнейшего изучения

**Сертификаты:**
- Certified Kubernetes Application Developer (CKAD) — focus на разработку в K8s
- Certified Kubernetes Administrator (CKA) — focus на администрирование
- Certified Kubernetes Security Specialist (CKS) — security focus

**Книги и ресурсы:**
- "Kubernetes in Action" — Marko Luksa
- "The Kubernetes Book" — Nigel Poulton
- Официальная документация: kubernetes.io/docs
- Linux Academy / A Cloud Guru K8s курсы
- KodeKloud практические лабы

**Practice:**
- Создавайте свои проекты в K8s
- Участвуйте в open source K8s проектах
- Пишите собственные Kubernetes operators
- Экспериментируйте с advanced features (Custom Resources, Webhooks, Operators)

**Advanced topics для изучения:**
- Istio service mesh
- Helm package manager
- Kubernetes operators
- Custom Resource Definitions (CRD)
- Webhook admission controllers
- Multi-cluster K8s
- eBPF networking (Cilium)

---

## ПРИЛОЖЕНИЕ: ПОЛЕЗНЫЕ КОМАНДЫ KUBECTL

```bash
# Основные команды
kubectl get nodes                           # Список нод
kubectl get pods --all-namespaces          # Все pods во всех namespaces
kubectl get pods -o wide                   # Расширенная информация
kubectl get pods -o json | jq .            # JSON формат

# Описание и логи
kubectl describe pod <name>                # Подробная информация
kubectl logs <pod-name>                    # Логи контейнера
kubectl logs <pod-name> -c <container>     # Логи специфичного контейнера
kubectl logs <pod-name> --tail=50          # Последние 50 строк

# Редактирование
kubectl edit pod <name>                    # Редактировать pod (vi)
kubectl patch pod <name> -p '{"spec":...}' # Patch ресурса

# Выполнение команд
kubectl exec -it <pod> -- bash             # Зайти в контейнер
kubectl exec <pod> -- command              # Выполнить команду
kubectl run -it --rm debug --image=<img>   # Запустить temp pod для отладки

# Масштабирование
kubectl scale deployment <name> --replicas=5

# Обновление
kubectl set image deployment/<name> <container>=<image>
kubectl rollout restart deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>

# Удаление
kubectl delete pod <name>
kubectl delete deployment <name>
kubectl delete -f manifest.yaml

# Проверка доступов
kubectl auth can-i create pods --as=system:serviceaccount:default:user

# Port forwarding
kubectl port-forward svc/<service> 8080:80

# Копирование файлов
kubectl cp <pod>:/path/in/pod /local/path

# Просмотр событий
kubectl get events --all-namespaces
kubectl get events --field-selector involvedObject.name=<pod>

# Мониторинг ресурсов
kubectl top nodes
kubectl top pods
```

---

## Заключение

Этот документ содержит материал для полного практического понимания Kubernetes на уровне production-ready систем. Каждый блок можно проходить последовательно, повторяя упражнения несколько раз до полного освоения.

**Ключевые навыки после прохождения:**
✓ Контейнеризация приложений
✓ Развёртывание и управление K8s кластером
✓ Развёртывание stateless и stateful приложений
✓ Базовая и продвинутая безопасность
✓ Мониторинг и CI/CD автоматизация

**Общее время:** 10 часов интенсивной практики

**Дата создания:** 2026-03-21
**Версия:** 1.0

---

*Документ подготовлен для IT студентов (2-3 курс) преподавателем с 10+ лет опыта в DevOps и контейнеризации.*
