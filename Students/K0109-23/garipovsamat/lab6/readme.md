# Лабораторная 6 — Kubernetes: ConfigMap, Secret, PersistentVolume
# Что за лаба

Тема — конфиги, пароли и данные отдельно от кода. Чтобы можно было поменять настройки без пересборки образа, и чтобы база данных не сдохла если под перезапустится.

## Блок 1 — ConfigMap
### Что это вообще

ConfigMap — это тема, которая хранит конфигурацию отдельно от пода. Можно положить туда переменные окружения, файлы конфигов, что угодно с буквами русскими английскими. Потом под это все подтягивает.

Зачем это надо: допустим приложение работает в dev и prod. В dev нужно логировать всё, в prod — только ошибки. Вместо того чтобы пересобирать образ под каждое окружение, ты просто делаешь два ConfigMap и подключаешь нужный.

Создал ConfigMap из литералов
```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_CONNECTIONS=100
```

Это просто команда, которая создает объект с тремя ключами и значениями.

Посмотрел что получилось:
```bash
kubectl get configmap app-config -o yaml
```

Вывод — обычный yaml с данными. Никакого шифрования, просто текст.

Создал ConfigMap из файла

Сделал файлик nginx.conf с простой конфигурацией:
```
server {
    listen 80;
    server_name localhost;
    location /health { return 200 "OK"; }
}
```
И загрузил его в ConfigMap:
```bash
kubectl create configmap nginx-conf --from-file=nginx.conf
```

Под с ConfigMap (три способа передачи)

Создал под config-demo, в котором три способа одновременно:

* envFrom — берет ВСЕ ключи из ConfigMap и делает из них переменные окружения. Самый удобный способ, когда нужно передать много переменных.

* env + configMapKeyRef — берет конкретный ключ и кладет в конкретную переменную. Когда нужно переименовать или взять только один ключ.

* volumeMounts — монтирует как файл. Удобно для конфигов (nginx.conf, application.properties), которые не переменные окружения, а полноценные файлы.

Запустил под:
```bash
kubectl logs config-demo
```

![alt text](<screens/Вставленное изображение.png>)

В логах увидел:

* переменные окружения (APP_ENV=production, LOG_LEVEL=info и т.д.)

* содержимое файла /etc/config/nginx.conf (тот самый конфиг)

Все три способа работают.

## Блок 2 — Secrets
### Что это

Secret — это то же самое что ConfigMap, но для чувствительных данных: пароли, токены, ключи.

Важное отличие: Secret не выводится в логах, не виден через kubectl describe (покажет только имя, не значение). Но это все равно не шифрование.

Создал Secret с паролем
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=SuperSecret123
```
![alt text](<screens/Вставленное изображение (2).png>)

Посмотрел что внутри
```bash
kubectl get secret db-credentials -o yaml
```
Вывод:
```text
data:
  password: U3VwZXJTZWNyZXQxMjM=
  username: YWRtaW4=
```

Это base64, а не шифрование. Расшифровать легко:
```bash
echo "U3VwZXJTZWNyZXQxMjM=" | base64 -d
```

![alt text](<screens/Вставленное изображение (3).png>)

Вывелось SuperSecret123. То есть любой, у кого есть доступ к кластеру и права на чтение Secret, может посмотреть пароль.
Почему это проблема

По умолчанию все Secrets в Kubernetes хранятся в etcd в base64. Если дура получит дамп etcd — она увидит все пароли в открытом виде. Настоящее шифрование нужно включать отдельно через EncryptionConfiguration с алгоритмами типа aescbc. Или вообще не хранить секреты в etcd, а использовать внешние системы типа HashiCorp Vault, AWS Secrets Manager.

Запустил под с Secret

Создал под secret-demo, который в переменные окружения подтянул логин и пароль.
```bash
kubectl logs secret-demo
```

![alt text](<screens/Вставленное изображение (4).png>)

## Блок 3 — PersistentVolume 
### Зачем это

В Docker если контейнер удалить, данные в нем пропадают. В Kubernetes тоже самое — если под удалить, все что внутри контейнера исчезает. Для баз данных это проблема. PersistentVolume (PV) и PersistentVolumeClaim (PVC) решают эту проблему — данные живут отдельно от пода.
Как это работает

* PV — это кусок дискового пространства в кластере (может быть на облачном диске, на локальном диске ноды, на NFS)

* PVC — это заявка на этот диск. Под привязывается к PVC, а не напрямую к PV.

Создал PVC

В файле postgres-pvc.yaml создали PVC на 1 гигабайт. Указали storageClassName: standard — какой диск использовать.

Проверил:
```bash
kubectl get pvc
kubectl get pv
```
![alt text](<screens/Вставленное изображение (6).png>)

PVC стал Bound — значит нашелся подходящий диск.
Запустили PostgreSQL

Создал Deployment с Postgres, который:

* использует этот PVC для хранения данных

* тянет пароли из Secret (через envFrom)

Создал данные

Зашел в под с Postgres и создал таблицу с данными:
```sql
CREATE TABLE sessions (id SERIAL, data TEXT);
INSERT INTO sessions (data) VALUES ('важные данные');
```
Проверил, что данные записались:
```sql
SELECT * FROM sessions;
```

Вывело табличку с записью.
Удалил под (но PVC остался)
```bash
kubectl delete pod <имя>
```

Deployment увидел что под умер и создал новый (автоматически, потому что replicas: 1).
Данные на месте

Зашел в новый под:
```sql
SELECT * FROM sessions;
```
```bash
➜  lab6 git:(k0109-23/garipov) ✗ kubectl exec -it $(kubectl get pod -l app=postgres -o name | cut -d/ -f2) -- \
  psql -U pguser -d mydb -c "CREATE TABLE sessions (id SERIAL, data TEXT); INSERT INTO sessions (data) VALUES ('важные данные');"
CREATE TABLE
INSERT 0 1
➜  lab6 git:(k0109-23/garipov) ✗ kubectl exec -it $(kubectl get pod -l app=postgres -o name | cut -d/ -f2) -- \
  psql -U pguser -d mydb -c "SELECT * FROM sessions;"
 id |     data      
----+---------------
  1 | важные данные
(1 row)

➜  lab6 git:(k0109-23/garipov) ✗ kubectl delete pod $(kubectl get pod -l app=postgres -o name | cut -d/ -f2)
pod "postgres-7f99b57d68-hfndq" deleted from default namespace
➜  lab6 git:(k0109-23/garipov) ✗ kubectl get pods -w
NAME                           READY   STATUS    RESTARTS      AGE
api-backend-794785cfbb-tt62b   1/1     Running   0             43m
config-demo                    1/1     Running   0             8m44s
my-webserver                   2/2     Running   1 (96m ago)   99m
nginx                          1/1     Running   0             105m
postgres-7f99b57d68-7n88z      1/1     Running   0             3s
secret-demo                    1/1     Running   0             2m55s
webapp-696d966cdc-rqs2n        1/1     Running   0             51m
webapp-696d966cdc-tvfgl        1/1     Running   0             51m
webapp-696d966cdc-txsxt        1/1     Running   0             51m
^C%                                                                                                ➜  lab6 git:(k0109-23/garipov) ✗ kubectl exec -it $(kubectl get pod -l app=postgres -o name | cut -d/ -f2) -- \
  psql -U pguser -d mydb -c "SELECT * FROM sessions;"
 id |     data      
----+---------------
  1 | важные данные
(1 row)
```
Вывело ту же таблицу. Данные сохранились, потому что PVC остался, а новый под примонтировал тот же диск.