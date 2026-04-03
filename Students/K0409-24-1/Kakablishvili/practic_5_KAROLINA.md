## Пара 5 — Kubernetes: Deployment, Service, Ingress
Команда "kubectl get pods" отображает 3 пода с названием webapp и статусом Running.
![alt text](image-42.png)
"kubectl rollout history deployment/webapp"  используется  для просмотра истории изменений (ревизий) конкретного Deployment с именем webapp. Она показывает список версий, которые были развернуты, что позволяет отслеживать изменения конфигурации и версии образа контейнера.
![alt text](image-43.png)
Ответ от curl webapp.local:
![alt text](image-44.png)
Ответ от curl webapp.local/api:
![alt text](image-45.png)

P.S. ответы получились по факту разными, но я правда хз почему такой странный ответ от второго webapp(((
