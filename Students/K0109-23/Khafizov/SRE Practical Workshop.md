# Quick Start
---
Запускаем сервисы с помощью `docker compose up --build -d` и смотрим, что у нас всё запустилось `docker compose ps`
<img width="880" height="390" alt="image" src="https://github.com/user-attachments/assets/7d3c75f4-fba5-4c0a-b5e4-e03fd15fd3dd" />

Проверяем, что сервисы `health` и они работают
<img width="883" height="579" alt="image" src="https://github.com/user-attachments/assets/a6aaba34-48a1-45de-b565-5458986bb42c" />
<img width="879" height="413" alt="image" src="https://github.com/user-attachments/assets/c8cd02c1-74f2-4aea-aabc-d2138dab4348" />

**Проблемы, с которыми столкнулся:**
- При запуске `docker compose up --build -d` изначально ругался и выдавал ошибку, что `go.sum` не может запуститься из-за гитхабовских контрольных сумм + `go.mod` тоже ругался на зависимости. Я просто пересоздал их с помощью `go mod init demo` и `go mod tidy`(конфиги по содержанию те же, но зато не выдают ошибок).
- `init-db.sql` не создает таблицы, поэтому в ручную их создал с помощью копирования в контейнер `docker cp init-db.sql practic-postgres-1:/init-db.sql` и выполнил в psql скрипт `docker exec -it practic-postgres-1 psql -U postgres -d demo -f /init-db.sql`. В ходе разборок понял, что скрипт Windows-формата запускается на Alpine + `break-db.sh` не может из-за этого выполниться. P.s: Windows сохраняет файл `CR+LF`, а Linux `LF` из-за этого появлялась ошибка заметил я её, когда просто выполнил `docker compose up`: `postgres-1  | /usr/local/bin/docker-entrypoint.sh: /docker-entrypoint-initdb.d/break-db.sh: /bin/bash^M: bad interpreter: No such file or directory`


## Lesson 1: Nginx Configuration & Reverse Proxying
Начнём с разбора файл `nginx.conf`

### Глобальный контекст
- Задаем пользователя `nginx` от имени, которого будет работать Nginx.
- Указываем кол-во рабочих процессов Nginx в данном случае будет автоматически устанавливаться в зависимости от ядер процессора.
- Записываем путь для записи критических ошибок
- Записываем путь для управления процесса nginx(остановка, перезагрузка)
```nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
```

### Блок `events`
Кол-во одновременных соединений, которые может обрабатывать один процесс
```nginx.conf
events {
  worker_connections 1024;
}
```

### Общие настройки `http`
- Подключение файла с сопоставлением MIME-типов и расширений файлов. Для правильного установления заголовка `Content-Type` для разных типов файлов.
- MIME-тип по умолчанию для файлов, тип которых не удалось определить.
- Описание содержимого логов. В каком формате и как будут записываться.
- Указание файла для логирования доступа + формат в котором будет записываться.
- Активируем системный вызов для эффективной передачи данных.
- Отправка заголовка и начала файла одним ответом.
- Отключение алгоритма Nagle(отправка мелких пакетов одним большим).
- 65 секунд поддержки keep-alive-соединения.
- Максимальный размер хэш-таблицы для типов MIME.
- Выделяем память для отслеживания запросов (10МБ) и задаем ограничение: 10 запросов в секунду с одного IP.
- Аналогично для `health_limit` только 100 запросов в секунду.
```nginx.conf
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  

  log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                  '$status $body_bytes_sent "$http_referer" '
                  '"$http_user_agent" "$http_x_forwarded_for"';

  access_log /var/log/nginx/access.log main;
  
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;

  limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
  limit_req_zone $binary_remote_addr zone=health_limit:10m rate=100r/s;
  
  server {
    ...
    
    location /health {
    ...
    }

    location /api/ {
    ...
    }

    location / {
    ...
    }
  }
}
```

### Блок `server`
- Порт, на котором сервер принимает соединение
- Домен для настройки блока server
---
Обработка запросов на эндпоинте `/health`
- Применение ограничений из зоны `health_limit` + `burst=20` превысить лимит на 20 запросов.
- Проксирование запроса на бэк по адресу `rate-limiter:3000`.
- Передача бэкэнду информации о клиенте и запросе(IP, хост, протокол и т.д.)
---
Обработка запросов на API
- Применение ограничений из зоны `api_limit` + `burst=5` буфер на 5 запросов, `nodelay` запросы свыше лимита отклоняются.
- Ведётся отдельный лог для API-запросов.
- Остальные директивы аналогичны `/health`.
---
Обработка всех оставшихся запросов
- Ограничения из `api_limit` + `burst=10`
- Все проксируется на бэкэнд
```nginx.conf
server {
    listen 80;
    server_name localhost;

    location /health {
      limit_req zone=health_limit burst=20;
      proxy_pass http://rate-limiter:3000;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/ {
      limit_req zone=api_limit burst=5 nodelay;
      proxy_pass http://rate-limiter:3000;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      access_log /var/log/nginx/api_access.log main;
    }

    location / {
      limit_req zone=api_limit burst=10;
      proxy_pass http://rate-limiter:3000;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
```

Посмотрим Nginx логи
<img width="886" height="211" alt="image" src="https://github.com/user-attachments/assets/ff6e615d-2e05-4ed2-91e0-4140bbd5cffd" />

Перезагрузим конфиги Nginx без перезапуска контейнера
<img width="882" height="56" alt="image" src="https://github.com/user-attachments/assets/c866c6f7-1c6c-48c4-8aa4-b470598d180c" />

Проверим что конфиги Nginx в порядке
<img width="878" height="88" alt="image" src="https://github.com/user-attachments/assets/e022d04b-911a-4e91-9fb2-058641503fff" />

Проверим корректность подключения(ss не установлен в контейнере, поэтому использовал netstat)
<img width="887" height="125" alt="image" src="https://github.com/user-attachments/assets/7eeb1844-cb51-4f5a-a561-d0c153e3e9ad" />


## Lesson 2: Docker Containerization & Multi-Stage Builds
Разберём файлы `Dockerfile.app` и `Dockerfile.middleware` 

В `Dockerfile.app` мы используем miltistage сборку. Берётся контейнер с Golang в нем мы копирем основной код, файлы зависимостей + контрольные суммы зависимостей. После Go-код компилируется в один бинарный файл. После перем чистый образ Alpine скачиваем туда сертификаты, curl, postgres, копируем приложение из этапа builder, настраиваем порт и запускаем приложение.

В `Dockerfile.middleware` - сборка node.js, в котором просто копируем `middleware.js`, `package.json`, настраиваем порт и запускам node. В `middleware.js` описанно прокрисирование запросов от клиентов на основной сервер, ограничение запросов и логирование запросов: в файлы и в psql(время, метод, путь, статус, IP, User-Agent и т.д).

Проверим детали докер образа
<img width="791" height="834" alt="Снимок экрана 2026-04-15 152533" src="https://github.com/user-attachments/assets/7333d1ba-1c08-4694-8bfd-2407ed22b96d" />

Проверим слои образа

<img width="651" height="310" alt="Снимок экрана 2026-04-15 152603" src="https://github.com/user-attachments/assets/0abef530-5b86-4810-9b59-ee3ba0a4b82b" />

Посмотрим объём образов, которые начинаются на `practic`
<img width="647" height="84" alt="Снимок экрана 2026-04-15 152636" src="https://github.com/user-attachments/assets/52adcbb7-6ad9-49d3-b266-0a4e3003cf4a" />

Проверим файловую систему контейнера

<img width="645" height="154" alt="Снимок экрана 2026-04-15 152744" src="https://github.com/user-attachments/assets/9a892646-84be-490a-b80f-131ad39a3f91" />


## Lesson 3: Rate Limiting & Middleware Architecture
Протестируем ограничения частоты запросов. Скрипт просто стучится по эндпоинтам и проверяет, что ограничения работают.

<img width="564" height="364" alt="image" src="https://github.com/user-attachments/assets/c99b1595-e2c1-48fb-a40d-15000f669249" />

Проверим журнал работы ограничений
<img width="964" height="112" alt="image" src="https://github.com/user-attachments/assets/cebacced-0c56-4d83-bd27-03f9d38d5de6" />

Посмотрим логи запросов в real-time
<img width="882" height="360" alt="image" src="https://github.com/user-attachments/assets/6d09552d-e9c0-4fce-9288-7ac7b0e390db" />

Посмотрим, что в БД тоже записались запросы
<img width="1099" height="295" alt="image" src="https://github.com/user-attachments/assets/036217b1-7232-4163-bad6-2c5637de7dcb" />

Запись логов одновременно в файл и БД - это просто "метод комбинирования", если нам нужно смотреть в реальном времени состояние сервиса, то мы может использовать `docker-compose exec rate-limiter tail -f /app/logs/requests-*.log`, но если нам интересно конкретное кол-во запросов от пользователя X(или в нашем случае время запросов), то мы можем посмотреть в БД.
Кратко: Файл для real-time отслеживания состояния сервиса и его диагностики. БД - аналитика, отчётность и долгосрочное хранение.

## Lesson 4: Logging & Observability
Посмотрим журнал на основе файлов
<img width="835" height="77" alt="Снимок экрана 2026-04-16 111842" src="https://github.com/user-attachments/assets/159ed8ad-8c75-480b-996c-db4bfa682feb" />

Запрос журнала из БД с фильтрацией. Время, метод, адрес по которому приходил запрос, время ответа и ограничения
<img width="837" height="178" alt="Снимок экрана 2026-04-16 112119" src="https://github.com/user-attachments/assets/55ee5039-0475-4dbf-9097-6e5a00c0817c" />

Получаем статику. Сколько запросов было, с каким кодом, максимальное время ответа
<img width="833" height="242" alt="Снимок экрана 2026-04-16 112240" src="https://github.com/user-attachments/assets/cf1bd9d6-d3f7-44a6-866e-7044a7c7f3c4" />

## Lesson 5: Network Debugging & Security
Запустим скрипты для проверки сети

<img width="576" height="411" alt="image" src="https://github.com/user-attachments/assets/dc9c1990-b7b7-4590-90cb-e58a7006284f" />
<img width="836" height="535" alt="image" src="https://github.com/user-attachments/assets/33768fd4-3ddd-4648-8e79-4cf8aa13c25c" />

Видим, что все тесты прошли успешно с сервисами всё в порядке(все запущены)

# Network Debugging (tcpdump)
---
## Capture HTTP Traffic Between Nginx and Middleware
Запуск захвата пакетов в сети службы ограничения скорости для этого используем `docker-compose exec nginx tcpdump -i eth0 -A 'tcp port 3000'`

<img width="886" height="479" alt="image" src="https://github.com/user-attachments/assets/423c52ab-1007-4a60-8365-768ba7eb3849" />

И с другого терминала делаем запросы

<img width="588" height="311" alt="image" src="https://github.com/user-attachments/assets/fa5457d6-97da-46a6-9dab-3fb34e993a2e" />

Tcpdump выводит, что сначала у нас был запрос на синхронизацию (флаг [S]), потом подтверждение синхранизации (флаг [S.]), потом клиент подтвердил установку соединения (флаг [.]). Ну и в самом конце видим, что начали передаваться данные (флаг [P.]) можно увидеть код завершения "200 OK" + после передачи данных идет флаг [F.] завершение соединения.

## Analyze Specific Protocols
Остальные разделы готовятся...
