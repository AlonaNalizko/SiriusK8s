Отчёт по лабораторной работе: «Kubernetes: ConfigMap, Secret, PersistentVolume»

В рамках выполнения лабораторной работы изучается управление конфигурацией приложения с помощью ConfigMap и Secret, а также организация постоянного хранилища с использованием PersistentVolumeClaim. Цель работы – научиться отделять конфигурацию от кода приложения, безопасно передавать чувствительные данные и обеспечивать сохранность данных при перезапуске подов.

1. ConfigMap
Для управления конфигурацией приложения создаётся ConfigMap из литералов командой kubectl create configmap app-config --from-literal=APP_ENV=production --from-literal=LOG_LEVEL=info --from-literal=MAX_CONNECTIONS=100. Команда kubectl get configmap app-config -o yaml показывает содержимое ConfigMap, а kubectl describe configmap app-config выводит данные в удобочитаемом виде.

Создаётся файл pod-with-config.yaml, в котором демонстрируются три способа передачи конфигурации в под. Первый способ – использование envFrom для загрузки всех ключей ConfigMap как переменных окружения. Второй способ – выбор конкретного ключа через configMapKeyRef с присвоением собственного имени переменной. Третий способ – монтирование ConfigMap как файла через volumeMounts и volumes.

Для тестирования монтирования ConfigMap как файла создаётся файл nginx.conf с простой конфигурацией сервера. Из этого файла создаётся ConfigMap: kubectl create configmap nginx-conf --from-file=nginx.conf.

После применения конфигурации пода командой kubectl apply -f pod-with-config.yaml логи пода показывают все три способа передачи конфигурации. Переменные окружения APP_ENV, LOG_LEVEL, MAX_CONNECTIONS и MY_ENV выведены корректно. Также выведено содержимое файла /etc/config/nginx.conf, что подтверждает успешное монтирование ConfigMap как файла.

2. Secrets
Для хранения чувствительной информации создаётся Secret командой kubectl create secret generic db-credentials --from-literal=username=admin --from-literal=password=SuperSecret123. Команда kubectl get secret db-credentials -o yaml показывает, что данные хранятся в base64-кодированном виде. Декодирование выполняется командой echo "U3VwZXJTZWNyZXQxMjM=" | base64 -d.

Создаётся файл pod-with-secret.yaml, в котором Secret передаётся в под через переменные окружения. В спецификации пода указываются env с secretKeyRef для каждого ключа Secret.

После применения конфигурации командой kubectl apply -f pod-with-secret.yaml логи пода kubectl logs secret-demo показывают, что переменные DB_USER и DB_PASS успешно переданы и содержат правильные значения (admin и SuperSecret123).

Важный разговор о безопасности Secrets: Secret в Kubernetes по умолчанию только закодирован в base64, но не зашифрован. Это не обеспечивает безопасность – любой, кто имеет доступ к API-серверу или к etcd, может прочитать секреты. Для настоящего шифрования требуется настройка EncryptionConfiguration с использованием алгоритмов aescbc или aesgcm, либо использование внешних решений, таких как HashiCorp Vault или AWS Secrets Manager.

3. PersistentVolume
Для обеспечения постоянного хранения данных PostgreSQL создаётся файл postgres-pvc.yaml, который содержит несколько объектов. PersistentVolumeClaim запрашивает 1 GiB хранилища с доступом ReadWriteOnce. Secret postgres-secret хранит учётные данные для базы данных. Deployment описывает контейнер PostgreSQL, который использует переменные окружения из Secret, монтирует PVC в /var/lib/postgresql/data и имеет ресурсные ограничения. Service открывает доступ к PostgreSQL внутри кластера.

Применение конфигурации: kubectl apply -f postgres-pvc.yaml. Команда kubectl get pvc показывает статус PVC. В K3s для PVC используется storageClassName: local-path, а не standard, как указано в методичке для minikube. После замены значения PVC успешно переходит в статус Bound.

Для проверки сохранности данных создаётся тестовая таблица: kubectl exec -it $(kubectl get pod -l app=postgres -o name) -- psql -U pguser -d mydb -c "CREATE TABLE sessions (id SERIAL, data TEXT); INSERT INTO sessions (data) VALUES ('важные данные');".


После этого под удаляется: kubectl delete pod $(kubectl get pod -l app=postgres -o name | cut -d/ -f2). Deployment автоматически создаёт новый под. Команда kubectl get pods -w показывает, что новый под переходит в состояние Running.

Проверка данных в новом поде: kubectl exec -it $(kubectl get pod -l app=postgres -o name) -- psql -U pguser -d mydb -c "SELECT * FROM sessions;". Данные сохранились – это доказывает, что PVC обеспечивает постоянное хранение, независимое от жизненного цикла пода.

Ошибки и сложности
Проблема с монтированием ConfigMap как файла. В первоначальном файле pod-with-config.yaml отсутствовали секции volumeMounts и volumes для третьего способа передачи ConfigMap. В результате команда cat /etc/config/nginx.conf внутри пода не находила файл. После добавления секций volumeMounts с mountPath: /etc/config и volumes с configMap ссылкой на nginx-conf под стал видеть файл, и в логах появилось содержимое nginx.conf.

Проблема с PVC в статусе Pending. В методичке для minikube указан storageClassName: standard. В K3s стандартный provisioner называется local-path. При первом применении PVC оставался в статусе Pending. После изменения значения на local-path PVC успешно привязался к PV и перешёл в статус Bound.

Secret отображается в base64, а не в открытом виде. При просмотре Secret через kubectl get secret -o yaml данные были в base64. Это нормальное поведение Kubernetes. Важно понимать, что base64 – это не шифрование, а только кодирование. При наличии доступа к etcd данные можно прочитать в открытом виде.

Результаты выполнения
kubectl logs config-demo – выведены переменные окружения из ConfigMap (APP_ENV, LOG_LEVEL, MAX_CONNECTIONS, MY_ENV) и содержимое смонтированного файла nginx.conf

kubectl get secret db-credentials -o yaml – данные username и password в base64

kubectl get pvc postgres-pvc – статус Bound

SELECT * FROM sessions после пересоздания пода – данные (важные данные) сохранились

![Снимок экрана](./Снимок%20экрана%202026-03-31%20154125.png)
![Снимок экрана](./Снимок%20экрана%202026-03-31%20154146.png)
![Снимок экрана](./Снимок%20экрана%202026-04-01%20091352.png)
![Снимок экрана](./Снимок%20экрана%202026-04-01%20091448.png)