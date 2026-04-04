# Пара 5 — Kubernetes: Deployment, Service, Ingress

## Блок 1 — Deployment
Создаём файл `deployment.yaml` и принимаем его `kubectl apply -f deployment.yaml`. Можем сразу проверить и убедиться, что запустили 3 пода
<img width="699" height="151" alt="image" src="https://github.com/user-attachments/assets/e873968d-fffb-4437-bce9-ff3e792ddcfd" />

## Блок 2 — Service + Rolling Update
Создадим `service.yaml`, примем его и проверим что трафик идет через все поды.
<img width="932" height="102" alt="image" src="https://github.com/user-attachments/assets/f72ae8cf-1c62-4812-a67f-267c1d7f50ef" />

Создайте второй терминал и запустите `while true; do curl -s $NODE_IP:30080 | grep "Server name"; sleep 0.5; done`

В основном терминале сделаем rolling update и убедимся в том, что трафик не прерывается. Посмотрим историю deployment-ов. Откатимся на пред. версию
<img width="941" height="823" alt="image" src="https://github.com/user-attachments/assets/1a2010ae-7f32-4868-aca0-2f05fd631307" />

## Блок 3 — Ingress
Создадим второй сервис для демонстрации маршрутизации + файл `ingress.yaml`
<img width="944" height="162" alt="image" src="https://github.com/user-attachments/assets/e9df4704-b4e2-4b89-b373-e7ca20f11e76" />
<img width="914" height="140" alt="image" src="https://github.com/user-attachments/assets/598a14b3-b658-4cc0-86ef-96d18f1a8e5a" />


Затем добавим в /etc/hosts и проверим с помощью `curl`, но у меня не получилось и я так и не понял в чем проблема
<img width="915" height="348" alt="image" src="https://github.com/user-attachments/assets/76d23fb2-11b2-4f21-93b3-7c9e713e3361" />

## Блок 4 — Сравнение типов Service
Создадим сервис типа `ClusterIP` для `webapp`. Узнаем информацию о сервисе. Запустим под с Alpine. И узнаем информацию о `webapp-svc`.
<img width="938" height="522" alt="image" src="https://github.com/user-attachments/assets/be13ec4c-0849-4e10-955d-b1581a0864b3" />

**Вопрос:** Объяснить: в чём разница ClusterIP и NodePort
**Ответ:** 
- ClusterIP — нужен для связи между компонентами кластера. Недоступен извне.
- NodePort — даёт внешний доступ к сервису через фиксированный порт на всех узлах кластера.
- - 
