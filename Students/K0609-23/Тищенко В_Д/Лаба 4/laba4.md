Отчёт по лабораторной работе: «Kubernetes: установка кластера, первые поды»

Блок 1 — Состояние кластера
Установили K3s командой curl -sfL https://get.k3s.io | sh. Установка прошла успешно: скачалась версия v1.34.6+k3s1, созданы символические ссылки на kubectl и crictl, настроен systemd-сервис.

Проверка нод:

kubectl get nodes -o wide
Вывод показал одну ноду user-comp в статусе Ready, роль control-plane. Версия узла v1.34.6+k3s1, внутренний IP 10.82.147.156.

Проверка компонентов Control Plane:

kubectl get pods -n kube-system
Все системные поды в статусе Running:

-coredns
-local-path-provisioner
-metrics-server
-traefik (и его helper-под svclb-traefik)
-два helm-install-пода завершились (Completed) — это нормально

Проверка компонентов etcd, scheduler, controller-manager:

kubectl get componentstatuses
Вывод показал все три компонента Healthy. В K3s они работают внутри единого процесса k3s-server, но API-эндпоинты доступны.

Посмотрели API-ресурсы. Вывелись стандартные ресурсы: pods, services, configmaps, nodes, persistentvolumes и т.д.

Версия кластера: Client Version и Server Version: v1.34.6+k3s1.

Контрольный вопрос: Какие поды в kube-system всегда должны быть Running?
В K3s всегда Running должны быть coredns, local-path-provisioner, metrics-server, traefik (если используется ingress). Поды helm-install после установки завершаются — это норма.

Блок 2 — Первый Pod
Запустили под императивно (через команду, без YAML-файла):

kubectl run nginx --image=nginx:alpine --port=80
Команда выдала ошибку AlreadyExists, так как под с таким именем уже был создан ранее. Проверили существующие поды:

kubectl get pods -o wide
Под nginx уже работал, IP 10.42.0.9.

Исследование пода изнутри:

kubectl exec -it nginx -- sh
Внутри выполнили:

- hostname — имя пода (nginx)
- cat /etc/hosts — видна запись с IP пода и его именем
- env | grep KUBE — переменные окружения от Kubernetes (KUBERNETES_SERVICE_HOST, KUBERNETES_PORT и др.)
- ps aux — только процессы nginx и оболочка (изоляция PID namespace)
- ip addr — интерфейс eth0 с IP 10.42.0.9 (изоляция сети)

Вывелись логи запуска nginx: проверка конфигурации, старт worker-процессов.

Описание пода:

kubectl describe pod nginx
Показало имя, namespace, ноду, IP, статус контейнера, события.

Блок 3 — Pod через YAML
Создали файл pod.yaml с двумя контейнерами:

nginx — веб-сервер с livenessProbe и readinessProbe, лимитами CPU 100m, памяти 64Mi

log-sidecar — busybox, который каждые 5 секунд пишет дату в лог-файл

Под успешно создался:

kubectl apply -f pod.yaml
kubectl get pods -w
Под прошёл стадии ContainerCreating -> Running, оба контейнера запустились.

Посмотрели имена контейнеров в поде:

kubectl get pod my-webserver -o jsonpath='{.spec.containers[*].name}'
Вывод: nginx log-sidecar

Логи sidecar-контейнера:

kubectl logs my-webserver -c log-sidecar
Пустой вывод (логи пишутся в файл внутри пода, не в stdout).

Вход в контейнер nginx:

kubectl exec -it my-webserver -c nginx -- sh
Внутри выполнили команды, затем вышли. Попытка выполнить kubectl изнутри пода не удалась (команда не найдена) — это ожидаемо, так как внутри только nginx и базовые утилиты.

Посмотрели YAML запущенного пода:

kubectl get pod my-webserver -o yaml | head -60
Вывод показал добавленные Kubernetes-поля: status, условия готовности, сгенерированные монтирования (kube-api-access), детали проб.

Блок 4 — Самовосстановление
Попытка убить процесс nginx стандартными способами:

kubectl exec my-webserver -c nginx -- kill 1
Выдало Permission denied, так как nginx в alpine запускается от непривилегированного пользователя и не может убить свой собственный PID 1.

Альтернативный способ через crictl:

sudo k3s crictl rm -f $(sudo k3s crictl ps --name nginx -q)
Эта команда находит контейнер с именем nginx на уровне containerd и принудительно удаляет его. Kubelet видит, что контейнер отсутствует, и пересоздаёт его.

Наблюдение за рестартами:

kubectl get pods -w
В процессе:

my-webserver стал 1/2 Running (один контейнер перезапускается)

затем 2/2 Running, а RESTARTS увеличился с 0 до 1

kubectl get pod my-webserver
Самовосстановление сработало — контейнер перезапустился, под остался жив.

Контрольный вопрос: Почему Pod не удалился, а перезапустился? Кто за это отвечает?
Pod не удалился, потому что удалялся не сам Pod, а только контейнер внутри него. Kubelet (агент на ноде) отслеживает состояние контейнеров и при их отсутствии пересоздаёт их в соответствии с политикой restartPolicy: Always (значение по умолчанию). За перезапуск отвечает kubelet.

Ошибки и сложности

1. kill 1 не работает в контейнере
В образе nginx:alpine процесс запущен от непривилегированного пользователя, и kill 1 завершился с Permission denied. Пришлось использовать crictl rm -f для принудительного удаления контейнера на уровне containerd, чтобы протестировать самовосстановление.

2. Предупреждение об устаревших componentstatuses
При выполнении kubectl get componentstatuses появилось предупреждение, что API устарел. Но сами компоненты были в статусе Healthy, что подтверждает работоспособность кластера.


![Снимок экрана.png](./Снимок%20экрана%20от%202026-03-31%2014-29-29.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-03-31%2014-30-25.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-03-31%2014-47-37.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-03-31%2014-59-38.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-03-31%2015-20-05.png)
