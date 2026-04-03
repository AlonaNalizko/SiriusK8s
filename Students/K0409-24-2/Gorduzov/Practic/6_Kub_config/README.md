# <b>СДЕЛАЛ?</b>
<b>ДА, сделал.</b>

* <b>ConfigMap</b> <br>

    ConfigMap хранит конфигурацию приложения (пары "ключ-значение") отдельно от образа контейнера, позволяя менять настройки без пересборки. Используется для несекретных данных: переменные окружения, настройки логирования, конфиг-файлы. Способы передачи в под: через переменные окружения (env/envFrom), монтированием как том (каждый ключ = файл), или в командной строке через $(KEY_NAME). Создаётся из литералов (--from-literal), файлов (--from-file) или директории.

* <b>Secret</b> <br>

    Secret хранит конфиденциальные данные (пароли, токены, ключи). По умолчанию Secret не зашифрован, а только закодирован в base64 — это легко декодируется командой base64 -d. Данные хранятся в etcd в открытом виде, что создаёт угрозу безопасности. Для настоящего шифрования нужна настройка EncryptionConfiguration (алгоритмы aescbc/aesgcm) или внешние решения (HashiCorp Vault, AWS Secrets Manager). В production полагаться только на стандартные Secret без шифрования не рекомендуется. Создаётся командой kubectl create secret generic, в поде монтируется через secretKeyRef.

* <b>PersistentVolume и PersistentVolumeClaim</b> <br>

    PV (PersistentVolume) — ресурс хранилища в кластере (статически или динамически через StorageClass). PVC (PersistentVolumeClaim) — заявка пользователя на хранилище с указанием размера, режима доступа и StorageClass. После создания PVC переходит в статус Bound. Режимы доступа: ReadWriteOnce (RWO) — один под на чтение/запись, ReadOnlyMany (ROX) — много подов на чтение, ReadWriteMany (RWX) — много подов на чтение/запись. В поде том подключается через volumes (ссылка на PVC) и volumeMounts (путь внутри контейнера). Данные сохраняются при удалении пода — новый под подхватывает тот же PVC. Удаление PVC обычно удаляет данные, если не настроена политика retain.


# <b>ПРОБЛЕМЫ</b>
нет проблем

# <b>SCREENШОТЫ</b>
![SCR1](https://github.com/noktirr/SCREENSHOTS/blob/main/6_Kub_config/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2012-35-18.png) <br>
![SCR2](https://github.com/noktirr/SCREENSHOTS/blob/main/6_Kub_config/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2012-37-40.png) <br>
![SCR3](https://github.com/noktirr/SCREENSHOTS/blob/main/6_Kub_config/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2013-07-21.png) <br>
![SCR4](https://github.com/noktirr/SCREENSHOTS/blob/main/6_Kub_config/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2013-11-16.png) <br>