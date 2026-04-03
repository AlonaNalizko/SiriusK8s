5_laba
Структура отчета: 
# 1 выводы в терминале
# 2. вопросы
# 3. трудности

# 1 выводы в терминале
1. `kubectl get pods` — 3 пода webapp Running
sofa@FILOSOF:/mnt/c/Users/sofia$ kubectl get pods
NAME                           READY   STATUS             RESTARTS      AGE
api-backend-86cf59dd6c-c82bz   1/1     Running            0             2m48s
my-webserver                   2/2     Running            1 (24m ago)   29m
nginx                          1/1     Running            0             32m
test                           1/1     Running            0             35s
webapp-6854d8b4bc-9sqbl        1/1     Running            0             13m
webapp-6854d8b4bc-bhdd6        1/1     Running            0             13m
webapp-6854d8b4bc-q8sjm        1/1     Running            0             13m
webapp-76fdddbfcd-57j7n        0/1     InvalidImageName   0             4m3s


2. `kubectl rollout history deployment/webapp` — минимум 2 ревизии
sofa@FILOSOF:/mnt/c/Users/sofia$ kubectl rollout history deployment/webapp
deployment.apps/webapp
REVISION  CHANGE-CAUSE
1         <none>
3         <none>
4         <none>


3. `curl webapp.local` и `curl webapp.local/api` — разные ответы
sofa@FILOSOF:/mnt/c/Users/sofia$ curl webapp.local
Server name: webapp-6854d8b4bc-9sqbl
...
sofa@FILOSOF:/mnt/c/Users/sofia$ curl webapp.local/api
Hello from API


4. 
ClusterIP = внутренняя сеть (как локалка в офисе)
NodePort = выход наружу с конкретным портом (как телефон компании с добавочным номером)


# Вопросы:
1. Что такое Deployment и зачем он нужен?
→ Контроллер, который управляет подами: создаёт нужное количество реплик, обновляет их без простоев, позволяет откатываться назад.

2. Как работает rolling update без даунтайма?
→ Постепенно заменяет старые поды на новые: сначала создаёт новый под, ждёт пока он станет готовым (readiness probe), потом удаляет старый. Параметр maxUnavailable: 0 гарантирует, что ни один под не упадёт во время обновления.

3. В чём разница ClusterIP / NodePort / LoadBalancer?
ClusterIP — доступен только внутри кластера (другие поды)
NodePort — открывается порт на каждой ноде (можно зайти снаружи по IP:порт)
LoadBalancer — внешний балансировщик (только в облаке AWS/GCP/Azure)

4. Что такое Ingress и зачем он?
→ Маршрутизатор HTTP-трафика: направляет запросы на разные сервисы в зависимости от пути (/api → backend, / → frontend) или доменного имени.

5. Как откатиться на предыдущую версию?
→ kubectl rollout undo deployment/webapp — возвращает предыдущий ReplicaSet.

# Сложности:
- curl webapp.local не работает, висит
Что сделала: Ingress Controller не получил ADDRESS. Проверила kubectl get pods -n ingress-nginx — поды должны быть Running. Добавили запись в /etc/hosts: minikube ip webapp.local. Для проверки использовали обход: curl -H "Host: webapp.local" http://$(minikube ip).

Скину доработки 31.03.2026
