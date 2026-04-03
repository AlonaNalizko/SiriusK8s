4_laba
Структура отчета: 
# 1 выводы в терминале
# 2. вопросы
# 3. трудности

# 1 выводы в терминале
1. `kubectl get nodes` — все Ready
sofa@FILOSOF:/mnt/c/Users/sofia$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   2d    v1.35.1
sofa@FILOSOF:/mnt/c/Users/sofia$

2. `kubectl get pods -n kube-system` — все системные поды Running 
sofa@FILOSOF:/mnt/c/Users/sofia$ kubectl get pods -n kube-system
NAME                               READY   STATUS    RESTARTS      AGE
coredns-7d764666f9-bf2qk           1/1     Running   1 (11m ago)   2d
coredns-7d764666f9-mttml           1/1     Running   1 (11m ago)   2d
etcd-minikube                      1/1     Running   1 (11m ago)   2d
kube-apiserver-minikube            1/1     Running   1 (11m ago)   2d
kube-controller-manager-minikube   1/1     Running   1 (46h ago)   2d
kube-proxy-gbljc                   1/1     Running   1 (46h ago)   2d
kube-scheduler-minikube            1/1     Running   1 (46h ago)   2d
storage-provisioner                1/1     Running   2 (11m ago)   11m
sofa@FILOSOF:/mnt/c/Users/sofia$


3. `kubectl get pods` — два пода (nginx и my-webserver) Running
sofa@FILOSOF:/mnt/c/Users/sofia$ kubectl get pods
NAME           READY   STATUS    RESTARTS        AGE
my-webserver   2/2     Running   1 (2m22s ago)   8m
nginx          1/1     Running   0               10m
sofa@FILOSOF:/mnt/c/Users/sofia$

4. `kubectl get pod my-webserver` — показать RESTARTS > 0 после kill
 sofa@FILOSOF:/mnt/c/Users/sofia$ kubectl get pod my-webserver
NAME           READY   STATUS    RESTARTS        AGE
my-webserver   2/2     Running   1 (2m46s ago)   8m24s
sofa@FILOSOF:/mnt/c/Users/sofia$


# Вопросы:
1. Какие поды в kube-system всегда должны быть Running?
coredns (DNS), etcd (база данных), kube-apiserver (мозг кластера), kube-controller-manager, kube-scheduler, kube-proxy (сеть). Без них кластер не работает.

2. Почему Pod не удалился, а перезапустился? Кто отвечает?
Потому что kubelet (агент на ноде) следит за состоянием контейнеров. Если контейнер упал — kubelet его перезапускает, чтобы выполнить желаемое состояние, описанное в YAML.

3. Отличие Pod vs Container (1–2 предложения)
Container — это один запущенный процесс с изоляцией. Pod — минимальная единица в Kubernetes, которая может содержать один или несколько контейнеров, разделяющих сеть и хранилище.

Сложности:
- minikube: command not found — скачали бинарный файл с GitHub и установили вручную
- Permission denied при старте — добавили флаг --driver=docker, чтобы не нужны были права root
- kubectl: not found внутри контейнера — написали exit, чтобы вернуться на хост-машину

Скину доработки 31.03.2026