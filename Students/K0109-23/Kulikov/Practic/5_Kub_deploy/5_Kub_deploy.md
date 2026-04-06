# лаба 5 kub deploy

в этой лабе собрал нормальный путь выката приложения: deployment, service, ingress и откат версии

1. создал deployment на 3 реплики

использовал `deployment.yaml`

```bash
kubectl apply -f deployment.yaml
kubectl get pods -w
kubectl rollout status deployment/webapp
kubectl get rs
```

реплики поднялись нормально, готовность прошла, все три пода стали running

![скрин 1](screens/image.png)
![скрин 2](screens/image-1.png)

2. добавил service и проверил доступ

использовал `service.yaml`

```bash
kubectl apply -f service.yaml
kubectl get svc
NODE_IP=$(minikube ip)
while true; do curl -s $NODE_IP:30080 | head -n 3; sleep 1; done
```

в цикле видно что ответы идут от разных подов, балансировка работает

![скрин 3](screens/image-2.png)
![скрин 4](screens/image-3.png)

3. сделал rolling update и откат

```bash
kubectl set image deployment/webapp webapp=nginxdemos/hello:latest
kubectl rollout status deployment/webapp
kubectl rollout history deployment/webapp
kubectl rollout undo deployment/webapp
kubectl rollout status deployment/webapp
```

на апдейте без даунтайма все ок, потом откатил назад для проверки и тоже без проблем

![скрин 5](screens/image-4.png)
![скрин 6](screens/image-5.png)
![скрин 7](screens/image-6.png)
![скрин 8](screens/image-7.png)

4. настроил ingress

использовал `ingress.yaml`

```bash
minikube addons enable ingress
kubectl apply -f ingress.yaml
kubectl get ingress
echo "$(minikube ip) webapp.local" | sudo tee -a /etc/hosts
curl webapp.local
curl webapp.local/api
```

тут была затычка с hosts, сначала забыл запись и думал что ingress сломан. потом добавил домен и сразу полетело

![скрин 9](screens/image-8.png)
![скрин 10](screens/image-9.png)
![скрин 11](screens/image-10.png)
![скрин 12](screens/image-11.png)

5. вывод

теперь понял как деплой живет в реале: обновление, откат и внешняя маршрутизация
