3_laba
Структура отчета: 
# 1 выводы в терминале
# 2. вопросы
# 3. трудности

1. `docker compose ps` — все сервисы `healthy`
sofa@FILOSOF:~/compose-lab$ docker compose logs -f
WARN[0000] /home/sofa/compose-lab/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
backend-1  |  * Serving Flask app 'app'
backend-1  |  * Debug mode: off
backend-1  | WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
backend-1  |  * Running on all addresses (0.0.0.0)
backend-1  |  * Running on http://127.0.0.1:5000
backend-1  |  * Running on http://172.19.0.3:5000
backend-1  | Press CTRL+C to quit
db-1       | The files belonging to this database system will be owned by user "postgres".
db-1       | This user must also own the server process.
db-1       |
db-1       | The database cluster will be initialized with locale "en_US.utf8".
db-1       | The default database encoding has accordingly been set to "UTF8".
db-1       | The default text search configuration will be set to "english".
db-1       |
db-1       | Data page checksums are disabled.
db-1       |
db-1       | fixing permissions on existing directory /var/lib/postgresql/data ... ok
db-1       | creating subdirectories ... ok
db-1       | selecting dynamic shared memory implementation ... posix
db-1       | selecting default max_connections ... 100
db-1       | selecting default shared_buffers ... 128MB
db-1       | selecting default time zone ... UTC
db-1       | creating configuration files ... ok
db-1       | running bootstrap script ... ok
db-1       | sh: locale: not found
db-1       | 2026-03-27 11:06:00.534 UTC [35] WARNING:  no usable system locales were found
db-1       | performing post-bootstrap initialization ... ok
db-1       | syncing data to disk ... ok
db-1       |
db-1       |
db-1       | Success. You can now start the database server using:
db-1       |
db-1       |     pg_ctl -D /var/lib/postgresql/data -l logfile start
db-1       |
db-1       | initdb: warning: enabling "trust" authentication for local connections
db-1       | initdb: hint: You can change this by editing pg_hba.conf or using the option -A, or --auth-local and --auth-host, the next time you run initdb.
db-1       | waiting for server to start....2026-03-27 11:06:01.702 UTC [41] LOG:  starting PostgreSQL 16.13 on x86_64-pc-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit
db-1       | 2026-03-27 11:06:01.705 UTC [41] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1       | 2026-03-27 11:06:01.712 UTC [44] LOG:  database system was shut down at 2026-03-27 11:06:00 UTC
db-1       | 2026-03-27 11:06:01.717 UTC [41] LOG:  database system is ready to accept connections
db-1       |  done
db-1       | server started
db-1       | CREATE DATABASE
db-1       |
db-1       |
db-1       | /usr/local/bin/docker-entrypoint.sh: ignoring /docker-entrypoint-initdb.d/*
db-1       |
db-1       | waiting for server to shut down....2026-03-27 11:06:01.838 UTC [41] LOG:  received fast shutdown request
db-1       | 2026-03-27 11:06:01.841 UTC [41] LOG:  aborting any active transactions
db-1       | 2026-03-27 11:06:01.843 UTC [41] LOG:  background worker "logical replication launcher" (PID 47) exited with exit code 1
db-1       | 2026-03-27 11:06:01.843 UTC [42] LOG:  shutting down
db-1       | 2026-03-27 11:06:01.845 UTC [42] LOG:  checkpoint starting: shutdown immediate
db-1       | 2026-03-27 11:06:02.124 UTC [42] LOG:  checkpoint complete: wrote 926 buffers (5.7%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.013 s, sync=0.255 s, total=0.282 s; sync files=301, longest=0.003 s, average=0.001 s; distance=4272 kB, estimate=4272 kB; lsn=0/191E928, redo lsn=0/191E928
db-1       | 2026-03-27 11:06:02.129 UTC [41] LOG:  database system is shut down
db-1       |  done
db-1       | server stopped
db-1       |
db-1       | PostgreSQL init process complete; ready for start up.
db-1       |
db-1       | 2026-03-27 11:06:02.156 UTC [1] LOG:  starting PostgreSQL 16.13 on x86_64-pc-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit
db-1       | 2026-03-27 11:06:02.156 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
db-1       | 2026-03-27 11:06:02.156 UTC [1] LOG:  listening on IPv6 address "::", port 5432
db-1       | 2026-03-27 11:06:02.161 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
db-1       | 2026-03-27 11:06:02.168 UTC [57] LOG:  database system was shut down at 2026-03-27 11:06:02 UTC
db-1       | 2026-03-27 11:06:02.173 UTC [1] LOG:  database system is ready to accept connections
^C
sofa@FILOSOF:~/compose-lab$


2. `curl localhost:8080/api/items` — данные из БД через nginx
sofa@FILOSOF:~/compose-lab$ curl localhost:8080/api/items
[{"id":1,"name":"apple"},{"id":2,"name":"banana"},{"id":3,"name":"cherry"}]
sofa@FILOSOF:~/compose-lab$


3. `docker compose ps` после `--scale backend=3` — 3 экземпляра backend
sofa@FILOSOF:~/compose-lab$ docker compose ps
NAME                     IMAGE                 COMMAND                  SERVICE    CREATED          STATUS                    PORTS
compose-lab-backend-1    compose-lab-backend   "python app.py"          backend    3 minutes ago    Up 2 minutes (healthy)
compose-lab-backend-2    compose-lab-backend   "python app.py"          backend    17 seconds ago   Up 17 seconds (healthy)
compose-lab-backend-3    compose-lab-backend   "python app.py"          backend    17 seconds ago   Up 16 seconds (healthy)
compose-lab-db-1         postgres:16-alpine    "docker-entrypoint.s…"   db         3 minutes ago    Up 3 minutes (healthy)    5432/tcp
compose-lab-frontend-1   nginx:alpine          "/docker-entrypoint.…"   frontend   3 minutes ago    Up 2 minutes              0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
sofa@FILOSOF:~/compose-lab$

Вопросы:
1. Почему контейнеры видят друг друга по имени в одной сети, а в разных — нет? (Блок 1)

Каждая сеть — отдельный DNS. В одной сети Docker автоматически резолвит имена контейнеров, в другой — нет, как разные телефонные книги.
2. Почему данные в БД сохранились после удаления контейнера? (Блок 2)

Volume (pgdata) живёт отдельно от контейнера. Удаление контейнера не стирает volume — новые контейнеры подключаются к тем же данным.
3. Зачем healthcheck и почему wget не сработал? (Блок 3)

Healthcheck проверяет, что сервис реально готов. wget не сработал — его нет в Alpine. Заменили на Python-скрипт.
4. Как работает depends_on: condition: service_healthy? (Блок 3)

Ждёт не просто старта контейнера, а успешного прохождения healthcheck. Гарантирует, что БД готова, прежде чем backend к ней подключится.

5. Что делает --scale backend=3? (Блок 3)
Запускает 3 копии backend. Docker DNS автоматически балансирует запросы между ними (round-robin).


Сложности:
   1. ping: bad address 'db' → забыла запустить контейнер db с --network app-network.
   2. Backend не healthy → wget нет в Alpine, заменила на Python-скрипт.
   3. --scale пересоздавал всё → добавила --no-recreate.

Скину доработки 31.03.2026