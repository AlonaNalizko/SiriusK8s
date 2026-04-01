Отчёт по лабораторной работе: «Kubernetes: ConfigMap, Secret, PersistentVolume»

Блок 1 — ConfigMap
Создали ConfigMap app-config из литералов (из значений, написанных прямо в команде, а не из файла) командой:

sudo kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_CONNECTIONS=100
Проверили содержимое через kubectl get configmap app-config -o yaml и kubectl describe configmap app-config. ConfigMap содержит три ключа: APP_ENV, LOG_LEVEL, MAX_CONNECTIONS.

Создание ConfigMap из файла:
Создали файл nginx.conf с конфигурацией сервера (слушает порт 80, отдаёт OK на /health). Затем создали ConfigMap nginx-conf командой:

sudo kubectl create configmap nginx-conf --from-file=nginx.conf
Pod с ConfigMap:
Создали файл pod-with-config.yaml, в котором описан под config-demo с контейнером на busybox. В поде использован первый способ передачи ConfigMap — envFrom, который загружает все ключи из ConfigMap app-config как переменные окружения. Также в поде настроено монтирование ConfigMap nginx-conf как файла в директорию /etc/config.

Применили манифест:
sudo kubectl apply -f pod-with-config.yaml
Проверили логи пода:
sudo kubectl logs config-demo
В выводе: 
-переменные окружения из app-config: LOG_LEVEL=info, MAX_CONNECTIONS=100, APP_ENV=production

-содержимое файла /etc/config/nginx.conf (полный текст конфига nginx)

Оба способа передачи ConfigMap сработали корректно.

Блок 2 — Secrets
Создали Secret db-credentials с двумя литералами (с двумя парами «ключ=значение», указанными прямо в команде):

sudo kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=SuperSecret123
Посмотрели содержимое Secret через kubectl get secret db-credentials -o yaml. Данные хранятся в кодировке base64:

- username: YWRtaW4= (декодируется в admin)
- password: U3VwZXJTZWNyZXQxMjM= (декодируется в SuperSecret123)

Pod с Secret:
Создали файл pod-with-secret.yaml с подом secret-demo. В манифесте переменные окружения DB_USER и DB_PASS получают значения из Secret через secretKeyRef. В команде контейнера эти переменные выводятся на экран.

Применили манифест и проверили логи:

sudo kubectl logs secret-demo
Вывод: 
User: admin и Pass: SuperSecret123. Secret успешно передан в под.

Блок 3 — PersistentVolume
Создали файл postgres-pvc.yaml, который содержит три объекта:

- PersistentVolumeClaim с именем postgres-pvc: запрашивает 1Gi хранилища, режим доступа ReadWriteOnce. В качестве storageClassName указан local-path (для K3s это стандартный provisioner).
- Secret postgres-secret с переменными для PostgreSQL (POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD). Использовано поле stringData, которое автоматически кодируется в base64.
- Deployment postgres с одной репликой: образ postgres:16-alpine, переменные окружения из Secret (через envFrom), монтирование тома data в /var/lib/postgresql/data с привязкой к PVC postgres-pvc.

Применили манифест и проверили PVC и PV:
sudo kubectl get pvc
sudo kubectl get pv
PVC postgres-pvc в статусе Bound (место на диске выделено), PV автоматически создан provisioner'ом local-path с ёмкостью 1Gi.

Проверка сохранения данных:

Создали таблицу и вставили данные через exec в под postgres:

sudo kubectl exec -it $(kubectl get pod -l app=postgres -o name) -- \
  psql -U pguser -d mydb -c \
  "CREATE TABLE sessions (id SERIAL, data TEXT); \
   INSERT INTO sessions (data) VALUES ('важные данные');"
Удалили под postgres (но не PVC):

sudo kubectl delete pod $(kubectl get pod -l app=postgres -o name | cut -d/ -f2)
Deployment автоматически создал новый под. Проверили, что данные сохранились:

sudo kubectl exec -it $(kubectl get pod -l app=postgres -o name) -- \
  psql -U pguser -d mydb -c "SELECT * FROM sessions;"
Вывод: 1 | важные данные. Данные пережили пересоздание пода благодаря PVC.

Ошибки и сложности
1. В pod-with-config.yaml использован только первый способ передачи ConfigMap
В манифесте не были добавлены volumeMounts и volumes для монтирования ConfigMap как файла. В итоге команда cat /etc/config/nginx.conf внутри пода не находила файл. После добавления секций volumeMounts (с mountPath: /etc/config) и volumes (с configMap ссылкой на nginx-conf) под стал видеть файл, и в логах появилось содержимое nginx.conf.

2. В PVC использован storageClassName local-path вместо standard
В методичке для minikube указан storageClassName: standard. В K3s стандартный provisioner называется local-path. Пришлось заменить значение, иначе PVC оставался в статусе Pending. После изменения PVC успешно привязался к PV.

3. Secret отображается в base64, а не в открытом виде
При просмотре Secret через kubectl get secret -o yaml данные были в base64. Это нормальное поведение, но важно понимать, что это не шифрование — при наличии доступа к etcd данные можно прочитать.

![Снимок экрана от 2026-04-01 09-08-47.png](Снимок экрана от 2026-04-01 09-08-47.png)

![Снимок экрана от 2026-04-01 09-29-43.png](Снимок экрана от 2026-04-01 09-29-43.png)

![Снимок экрана от 2026-04-01 09-31-30.png](Снимок экрана от 2026-04-01 09-31-30.png)

![Снимок экрана от 2026-04-01 09-40-42.png](Снимок экрана от 2026-04-01 09-40-42.png)

![Снимок экрана от 2026-04-01 09-48-30.png](Снимок экрана от 2026-04-01 09-48-30.png)