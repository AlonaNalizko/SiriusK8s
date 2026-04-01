Отчёт по лабораторной работе: «Kubernetes: Deployment, Service, Ingress»

Блок 1 — Deployment
Создали файл deployment.yaml для развёртывания приложения. В манифесте указали:

- 3 реплики

- стратегию обновления RollingUpdate с параметрами maxSurge: 1 (разрешён один дополнительный под во время обновления) и maxUnavailable: 0 (ни один под не должен падать)

- образ nginxdemos/hello:plain-text, который выводит имя хоста

- ресурсы: requests и limits для CPU и памяти

- readinessProbe для проверки готовности пода


После создания манифеста проверили статус:

sudo kubectl rollout status deployment/webapp
Деплоймент успешно развернулся: 3 реплики стали доступны.

Проверка ReplicaSet:
sudo kubectl get rs
Вывод показал ReplicaSet с 3 желаемыми, текущими и готовыми репликами.

sudo kubectl get pods -w
Три пода webapp запустились и перешли в статус Running.

Блок 2 — Service + Rolling Update
Создали Service типа NodePort для доступа к приложению извне:
sudo kubectl apply -f service.yaml
Проверили Service:

sudo kubectl get svc webapp-svc
Вывод: тип NodePort, ClusterIP 10.43.140.253, порт 30000.

Rolling update без даунтайма:

Обновили образ до nginxdemos/hello:latest:

sudo kubectl set image deployment/webapp webapp=nginxdemos/hello:latest
Следили за статусом обновления:

sudo kubectl rollout status deployment/webapp
Деплоймент успешно обновился.

Проверка ReplicaSet после обновления:

sudo kubectl get rs
Появился новый ReplicaSet webapp-5665b6cf6b со старым остался webapp-696d966cdc (3 реплики). При обновлении старый RS масштабируется до 0, новый — до 3.

История деплойментов:

sudo kubectl rollout history deployment/webapp
Вывод показал ревизии без указания причины (CHANGE-CAUSE: <none>).

Откат на предыдущую версию:

sudo kubectl rollout undo deployment/webapp
sudo kubectl rollout status deployment/webapp
Деплоймент успешно откатился. Повторный rollout history показал появление новой ревизии (5). При откате создаётся новая ревизия, а не удаляется старая.

Блок 3 — Ingress
Создание второго сервиса для демонстрации маршрутизации:

sudo kubectl create deployment api-backend --image=hashicorp/http-echo -- /http-echo -text="Hello from API"
sudo kubectl expose deployment api-backend --port=5678 --name=api-svc
Создание Ingress:

Файл ingress.yaml:

yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
spec:
  ingressClassName: traefik   # для K3s используется traefik
  rules:
  - host: webapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-svc
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 5678
Применили:

sudo kubectl apply -f ingress.yaml
sudo kubectl get ingress
Вывод: Ingress webapp-ingress создан, класс traefik, хост webapp.local, адрес 10.82.147.156.

Проверка Ingress Controller (в K3s это Traefik):

sudo kubectl get pods -n kube-system | grep traefik
Поды в статусе Running.

Добавление записи в /etc/hosts:

sudo echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts
В файл добавилась строка 10.82.147.156 webapp.local.

Проверка маршрутизации:

curl webapp.local
Вывод: Server address: 10.42.0.26:80, Server name: webapp-696d966cdc-l2pq5 — основной сервис.

curl webapp.local/api
Вывод: Hello from API — запрос ушёл на api-backend.

Маршрутизация работает: Ingress направляет запросы на / в webapp-svc, а на /api — в api-svc.

Блок 4 — Сравнение типов Service
ClusterIP (внутренний):

sudo kubectl expose deployment webapp --name=webapp-clusterip --type=ClusterIP --port=80
sudo kubectl get svc webapp-clusterip
Вывод: ClusterIP 10.43.64.103, EXTERNAL-IP: <none>. Доступен только внутри кластера.

NodePort (доступ снаружи):

sudo kubectl get svc webapp-svc
Вывод: тип NodePort, порт 30000. Доступен по адресу IP_ноды:30000.

Разница ClusterIP и NodePort:

ClusterIP — доступен только внутри кластера, используется для внутренней коммуникации между сервисами.

NodePort — открывает порт на каждой ноде кластера, позволяя обращаться к сервису извне. Подходит для разработки и тестирования.

LoadBalancer (не использовался) — в облачных средах автоматически выделяет внешний IP.

Ошибки и сложности
1. Отсутствие Ingress Controller nginx в K3s
В K3s по умолчанию используется Traefik, а не nginx-ingress. Пришлось изменить ingressClassName с nginx на traefik, иначе Ingress не работал.

2. Проблема с добавлением записи в /etc/hosts
Команда для добавления хоста потребовала нескольких попыток. Итоговая рабочая команда:
sudo echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts

3. В методичке предлагалась команда NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'), но она не сработала из-за особенностей вывода адресов в K3s. Вместо этого использовали команду:
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
Она корректно извлекла внутренний IP ноды (10.82.147.156).

4. Проверка Ingress Controller
Вместо kubectl get pods -n ingress-nginx (для minikube) использовали:
sudo kubectl get pods -n kube-system | grep traefik
Поды traefik-c5c8bf4ff-tkd45 и svclb-traefik-6f3d9b9a-vxmxv оказались в статусе Running, что подтвердило работу Ingress Controller.

![Снимок экрана от 2026-03-31 15-27-12.png](Снимок экрана от 2026-03-31 15-27-12.png)

![Снимок экрана от 2026-03-31 15-40-54.png](Снимок экрана от 2026-03-31 15-40-54.png)

![Снимок экрана от 2026-03-31 15-43-47.png](Снимок экрана от 2026-03-31 15-43-47.png)

![Снимок экрана от 2026-03-31 15-51-21.png](Снимок экрана от 2026-03-31 15-51-21.png)

![Снимок экрана от 2026-03-31 15-52-46.png](Снимок экрана от 2026-03-31 15-52-46.png)