# Лабораторная 4 — Kubernetes: кластер, поды, самовосстановление
## Что делали
### Блок 1 — Состояние кластера

Посмотрел ноды:
```bash
kubectl get nodes -o wide
```
![alt text](<screens/Вставленное изображение (3).png>)
Нода desktop-control-plane в статусе Ready. Это нода, на которой крутятся все компоненты.

Посмотрел системные поды:
```bash
kubectl get pods -n kube-system
```
![alt text](<screens/Вставленное изображение (4).png>)

Все поды в статусе Running: kube-apiserver, etcd, kube-scheduler, controller-manager, coredns, kube-proxy.

Попробовал посмотреть манифесты control plane:
```bash
ls /etc/kubernetes/manifests/
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Ничего не нашел. Оказалось, что манифесты лежат не на хосте, а внутри VM. Пришлось заходить туда:
```bash
docker exec desktop-control-plane ls /etc/kubernetes/manifests/
```
Там лежат etcd.yaml, kube-apiserver.yaml, kube-controller-manager.yaml, kube-scheduler.yaml.

![alt text](<screens/Вставленное изображение (2).png>)
### Блок 2 — Первый под

Запустил под:
```bash
kubectl run nginx --image=nginx:alpine --port=80
```
Проблема: под не запускался, висел в ErrImagePull и ImagePullBackOff. Docker Hub не качал образы из-за проблем с DNS.

Как исправил:

* Скачали образ на хосте: docker pull nginx:alpine

* Сохранили в tar: docker save nginx:alpine -o nginx-alpine.tar

* Скопировали в контейнер кластера: docker cp nginx-alpine.tar desktop-control-plane:/

* Импортировали в containerd: docker exec desktop-control-plane ctr images import /nginx-alpine.tar

После этого под запустился.

Зашел внутрь:
```bash
kubectl exec -it nginx -- sh
```
Внутри:

    hostname — имя пода

    cat /etc/hosts — видно IP пода

    env | grep KUBE — письки от Kubernetes

    ps aux — только процессы внутри контейнера

    ip addr — свой IP

![alt text](<screens/Вставленное изображение (5).png>)

### Блок 3 — Под через YAML

Создал файл pod.yaml с двумя контейнерами:

* nginx — основной веб-сервер

* log-sidecar — busybox, который пишет логи в файл

Общие проблемы:
busybox тоже не качался, пришлось делать ту же процедуру: docker pull busybox, сохранить, скопировать, импортировать

Применил:
```bash
kubectl apply -f pod.yaml
```
Проверил:

    kubectl get pods — оба контейнера Running

    kubectl logs my-webserver -c log-sidecar — логи из sidecar

    kubectl exec -it my-webserver -c nginx -- sh — зашли в nginx контейнер

![alt text](<screens/Вставленное изображение (6).png>)
### Блок 4 — Самовосстановление

Убил процесс nginx внутри контейнера:
```bash
kubectl exec my-webserver -c nginx -- kill 1
```
Наблюдал:
```bash
kubectl get pods -w
```
Под сначала стал 1/2, потом 2/2, а RESTARTS увеличился до 1.

Почему под не удалился, а перезапустился?

    За это отвечает kubelet — агент на каждой ноде.

    По умолчанию у подов стоит restartPolicy: Always.

    Если процесс в контейнере упал, kubelet перезапускает контейнер, а не удаляет под целиком.

![alt text](<screens/Вставленное изображение (7).png>)
# Ошибки и их исправление
Ошибка
* ErrImagePull / ImagePullBackOff 
DNS проблемы в кластере, не мог скачать образы из Docker Hub - cкачали образы на хосте, загрузили в containerd через ctr images import

* ls /etc/kubernetes/manifests не работает - манифесты не на хосте, а внутри VM - зашли через docker exec desktop-control-plane ...
