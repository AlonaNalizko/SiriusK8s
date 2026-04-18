Отчёт по лабораторной работе: «Docker: сети, volumes, docker-compose»

В рамках выполнения лабораторной работы изучается развёртывание многоконтейнерного приложения с использованием Docker Compose. Цель работы – научиться создавать изолированные сети для контейнеров, использовать persistent volumes для хранения данных, а также поднимать полный стек из трёх сервисов (frontend на nginx, backend на Flask и база данных PostgreSQL) с помощью docker-compose.

---

### 1. Docker networking

Для начала изучаются сетевые возможности Docker. Команда `docker network ls` показывает все доступные сети. По умолчанию существуют три сети: bridge (стандартная), host и none. Команда `docker network inspect bridge` выводит детальную информацию о сети bridge: её подсеть (172.17.0.0/16), шлюз и подключённые контейнеры.

Создаётся собственная изолированная сеть командой `docker network create --driver bridge app-network`. Эта сеть будет работать по драйверу bridge, что обеспечивает изоляцию от других контейнеров.

В созданную сеть запускается контейнер с PostgreSQL с именем db: `docker run -d --name db --network app-network -e POSTGRES_PASSWORD=secret postgres:16-alpine`. Затем запускается временный контейнер с Alpine Linux в той же сети: `docker run -it --rm --network app-network alpine sh`. Внутри этого контейнера выполняется `ping db` – DNS-резолвинг работает, и контейнер видит db по имени. Команда `nc -zv db 5432` подтверждает, что порт PostgreSQL открыт и доступен.

Для сравнения запускается контейнер без указания сети: `docker run -it --rm alpine ping db`. В этом случае имя db не резолвится, так как контейнер находится в другой сети (bridge по умолчанию) и не видит контейнеры из app-network.

**Вывод:** Каждая сеть в Docker – это отдельный network namespace с собственным DNS-сервером, который автоматически резолвит имена контейнеров внутри сети.

---

### 2. Volumes и persistent data

Для обеспечения сохранности данных при перезапуске контейнеров используются volumes. Сначала создаётся том: `docker volume create pgdata`. Затем запускается контейнер PostgreSQL с монтированием этого тома в `/var/lib/postgresql/data`: `docker run -d --name postgres-persistent -e POSTGRES_DB=mydb -e POSTGRES_USER=user -e POSTGRES_PASSWORD=pass -v pgdata:/var/lib/postgresql/data postgres:16-alpine`.

Внутри контейнера создаются тестовые данные: `docker exec -it postgres-persistent psql -U user -d mydb -c "CREATE TABLE items (id SERIAL, name TEXT); INSERT INTO items VALUES (1, 'test');"`.

После этого контейнер удаляется командой `docker rm -f postgres-persistent`. При этом том pgdata остаётся нетронутым. Затем запускается новый контейнер с тем же томом: `docker run -d --name postgres-restored -e POSTGRES_DB=mydb -e POSTGRES_USER=user -e POSTGRES_PASSWORD=pass -v pgdata:/var/lib/postgresql/data postgres:16-alpine`. Проверка данных командой `docker exec postgres-restored psql -U user -d mydb -c "SELECT * FROM items;"` показывает, что созданная ранее запись сохранилась.

Команда `docker volume inspect pgdata` показывает физическое расположение тома на хосте.

---

### 3. docker-compose

Создаётся структура проекта в директории `~/compose-lab` с поддиректориями backend и frontend.

**Backend-приложение** представляет собой Flask-сервер, который подключается к PostgreSQL и возвращает данные из таблицы items. В файле `app.py` реализованы два эндпоинта: `/api/items` для получения списка записей и `/health` для проверки состояния. Переменные окружения (DB_HOST, DB_NAME, DB_USER, DB_PASS) позволяют гибко настраивать подключение к БД.

**Файл `requirements.txt`** содержит зависимости: flask и psycopg2-binary (для работы с PostgreSQL). Используется именно psycopg2-binary, так как в Alpine Linux сборка обычного psycopg2 может вызвать проблемы.

**Dockerfile для backend** использует образ `python:3.12-alpine`, что обеспечивает небольшой размер финального образа. Копируются зависимости, устанавливаются через pip, затем копируется само приложение.


**Nginx в роли frontend** проксирует запросы на backend. Конфигурационный файл `nginx.conf` настраивает проксирование всех запросов на `/api/` к сервису backend на порту 5000. Корневой путь возвращает простую HTML-страницу со ссылкой на API.

**Файл `docker-compose.yml`** описывает три сервиса:

Сервис `db` использует образ `postgres:16-alpine`, задаёт переменные окружения для создания базы данных и пользователя, монтирует том `pgdata` для сохранения данных, а также включает healthcheck – проверку готовности PostgreSQL командой `pg_isready`.

Сервис `backend` собирается из Dockerfile в директории `./backend`. Ему передаются переменные окружения для подключения к БД. С помощью `depends_on` с условием `service_healthy` гарантируется, что контейнер backend запустится только после того, как db станет здоровой. Также у backend есть собственный healthcheck через wget.

Сервис `frontend` использует готовый образ `nginx:alpine`, пробрасывает порт 8080 хоста на 80 порт контейнера, монтирует конфигурационный файл nginx и зависит от backend с условием `service_healthy`.

В секции `volumes` объявляется том `pgdata`.

После написания всех файлов выполняется `docker compose up -d --build`. Сборка проходит успешно, все три контейнера запускаются. Команда `docker compose ps` показывает статус сервисов – db и backend имеют статус healthy.

Для проверки работы в базу данных добавляются тестовые записи через `docker compose exec db psql -U user -d mydb -c "CREATE TABLE IF NOT EXISTS items (id SERIAL, name TEXT); INSERT INTO items (name) VALUES ('apple'), ('banana'), ('cherry');"`. Затем через `curl localhost:8080/api/items` данные успешно возвращаются в формате JSON. Это подтверждает, что цепочка frontend → backend → db работает корректно.

Для проверки масштабирования выполняется команда `docker compose up -d --scale backend=3`. Docker Compose создаёт два дополнительных экземпляра backend-сервиса. `docker compose ps` показывает три контейнера backend с именами backend-1, backend-2 и backend-3. Nginx продолжает работать, проксируя запросы на все три экземпляра.

Остановка всех контейнеров выполняется командой `docker compose down`. Для полной очистки вместе с томами используется `docker compose down -v`. Команда `docker system prune -f` удаляет неиспользуемые контейнеры, сети и кэш сборки.

---

### Ошибки и сложности

**Проблема с healthcheck в backend.** При первом запуске compose backend не стартовал, потому что у него не был настроен healthcheck, но в depends_on у frontend было условие `condition: service_healthy`. Решение – добавить healthcheck для backend.

**Ошибка синтаксиса в docker-compose.yml.** В секции `depends_on` для frontend изначально был указан список `- backend`, но для условия healthcheck требуется словарь. Исправлено на `depends_on: backend: condition: service_healthy`.

**Проблема с psycopg2 в Alpine.** При использовании стандартного пакета `psycopg2` возникали ошибки сборки из-за отсутствия системных зависимостей. Замена на `psycopg2-binary` решила проблему.

**Nginx не видел backend.** В первом варианте nginx.conf использовалось имя `backend` без учёта масштабирования. Это корректно работало, так как Docker Compose создаёт DNS-запись для сервиса, которая балансирует нагрузку между всеми экземплярами.

---

### Результаты выполнения

1. **docker compose ps** – все сервисы (db, backend, frontend) имеют статус healthy
2. **curl localhost:8080/api/items** – возвращается JSON с данными из PostgreSQL
3. **docker compose ps после --scale backend=3** – отображаются три экземпляра backend

![Снимок экрана](./Снимок%20экрана%202026-03-30%20015427.png)
![Снимок экрана](./Снимок%20экрана%202026-03-30%20015511.png)
![Снимок экрана](./Снимок%20экрана%202026-03-30%20015554.png)