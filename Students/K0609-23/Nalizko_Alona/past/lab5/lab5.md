Отчёт по лабораторной работе: «Kubernetes: Deployment, Service, Ingress»

В рамках выполнения лабораторной работы изучается развёртывание приложений в Kubernetes с использованием Deployment, Service и Ingress. Цель работы – научиться создавать масштабируемые приложения, выполнять rolling update без даунтайма, настраивать доступ к приложениям извне кластера и маршрутизировать трафик через Ingress.

1. Deployment
Создаётся файл deployment.yaml с описанием Deployment для веб-приложения. В спецификации указано 3 реплики, используется стратегия обновления RollingUpdate с параметрами maxSurge: 1 (разрешает на один под больше во время обновления) и maxUnavailable: 0 (гарантирует, что ни один под не будет недоступен во время обновления). Контейнер использует образ nginxdemos/hello:plain-text, который показывает имя хоста пода. Настроены ресурсные ограничения (requests и limits), а также readinessProbe для проверки готовности пода принимать трафик.

Применение конфигурации выполняется командой kubectl apply -f deployment.yaml. Команда kubectl get pods -w показывает, как три пода последовательно переходят из состояния ContainerCreating в Running. Статус развёртывания отслеживается через kubectl rollout status deployment/webapp. Команда kubectl get rs показывает, что Deployment управляет ReplicaSet, который в свою очередь управляет подами.

2. Service + Rolling Update
Создаётся файл service.yaml для доступа к приложению извне кластера. Service типа NodePort с селектором app: webapp и портом 30080 на каждой ноде.

После применения конфигурации командой kubectl apply -f service.yaml определяется IP-адрес узла. В K3s для извлечения внутреннего IP используется команда NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}').

Для проверки балансировки нагрузки запускается цикл, который отправляет запросы к сервису и выводит имя сервера. В другом терминале выполняется rolling update: kubectl set image deployment/webapp webapp=nginxdemos/hello:latest. В процессе обновления видно, что трафик продолжает поступать без прерываний – поды обновляются постепенно, по одному.

После обновления проверяется история деплойментов командой kubectl rollout history deployment/webapp. Видно, что появилась новая ревизия. Для отката на предыдущую версию выполняется kubectl rollout undo deployment/webapp. После успешного отката история снова показывает изменения, а трафик продолжает идти без разрывов.

3. Ingress
Для демонстрации маршрутизации создаётся второй сервис – API-бэкенд. Команда kubectl create deployment api-backend --image=hashicorp/http-echo -- /http-echo -text="Hello from API" создаёт Deployment с одним подом, который возвращает строку "Hello from API". Затем этот Deployment экспонируется как сервис: kubectl expose deployment api-backend --port=5678 --name=api-svc.

Создаётся файл ingress.yaml. В K3s по умолчанию используется Traefik в качестве Ingress Controller, поэтому в спецификации указывается ingressClassName: traefik. Правила маршрутизации: все запросы на корневой путь / направляются к сервису webapp-svc, а запросы на /api – к сервису api-svc.

Применение конфигурации: kubectl apply -f ingress.yaml. Команда kubectl get ingress показывает, что Ingress получил адрес 192.168.78.150.

Для доступа по имени хоста webapp.local добавляется запись в /etc/hosts. Рабочая команда: echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts.

После этого проверяется работа Ingress: curl webapp.local возвращает ответ от веб-приложения (показывает имя сервера), а curl webapp.local/api возвращает "Hello from API". Маршрутизация работает корректно.

Для проверки работы Ingress Controller выполняется kubectl get pods -n kube-system | grep traefik. Поды traefik и svclb-traefik находятся в статусе Running, что подтверждает работоспособность Ingress Controller.


4. Сравнение типов Service
Для демонстрации различных типов Service создаётся ClusterIP-сервис: kubectl expose deployment webapp --name=webapp-clusterip --type=ClusterIP --port=80. Команда kubectl get svc webapp-clusterip показывает, что внешний IP отсутствует (EXTERNAL-IP: <none>). Проверка доступа изнутри кластера выполняется через временный под: kubectl run test --rm -it --image=alpine -- sh. Внутри пода выполняется wget -qO- webapp-clusterip, и запрос успешно доходит до приложения.

Разница между ClusterIP, NodePort и LoadBalancer:

ClusterIP – доступен только внутри кластера. Используется для внутренней коммуникации между сервисами.

NodePort – открывает порт на каждой ноде кластера (в диапазоне 30000-32767). Доступен извне кластера через <IP_ноды>:<NodePort>. Подходит для тестирования и простых сценариев.

LoadBalancer – создаёт внешний балансировщик нагрузки в облачной среде (AWS, GCP, Azure). Автоматически выделяет внешний IP и распределяет трафик между нодами. В локальных кластерах (minikube, k3s) работает только при наличии cloud provider.

Ошибки и сложности
Проблема с извлечением IP-адреса ноды. Команда из методички NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}') не сработала из-за особенностей вывода адресов в K3s. Использована альтернативная команда с фильтром по типу InternalIP: NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'). Это корректно извлекло внутренний IP ноды.

Проблема с Ingress Controller в K3s. В K3s по умолчанию используется Traefik, а не nginx-ingress. Пришлось изменить ingressClassName с nginx на traefik, иначе Ingress не работал и адрес оставался пустым. После изменения Ingress получил адрес, и маршрутизация заработала.

Проблема с добавлением записи в /etc/hosts. Команда для добавления хоста потребовала нескольких попыток. Итоговая рабочая команда: echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts.

Проверка Ingress Controller. Вместо kubectl get pods -n ingress-nginx (для minikube) использована команда kubectl get pods -n kube-system | grep traefik. Поды traefik и svclb-traefik оказались в статусе Running, что подтвердило работу Ingress Controller.

Результаты выполнения
kubectl get pods – 3 пода webapp в статусе Running

kubectl rollout history deployment/webapp – минимум 2 ревизии (после обновления и отката)

curl webapp.local – возвращает ответ от веб-приложения (Server name: webapp-...), curl webapp.local/api – возвращает "Hello from API"

Разница между ClusterIP и NodePort – ClusterIP доступен только внутри кластера, NodePort открывает порт на каждой ноде для внешнего доступа

![Снимок экрана](./Снимок%20экрана%202026-03-31%20151322.png)
![Снимок экрана](./Снимок%20экрана%202026-03-31%20151347.png)
![Снимок экрана](./Снимок%20экрана%202026-03-31%20153124.png)
![Снимок экрана](./Снимок%20экрана%202026-03-31%20153248.png)
![Снимок экрана](./Снимок%20экрана%202026-03-31%20152715.png)