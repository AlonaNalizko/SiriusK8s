Отчёт по лабораторной работе: «Безопасность Kubernetes: RBAC, NetworkPolicy, TLS, Falco»

В рамках выполнения лабораторной работы изучаются механизмы безопасности Kubernetes: управление доступами с помощью RBAC, изоляция сетевого трафика через NetworkPolicy, настройка TLS-шифрования с помощью собственных сертификатов и обнаружение подозрительной активности с помощью Falco. Цель работы – освоить принцип минимальных привилегий, научиться ограничивать доступ и трафик между приложениями, а также понимать, как шифровать трафик и отслеживать аномалии в кластере.

1. RBAC – управление доступом
Для демонстрации управления доступом создаётся отдельное пространство имён rbac-demo. В файле rbac.yaml описываются три объекта.

ServiceAccount с именем app-reader – учётная запись, от имени которой будет работать приложение. Role pod-reader определяет разрешения: только чтение подов и их логов (глаголы get, list, watch) в пространстве имён rbac-demo. RoleBinding связывает ServiceAccount с этой Role.

После применения конфигурации проверяются права с помощью kubectl auth can-i. Команда kubectl auth can-i list pods --namespace rbac-demo --as=system:serviceaccount:rbac-demo:app-reader возвращает yes – поды можно читать. Команда kubectl auth can-i delete pods --namespace rbac-demo --as=system:serviceaccount:rbac-demo:app-reader возвращает no – удалять поды нельзя. Команда kubectl auth can-i list pods --namespace default --as=system:serviceaccount:rbac-demo:app-reader возвращает no – права ограничены только пространством имён rbac-demo.

Создаётся под rbac-test, который использует ServiceAccount app-reader. Внутри пода выполняется проверка прав: kubectl get pods -n rbac-demo работает, kubectl delete pod rbac-test -n rbac-demo запрещён, kubectl get pods -n default также запрещён. Это подтверждает, что ServiceAccount получил только те права, которые были явно разрешены в Role.

2. NetworkPolicy – изоляция сетевого трафика
Для тестирования сетевой изоляции создаётся пространство имён netpol-demo. В нём запускаются три пода: frontend, backend и database – все на образе nginx:alpine. Каждый под экспонируется через Service с именем, соответствующим его роли.

До применения политик проверяется, что все поды могут общаться друг с другом. kubectl exec frontend -n netpol-demo -- wget -qO- backend-svc возвращает приветственную страницу nginx. kubectl exec frontend -n netpol-demo -- wget -qO- database-svc также возвращает страницу – это нежелательная ситуация, так как frontend не должен иметь прямого доступа к базе данных.

Создаётся файл networkpolicies.yaml с четырьмя политиками. Первая – default-deny-ingress – запрещает весь входящий трафик ко всем подам в пространстве имён. Вторая – allow-frontend-ingress – разрешает внешний трафик к frontend (например, от Ingress). Третья – allow-backend-from-frontend – разрешает backend принимать трафик только от подов с меткой role: frontend. Четвёртая – allow-database-from-backend – разрешает database принимать трафик только от подов с меткой role: backend.

После применения политик проверяется изоляция. kubectl exec frontend -n netpol-demo -- wget -qO- --timeout=3 backend-svc работает (разрешено). kubectl exec frontend -n netpol-demo -- wget -qO- --timeout=3 database-svc завершается с таймаутом (запрещено). kubectl exec backend -n netpol-demo -- wget -qO- --timeout=3 database-svc работает (backend → database разрешено). Команда kubectl get networkpolicies -n netpol-demo показывает все четыре применённые политики.

3. TLS сертификаты с OpenSSL
Для шифрования трафика создаётся собственная инфраструктура открытых ключей. В директории ~/ssl-lab генерируется корневой сертификат CA. Команда openssl genrsa -out ca.key 4096 создаёт приватный ключ. Команда openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/C=RU/ST=Moscow/O=SiriusLab CA/CN=SiriusLab Root CA" создаёт самоподписанный корневой сертификат на 10 лет. Проверка командой openssl x509 -in ca.crt -noout -text | grep -E "Issuer:|Subject:|Not (Before|After)" показывает корректные данные.


Для веб-сервера создаётся конфигурационный файл webapp.ext с расширениями Subject Alternative Names (SAN), включающими домены webapp.local и www.webapp.local, а также IP-адрес 127.0.0.1. Генерируется ключ сервера webapp.key и запрос на подпись сертификата (CSR) с помощью openssl req -new -key webapp.key -out webapp.csr -subj "/C=RU/O=SiriusLab/CN=webapp.local".

Сертификат подписывается корневым CA: openssl x509 -req -in webapp.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out webapp.crt -days 365 -sha256 -extfile webapp.ext. Проверка openssl x509 -in webapp.crt -noout -text | grep -A5 "Subject Alternative" показывает правильные DNS и IP. Команда openssl verify -CAfile ca.crt webapp.crt возвращает OK.

Сертификат загружается в Kubernetes как Secret типа TLS: kubectl create secret tls webapp-tls --cert=webapp.crt --key=webapp.key -n netpol-demo. Проверка kubectl describe secret webapp-tls -n netpol-demo показывает, что Secret содержит данные tls.crt и tls.key.

Создаётся файл ingress-tls.yaml с Ingress, использующим этот Secret. Поскольку кластер работает на K3s, в качестве ingressClassName указывается traefik. После применения Ingress добавляется запись в /etc/hosts: echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts.

Проверка TLS-соединения: curl --cacert ca.crt https://webapp.local возвращает приветственную страницу nginx. Команда openssl s_client -connect webapp.local:443 -CAfile ca.crt -showcerts 2>&1 | grep -E "subject=|issuer=|Verify return code" показывает Verify return code: 0 (ok), что подтверждает успешную проверку сертификата.

Для извлечения сертификата из Secret выполняется kubectl get secret webapp-tls -n netpol-demo -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep -E "Subject:|Issuer:|DNS:|IP:|Not ". Вывод показывает все данные сертификата, включая срок действия.

4. Falco – обнаружение угроз (бонус)
Для демонстрации работы Falco запускается мониторинг логов: kubectl logs -n falco -l app.kubernetes.io/name=falco -f. При входе в контейнер frontend через kubectl exec -it frontend -n netpol-demo -- sh Falco генерирует алерт "A shell was spawned in a container". При попытке прочитать чувствительный файл /etc/shadow командой kubectl exec frontend -n netpol-demo -- cat /etc/shadow 2>/dev/null || true Falco генерирует алерт "Read sensitive file untrusted".

Ошибки и сложности
Проблема с входом в под rbac-test. При первой попытке выполнить kubectl exec -it rbac-test -n rbac-demo -- sh возникла ошибка container not found. Повторная команда сработала – под успел запуститься, контейнер стал доступен.

Проблема с Ingress-контроллером в K3s. В манифесте ingress-tls.yaml изначально был указан ingressClassName: nginx. В K3s по умолчанию используется Traefik. После изменения на ingressClassName: traefik Ingress успешно применился, и адрес стал доступен.

Проблема с добавлением записи в /etc/hosts. Вместо echo "$(minikube ip) webapp.local" (minikube не использовался) использовалась команда с извлечением IP узла: echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') webapp.local" | sudo tee -a /etc/hosts. Запись добавилась корректно.

Проблема с проверкой TLS. При выполнении curl https://webapp.local без --cacert возникала ошибка самоподписанного сертификата. Добавление --cacert ca.crt решило проблему. Для быстрой проверки можно использовать -k, но в работе использовался правильный путь с доверенным CA.

Результаты выполнения
kubectl auth can-i list pods – возвращает yes (можно читать поды)

kubectl auth can-i delete pods – возвращает no (нельзя удалять поды)

kubectl exec frontend -- wget database-svc – timeout (NetworkPolicy запретила)

kubectl exec backend -- wget database-svc – 200 OK (разрешено)

openssl verify -CAfile ca.crt webapp.crt – webapp.crt: OK

curl --cacert ca.crt https://webapp.local – приветственная страница nginx



![Снимок экрана](./Снимок%20экрана%202026-03-31%20154528.png)
![Снимок экрана](./Снимок%20экрана%202026-04-01%20093511(1).png)
![Снимок экрана](./Снимок%20экрана%202026-04-01%20093511.png)
![Снимок экрана](./Снимок%20экрана%202026-04-01%20093645.png)
![Снимок экрана](./Снимок%20экрана%202026-04-01%20094952.png)
