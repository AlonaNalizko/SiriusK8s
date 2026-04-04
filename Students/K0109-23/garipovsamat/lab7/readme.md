# Лабораторная 7 — Kubernetes: RBAC, NetworkPolicy, TLS
# Что за лаба

Тема — безопасность в Kubernetes. Кто что может делать в кластере, кто с кем может общаться по сети, и как зашифровать трафик через TLS.

## Блок 1 — RBAC
Что это

RBAC — это система контроля доступа. 
Она отвечает на вопросы: 
* может ли ServiceAccount читать поды?, 
* может ли удалять?, 
* в каком namespace?.

# Что сделал

Создал namespace для тестов:
```bash
kubectl create namespace rbac-demo
```

Создал ServiceAccount, Role и RoleBinding:
* app-reader — наш ServiceAccount (учетка для приложения)

* pod-reader — Role, которая разрешает только get, list, watch на pods и pods/log

* app-reader-binding — связка, которая прикрепляет Role к ServiceAccount

Проверил права через kubectl auth can-i:
```bash
kubectl auth can-i list pods -n rbac-demo --as=system:serviceaccount:rbac-demo:app-reader # yes

kubectl auth can-i delete pods -n rbac-demo --as=system:serviceaccount:rbac-demo:app-reader # no

kubectl auth can-i list pods -n default --as=system:serviceaccount:rbac-demo:app-reader # no
```
![alt text](<screens/Вставленное изображение (2).png>)

Запустил под от этого ServiceAccount и проверили внутри:
```bash
kubectl exec -it rbac-test -n rbac-demo -- sh
kubectl get pods -n rbac-demo           # работает
kubectl delete pod rbac-test -n rbac-demo  # Forbidden (нельзя)
kubectl get pods -n default                # Forbidden (чужой namespace)
```
![alt text](<screens/Вставленное изображение (3).png>)

Все работает как задумано. ServiceAccount имеет права только на чтение подов в своем namespace.

## Блок 2 — NetworkPolicy 
Что это

NetworkPolicy — это файервол внутри кластера. Можно запретить подам общаться друг с другом, разрешить только нужные связи.
Что сделали

Создал namespace и три пода:

* frontend — веб-сервер (nginx)

* backend — бекенд (тоже nginx для теста)

* database — база (тоже nginx для теста)

![alt text](<screens/Вставленное изображение (4).png>)

До применения политик проверили что все видят всех:
```bash
kubectl exec frontend -- wget -qO- backend-svc   # работает
```
![alt text](<screens/Вставленное изображение (5).png>)

```bash
kubectl exec frontend -- wget -qO- database-svc  # работает
```
![alt text](<screens/Вставленное изображение (6).png>)

```bash
kubectl exec backend -- wget -qO- database-svc   # работает
```

Применил политики:

* default-deny-ingress — запрещает весь входящий трафик ко всем подам

* allow-frontend-ingress — разрешает фронтенду принимать трафик извне

* allow-backend-from-frontend — разрешает бекенду принимать трафик только от фронтенда

* allow-database-from-backend — разрешает базе принимать трафик только от бекенда

![alt text](<screens/Вставленное изображение (7).png>)

После применения политик:
```bash
kubectl exec frontend -- wget -qO- backend-svc     # работает (разрешено)
```
![alt text](<screens/Вставленное изображение (8).png>)

```bash
kubectl exec frontend -- wget -qO- database-svc    # timeout (запрещено)
```
![alt text](<screens/Вставленное изображение (9).png>)

```bash
kubectl exec backend -- wget -qO- database-svc     # работает (разрешено)
```
![alt text](<screens/Вставленное изображение (10).png>)

Все как надо — фронтенд не может напрямую в базу, только через бекенд.

![alt text](<screens/Вставленное изображение (11).png>)

## Блок 3 — TLS
Что это

Создал свой CA (Certificate Authority), выпустили сертификат для webapp.local и подключили его к Ingress, чтобы HTTPS работал.


Создал корневой CA:
```bash
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=RU/ST=Moscow/O=SiriusLab CA/CN=SiriusLab Root CA"
```
![alt text](<screens/Вставленное изображение (12).png>)

Это наш мфц. Мы сами себе выдаем сертификаты.

Создал сертификат для webapp.local:

* Сгенерировал ключ

* Сделал запрос на подпись (CSR)

* Подписал его личным CA

Проверил сертификат:
```bash
openssl verify -CAfile ca.crt webapp.crt
```
webapp.crt: OK 

![alt text](<screens/Вставленное изображение (14).png>)

Загрузил сертификат в Kubernetes как Secret:
```bash
kubectl create secret tls webapp-tls --cert=webapp.crt --key=webapp.key -n netpol-demo
```
![alt text](<screens/Вставленное изображение (15).png>)

Создал Ingress с TLS:
```yaml
tls:
- hosts:
  - webapp.local
  secretName: webapp-tls
```

Проверил:
```bash
curl --cacert ca.crt https://webapp.local # вернул страницу nginx 
```
![alt text](<screens/Вставленное изображение (16).png>)

```bash
openssl s_client -connect webapp.local:443 -CAfile ca.crt -showcerts 2>&1 | grep "Verify return code" # Verify return code: 0 (ok)
```

![alt text](<screens/Вставленное изображение (17).png>)

# Ошибки и как их чинили
Проблема - решение

Под с kubectl не запускался (ErrImageNeverPull) - imagePullPolicy: IfNotPresent

Ingress конфликтовал со старым - удалил старый Ingress