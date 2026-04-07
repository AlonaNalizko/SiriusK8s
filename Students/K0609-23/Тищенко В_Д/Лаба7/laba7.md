Отчёт по лабораторной работе: «Безопасность Kubernetes: RBAC, NetworkPolicy, TLS»

Блок 1 — RBAC
Создали namespace rbac-demo и файл rbac.yaml, который содержит три объекта:
-ServiceAccount app-reader — учётная запись для приложения;
-Role pod-reader — разрешает только чтение подов и их логов (get, list, watch). Специально не даёт прав на создание, удаление и обновление;
-RoleBinding — связывает ServiceAccount с Role в namespace rbac-demo.

Применили манифест:
kubectl apply -f rbac.yaml
Проверили права ServiceAccount:

kubectl auth can-i list pods --namespace rbac-demo --as=system:serviceaccount:rbac-demo:app-reader
Вывод: yes — читать поды можно.

kubectl auth can-i delete pods --namespace rbac-demo --as=system:serviceaccount:rbac-demo:app-reader
Вывод: no — удалять нельзя.

kubectl auth can-i list pods --namespace default --as=system:serviceaccount:rbac-demo:app-reader
Вывод: no — права ограничены только namespace rbac-demo.

Запуск пода от имени ServiceAccount:

Создали файл pod-rbac-demo.yaml с подом rbac-test, который использует ServiceAccount app-reader. В контейнере образ bitnami/kubectl для выполнения команд kubectl изнутри пода.

Применили манифест. При попытке войти в под через kubectl exec возникла ошибка container not found, но после повторной команды под запустился.

Внутри пода:
kubectl get pods -n rbac-demo — сработало (разрешено)
kubectl delete pod rbac-test -n rbac-demo — ошибка Forbidden (не разрешено)
kubectl get pods -n default — ошибка Forbidden (другой namespace)
RBAC работает: ServiceAccount имеет ровно те права, которые описаны в Role, и не больше.

Блок 2 — NetworkPolicy
Создали namespace netpol-demo и три тестовых пода с разными ролями:

-frontend (label role=frontend)
-backend (label role=backend)
-database (label role=database)

Для каждого пода создали Service (frontend-svc, backend-svc, database-svc).

Проверка доступа до применения политик:
-frontend -> backend — работало
-frontend -> database — работало (это небезопасно)

Создали файл networkpolicies.yaml с четырьмя политиками:

-default-deny-ingress — запрещает весь входящий трафик ко всем подам (podSelector пустой);

-allow-frontend-ingress — разрешает входящий трафик к frontend откуда угодно (для внешнего доступа);

-allow-backend-from-frontend — backend принимает трафик только от подов с label role=frontend;

-allow-database-from-backend — database принимает трафик только от подов с label role=backend;

Применили политики и проверили изоляцию:
kubectl exec frontend -n netpol-demo -- wget -qO- --timeout=3 backend-svc
Работает — frontend -> backend разрешено.

kubectl exec frontend -n netpol-demo -- wget -qO- --timeout=3 database-svc
Connection refused — frontend не может напрямую обращаться к database.

kubectl exec backend -n netpol-demo -- wget -qO- --timeout=3 database-svc
Работает — backend -> database разрешено.
NetworkPolicy применяются корректно, трафик изолирован по принципу минимальных привилегий.

Блок 3 — TLS сертификаты с OpenSSL
3.1 — Создание собственного CA

В директории ~/ssl-lab сгенерировали приватный ключ корневого центра сертификации (CA) алгоритмом RSA 4096:
openssl genrsa -out ca.key 4096
Создали самоподписанный корневой сертификат CA на 10 лет:
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=RU/ST=Moscow/O=SiriusLab CA/CN=SiriusLab Root CA"
Проверили сертификат: Issuer и Subject совпадают, срок действия 10 лет.

3.2 — Создание CSR для веб-сервера
Создали файл webapp.ext с расширениями Subject Alternative Names (SAN), указав DNS-имена webapp.local, www.webapp.local и IP 127.0.0.1.

Сгенерировали ключ сервера и Certificate Signing Request (CSR):

openssl genrsa -out webapp.key 2048
openssl req -new -key webapp.key -out webapp.csr -subj "/C=RU/O=SiriusLab/CN=webapp.local"
3.3 — Подпись сертификата CA
Подписали CSR своим CA, получив сертификат сервера на 1 год с учётом SAN:

openssl x509 -req -in webapp.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out webapp.crt -days 365 -sha256 -extfile webapp.ext
Проверили:
openssl x509 -in webapp.crt -noout -text | grep -A5 "Subject Alternative" — показывает DNS и IP из webapp.ext

openssl verify -CAfile ca.crt webapp.crt — вывод webapp.crt: OK, цепочка доверия построена

3.4 — Подключение сертификата к Kubernetes Ingress

Создали TLS Secret в Kubernetes:

kubectl create secret tls webapp-tls --cert=webapp.crt --key=webapp.key -n netpol-demo
Проверили Secret: kubectl get secret webapp-tls -n netpol-demo — тип kubernetes.io/tls, данные tls.crt и tls.key.

Создали файл ingress-tls.yaml с Ingress для namespace netpol-demo. В нём указаны:

- ingressClassName: traefik (для K3s);
- секция tls с hosts webapp.local и secretName webapp-tls;
- правило: запросы на webapp.local идут на frontend-svc

Применили Ingress.

Добавление записи в /etc/hosts:
Вместо echo "$(minikube ip) webapp.local" | sudo tee -a /etc/hosts использовали команду, адаптированную для K3s:
echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts
Проверка TLS-соединения:

curl --cacert ca.crt https://webapp.local
Вывод показал HTML-страницу nginx — соединение установлено, сертификат доверенный.

Детальная проверка через openssl:

openssl s_client -connect webapp.local:443 -CAfile ca.crt -showcerts 2>&1 | \
  grep -E "subject=|issuer=|Verify return code"

Вывод: subject=C=RU, O=SiriusLab, CN=webapp.local, issuer=C=RU, ST=Moscow, O=SiriusLab CA, CN=SiriusLab Root CA, Verify return code: 0 (ok).

3.5 — Декодирование сертификата из Secret

Извлекли сертификат из Secret и проверили его параметры:

kubectl get secret webapp-tls -n netpol-demo -o jsonpath='{.data.tls.crt}' | base64 -d | \
  openssl x509 -noout -text | grep -E "Subject:|Issuer:|DNS:|IP:|Not "
Срок действия: notAfter=Apr 1 07:16:34 2027 GMT.

Ошибки и сложности
1. Ошибка container not found при kubectl exec в rbac-test
После создания пода rbac-test первая попытка войти в него завершилась ошибкой container not found. Повторная команда сработала — под успел запуститься, контейнер стал доступен.

2. Ingress-контроллер в K3s — Traefik, а не nginx
В манифесте ingress-tls.yaml пришлось указать ingressClassName: traefik, иначе Ingress не работал. После исправления Ingress успешно применился.

3. Команда для добавления записи в /etc/hosts
Вместо echo "$(minikube ip) webapp.local" | sudo tee -a /etc/hosts использовали:
echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts
Запись добавилась корректно, curl по домену стал проходить.

4. curl без --cacert выдавал ошибку самоподписанного сертификата
Так как сертификат подписан собственным CA, который не встроен в системное хранилище, curl отказывался доверять. Добавление --cacert ca.crt решило проблему. Для проверки без проверки можно было использовать -k, но в работе использовали правильный путь с CA.

![Снимок экрана.png](./Снимок%20экрана%20от%202026-04-01%2010-01-41.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-04-01%2010-13-56.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-04-01%2010-14-05.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-04-01%2010-14-33.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-04-01%2010-17-17.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-04-01%2010-25-25.png)

![Снимок экрана.png](./Снимок%20экрана%20от%202026-04-01%2010-29-24.png)