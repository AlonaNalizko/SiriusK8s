Отчёт по лабораторной работе: «Docker: сети, volumes, docker-compose»

Блок 1 — Docker networking
Что делали:
Сначала посмотрели доступные сети командой docker network ls. Стандартные сети: bridge, host, none. Команда docker network inspect bridge показала детали: подсеть 172.17.0.0/16, шлюз 172.17.0.1. Bridge-сеть работает как изолированный коммутатор — контейнеры в ней могут общаться друг с другом.

Создали свою изолированную сеть:

docker network create --driver bridge app-network
Запустили контейнер с PostgreSQL в этой сети:
docker run -d --name db --network app-network -e POSTGRES_PASSWORD=secret postgres:16-alpine
Затем запустили временный контейнер с alpine в той же сети и проверили доступ:

docker run -it --rm --network app-network alpine sh
ping db
nc -zv db 5432
Внутри alpine ping db отработал — DNS в пользовательской сети разрешил имя контейнера в IP-адрес. Порт 5432 оказался открыт.

Для сравнения запустили контейнер без указания сети:

docker run -it --rm alpine ping db
Команда не нашла хост db — контейнеры видят друг друга только в общей сети.

Вывод: Каждая пользовательская сеть даёт контейнерам собственную DNS-таблицу, где имена соответствуют именам контейнеров. Контейнеры в разных сетях не видят друг друга.

Блок 2 — Volumes и persistent data
Что делали:

Создали том для хранения данных PostgreSQL:

docker volume create pgdata
Запустили контейнер с монтированием тома:

bash
docker run -d \
  --name postgres-persistent \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=pass \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16-alpine
Создали тестовую таблицу и вставили данные.
Удалили контейнер:

docker rm -f postgres-persistent
Запустили новый контейнер с тем же томом и проверили, что данные сохранились:

docker exec postgres-restored psql -U user -d mydb -c "SELECT * FROM items;"
Вывод показал 1 | test — данные пережили удаление контейнера.

Команда docker volume inspect pgdata показала физическое расположение тома: /var/lib/docker/volumes/pgdata/_data.

Контрольный вопрос: Почему данные не удалились при удалении контейнера?
Потому что том pgdata был создан отдельно и смонтирован в контейнер. Данные физически лежат в каталоге Docker на хосте, а не внутри контейнера. При удалении контейнера том остаётся нетронутым.

Блок 3 — docker-compose
Что делали:
Создали структуру проекта:

backend/app.py — Flask-приложение с двумя маршрутами: /api/items (возвращает данные из БД) и /health (для проверки готовности).

backend/requirements.txt — зависимости: flask==3.0.0, psycopg2-binary==2.9.9.

backend/Dockerfile — образ на python:3.12-alpine, копирует код и устанавливает зависимости.

Создали файл frontend/nginx.conf:

nginx
server {
    listen 80;
    location /api/ {
        proxy_pass http://backend:5000/api/;
        proxy_set_header Host $host;
    }
    location / {
        return 200 '<h1>Frontend OK</h1><p>API: <a href="/api/items">/api/items</a></p>';
        add_header Content-Type text/html;
    }
}
Nginx проксирует запросы на /api/ в backend-сервис.

Создали docker-compose.yml с тремя сервисами:

db	- PostgreSQL - Том pgdata для данных, healthcheck через pg_isready
backend	- Flask-API - Сборка из ./backend, зависит от db (ждёт healthcheck), свой healthcheck на /health
frontend - Nginx - Готовый образ nginx:alpine, проброс порта 8080, монтирование конфига, зависит от backend (ждёт healthcheck)
Запустили стек, сборка заняла около 10 секунд, все сервисы поднялись.

Проверка статуса:

docker compose ps
Все три сервиса в статусе healthy.

Создание тестовых данных в БД:

docker compose exec db psql -U user -d mydb -c \
  "CREATE TABLE IF NOT EXISTS items (id SERIAL, name TEXT); \
   INSERT INTO items (name) VALUES ('apple'), ('banana'), ('cherry');"
Запрос выполнился успешно.

Проверка цепочки frontend -> backend -> db:

curl localhost:8080/api/items
Вывод:
Nginx принял запрос на порту 8080, перенаправил его в backend, backend подключился к БД, вернул данные.

Масштабирование backend:
docker compose up -d --scale backend=3
Появились три экземпляра backend: compose-lab-backend-1, compose-lab-backend-2, compose-lab-backend-3. Nginx балансирует запросы между ними.

Остановка и очистка:

docker compose down
docker compose down -v   # с удалением томов
Команда docker volume ls показала, что том compose-lab_pgdata был удалён.


![Снимок экрана1.png](Снимок экрана1.png)
Данные PostgreSQL сохранились после пересоздания контейнера

![Снимок экрана2.png](Снимок экрана2.png)

![Снимок экрана3.png](Снимок экрана3.png)

![Снимок экрана4.png](Снимок экрана4.png)
