# Лабораторная 5 — Kubernetes: Deployment, Service, Ingress
## Что за лаба

Короче, надо было задеплоить приложение на Kubernetes так, чтобы оно обновлялось без остановки работы, и чтобы было доступно извне через Ingress. Газ страпонить ноут.

## Блок 1 — Deployment

Создал файл deployment.yaml с тремя репликами приложения. Использовал образ nginxdemos/hello:plain-text, который показывает имя хоста пода, это удобно, чтобы видеть, на какой под прилетел запрос.

Настройки:

    replicas: 3 — три пода

    maxSurge: 1 и maxUnavailable: 0 — при обновлении сначала поднимется один новый под, а старый не упадет, пока новый не заработает

    readinessProbe — проверяет что под готов принимать трафик

Применил:
```bash
kubectl apply -f deployment.yaml
```
Глянул:
```bash
kubectl get pods
```
![alt text](<screens/Вставленное изображение (3).png>)

Все три поднялись. Но сначала была фигнюшка, что образ не качался, ImagePullBackOff. Пришлось опять ручками качать и загружать.

## Блок 2 — Service + Rolling Update
Создал Service типа NodePort

service.yaml:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
spec:
  selector:
    app: webapp
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```
Это чтобы можно было достучаться до приложения снаружи кластера.
Rolling update — обновление без остановки

Открыл два терминала:

В одном запустил цикл curl который стучался на сервис и выводил имя пода

Во втором обновил образ на latest:

```bash
kubectl set image deployment/webapp webapp=nginxdemos/hello:latest
kubectl rollout status deployment/webapp
```

Пока шло обновление, во втором терминале запросы не прерывались — имена подов менялись, но 404 не было. Доказали, что rolling update работает без даунтайма.

Откат
```bash
kubectl rollout undo deployment/webapp
kubectl rollout history deployment/webapp
```
![alt text](<screens/Вставленное изображение (4).png>)

Вернулись на предыдущую версию. В истории деплоймента появились ревизии — можно смотреть, что менялось.

## Блок 3 — Ingress

Тут надо было сделать так, чтобы по разным URL приходили разные ответы:

    webapp.local/ наш веб-сервер (nginx)

    webapp.local/api другой сервис, который просто возвращает "Hello from API"

Установил Ingress Controller

Для kind ингресс не ставится по умолчанию, пришлось накатывать:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Ждал пока поды поднимутся, они появились в неймспейсе ingress-nginx.

Создал второй сервис для API
```bash
kubectl create deployment api-backend --image=hashicorp/http-echo -- /http-echo -text="Hello from API"
kubectl expose deployment api-backend --port=5678 --name=api-svc
```

Написал Ingress

ingress.yaml с правилами:

    / # webapp-svc:80

    /api # api-svc:5678

Добавил хост webapp.local в /etc/hosts:
```bash
echo "127.0.0.1 webapp.local" | sudo tee -a /etc/hosts
```

Пробросил порт ингресса:
```bash
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 --address 0.0.0.0
```

Проверил
```bash
curl webapp.local
```

```bash
curl webapp.local/api
```
![alt text](<screens/Вставленное изображение (5).png>)

Ответил Hello from API.

Всё работает/

## Блок 4 — Типы Service

Создал три типа и посмотрели разницу:

### ClusterIP
```bash
kubectl expose deployment webapp --name=webapp-clusterip --type=ClusterIP --port=80
kubectl get svc webapp-clusterip
```

Доступен только внутри кластера. Проверил, зайдя в под с alpine:
```bash
kubectl run test --rm -it --image=alpine -- sh
wget -qO- webapp-clusterip | grep "Server name"
```

![alt text](<screens/Вставленное изображение.png>)

### NodePort
```bash
kubectl get svc webapp-svc
```

Виден порт 30080 на всех нодах. В kind его видно только через проброс порта.

### LoadBalancer
```bash
kubectl expose deployment webapp --name=webapp-lb --type=LoadBalancer --port=80
kubectl get svc webapp-lb
```

![alt text](<screens/Вставленное изображение (2).png>)

Завис в pending, потому что локальный кластер не дает внешний балансировщик.

Коротко про типы:

    ClusterIP — только внутри кластера, для связи между сервисами

    NodePort — открывает порт на каждой ноде, можно достучаться снаружи

    LoadBalancer — создает внешний балансировщик, который раздает трафик на ноды

# Ошибки и как чинил
* Образы не качались

ErrImagePull и ImagePullBackOff чет напрягали на каждой лабе. Кластер не мог скачать образы из Docker Hub — то ли DNS, то ли сеть хз.

Как чинили: качали образ на хосте, сохраняли в tar, копили в контейнер кластера и импортировали через ctr images import. Руками, но работало.

* В kind порты не пробрасываются на localhost

Пришлось использовать kubectl port-forward для сервисов и для ингресса.
