# Практический курс: 5 уроков по SRE, Docker и отладке

Документация по выполнению практических заданий. Описываю ошибки и решения, с которыми столкнулся.

---
Фото с выполнением лежат в папке /images
---

## Что у нас в проекте

Стек: nginx -> node.js middleware -> go app -> postgres

Порты:
- 80/443: nginx
- 3000: middleware
- 8080: go приложение
- 5432: postgres

Файлы:
- docker-compose.yml — оркестрация
- Dockerfile.app, Dockerfile.middleware — сборка образов
- main.go, middleware.js — код приложений
- nginx.conf — конфиг прокси
- init-db.sql, break-db.sh — работа с БД
- вспомогательные скрипты для тестов

---

## Требования

У меня уже стояло:
- Docker 24.x
- Docker Compose v2
- curl, tcpdump, strace

Если нет — ставлю:
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y tcpdump strace jq apache2-utils
```

Проверяю:
```bash
docker --version
docker-compose --version
curl --version
```

---

## Урок 1: Запуск через docker-compose

### Первый запуск

Запускаю:
```bash
docker-compose up --build
```

Система начинает скачивать базовые образы: alpine, node, golang, postgres, nginx.

### Ошибка 1: checksum mismatch в go.sum

При сборке Go-приложения вылезает:
```
verifying github.com/lib/pq@v1.10.9/go.mod: checksum mismatch
```

Понял, что хеши в go.sum не совпадают с тем, что скачивается из сети.

Решение простое:
```bash
# На хосте, в папке проекта
rm go.sum
go mod tidy
```

После этого сборка пошла дальше.

### Ошибка 2: context deadline exceeded

Следующая проблема — таймаут при скачивании образа golang:
```
failed to pull image golang:1.22-alpine: context deadline exceeded
```

Это сетевая проблема. Решил так:

1. Проверил интернет:
```bash
ping registry.hub.docker.com
```

2. Предварительно скачал образы вручную:
```bash
docker pull golang:1.22-alpine
docker pull node:18-alpine
docker pull postgres:15-alpine
docker pull nginx:alpine
```

3. Повторил сборку:
```bash
docker-compose up --build
```

### Ошибка 3: версия Go

В Dockerfile.app была указана версия 1.21, но возникли проблемы с совместимостью зависимостей.

Просто поменял в начале Dockerfile.app:
```dockerfile
# Было
FROM golang:1.21-alpine AS builder

# Стало
FROM golang:1.22-alpine AS builder
```

### Проверка статуса

После всех правок:
```bash
docker-compose ps
```

Ожидаю:
```
NAME           STATUS
postgres       Up (healthy)
app            Up (healthy)
rate-limiter   Up (healthy)
nginx          Up (healthy)
```

Проверяю endpoints:
```bash
curl -v http://localhost/health
curl -v http://localhost/api/status
```

Если всё работает — вижу:
```json
{"status":"healthy","service":"health-check"}
{"status":"ok","users_count":3,"message":"Database connection successful"}
```

---

## Урок 2: Проблема с nginx

### Симптом

Контейнер nginx запускается, но:
- Статус: unhealthy
- Запросы на порт 80 возвращают 404
- При этом `curl localhost:3000/health` работает

Долго не мог понять, в чём дело.

### Диагностика

Зашёл в контейнер:
```bash
docker-compose exec nginx sh
```

Посмотрел, какие конфиги загружаются:
```bash
ls -la /etc/nginx/conf.d/
```

Увидел файл `default.conf`, который я не создавал.

### Причина

В образе nginx:alpine по умолчанию есть `/etc/nginx/conf.d/default.conf`. Он автоматически подгружается и конфликтует с моим кастомным `nginx.conf`. Из-за этого nginx не знает, куда проксировать запросы.

### Решение

Удалил конфликтующий файл:
```bash
rm /etc/nginx/conf.d/default.conf
nginx -s reload
exit
```

После этого запросы через порт 80 заработали.

### Правильное решение на будущее

Чтобы не удалять файл вручную каждый раз, добавил в `docker-compose.yml`:

```yaml
nginx:
  volumes:
    - ./nginx.conf:/etc/nginx/nginx.conf:ro
    - ./nginx-logs:/var/log/nginx
    - ./nginx-empty.conf:/etc/nginx/conf.d/default.conf:ro  # переопределяем стандартный конфиг
```

А сам файл `nginx-empty.conf` создал пустым:
```bash
touch nginx-empty.conf
```

### Ошибка с healthcheck

После фикса с default.conf nginx всё ещё показывал unhealthy.

Проверил, в чём дело:
```bash
docker-compose logs nginx
```

Оказалось, `wget` в Alpine странно работает с `localhost`.

Исправил в `docker-compose.yml`:
```yaml
# Было
test: ["CMD", "wget", "-q", "-O-", "http://localhost/health"]

# Стало
test: ["CMD", "wget", "-q", "-O-", "http://127.0.0.1/health"]
```

Или можно использовать curl:
```yaml
test: ["CMD", "curl", "-f", "http://localhost/health"]
```

После этого статус стал healthy.

---

## Урок 3: Rate limiting и middleware

### Как работает

Node.js middleware стоит между nginx и Go-приложением. Он:
- Ограничивает запросы по алгоритму token bucket (10 req/s, burst 20)
- Логирует запросы в файл и в PostgreSQL
- Проксирует запросы дальше

### Тестирование rate limiting

Запускаю:
```bash
bash test-rate-limiting.sh
```

Или вручную:
```bash
for i in {1..30}; do
    curl -s http://localhost/api/status -w "Request $i: %{http_code}\n" -o /dev/null
    sleep 0.05
done
```

Вижу:
- Первые ~10 запросов: 200
- Дальше: 429 (Too Many Requests)
- После паузы в 1+ секунду: снова 200

Это работает token bucket: токены тратятся на запросы и восполняются со временем.

### Просмотр логов

Файловые логи:
```bash
docker-compose exec rate-limiter cat /app/logs/requests-*.log | jq .
```

Логи в БД:
```bash
docker-compose exec postgres psql -U demo -d demo
```

Внутри psql:
```sql
-- Последние запросы
SELECT timestamp, method, path, status_code, response_time_ms, rate_limited
FROM request_logs
ORDER BY timestamp DESC LIMIT 10;

-- Заблокированные запросы
SELECT COUNT(*) FROM request_logs WHERE rate_limited = true;

-- Статистика по статусам
SELECT status_code, COUNT(*) as count, AVG(response_time_ms) as avg_ms
FROM request_logs
GROUP BY status_code
ORDER BY count DESC;
```

Выход из psql: `\q`

Важный момент с определением IP

В middleware есть функция `getRateLimitKey()`, которая берёт IP клиента.

Без правильной настройки nginx все запросы будут приходить с одного IP (контейнера nginx), и rate limiting не будет работать как задумано.

Поэтому в `nginx.conf` важно передать заголовки:
```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

А в `middleware.js` читать их:
```javascript
function getRateLimitKey(req) {
    return req.headers['x-real-ip'] || 
           (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || 
           req.socket.remoteAddress || '127.0.0.1';
}
```

---

## Урок 4: Сетевая отладка с tcpdump

### Базовый захват

В одном терминале:
```bash
docker-compose exec nginx tcpdump -i eth0 -A 'tcp port 3000'
```

В другом:
```bash
curl -v http://localhost/api/status
```

В выводе tcpdump вижу:
- TCP handshake (SYN, ACK)
- HTTP GET запрос с заголовками
- Ответ с кодом 200 и телом
- Закрытие соединения (FIN)

### Фильтры

```bash
# DNS
docker-compose exec nginx tcpdump -i eth0 -A 'udp port 53'

# PostgreSQL
docker-compose exec postgres tcpdump -i eth0 -A 'tcp port 5432'

# Только к middleware
docker-compose exec nginx tcpdump -i eth0 'dst port 3000'

# Только новые соединения
docker-compose exec nginx tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'
```
---

## Урок 5: Безопасность и strace

### Security scanner

Запускаю скрипт:
```bash
chmod +x check-docker-security.sh
./check-docker-security.sh app
```

Вижу предупреждения:
```
[CRITICAL] Container running as root
[WARNING] No capabilities explicitly dropped
[WARNING] No read-only filesystem
```

### Как исправить

В Dockerfile добавляю запуск от непривилегированного пользователя:
```dockerfile
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -D appuser
USER appuser
```

В docker-compose.yml добавляю ограничения:
```yaml
app:
  cap_drop:
    - ALL
  read_only: true
  tmpfs:
    - /tmp
  security_opt:
    - no-new-privileges:true
  deploy:
    resources:
      limits:
        memory: 512M
        cpus: '1.0'
```

### strace: трассировка системных вызовов

Сначала нахожу PID процесса:
```bash
docker-compose exec app pgrep app
```

Затем запускаю strace:
```bash
docker-compose exec app strace -p <PID>
```

В другом терминале делаю запрос:
```bash
curl http://localhost/api/status
```

В выводе strace вижу:
```
socket(...) = 3
connect(3, {...}, ...) = 0  # подключение к БД
write(3, "SELECT COUNT(*)...", ...)
read(3, "...", ...)
write(1, "{\"status\":\"ok\"...", ...)  # ответ клиенту
```


### Работа с PostgreSQL

```bash
# Интерактивная сессия
docker-compose exec postgres psql -U demo -d demo

# Команды внутри:
\dt                    # список таблиц
\d users               # структура таблицы
SELECT * FROM users;   # данные
\q                     # выход

# Бэкап
docker-compose exec postgres pg_dump -U demo demo > backup.sql

# Восстановление
cat backup.sql | docker-compose exec -T postgres psql -U demo demo
```

### Load testing
wrk:
```bash
git clone https://github.com/wg/wrk.git
cd wrk && make
./wrk -t4 -c100 -d30s http://localhost/api/status
```

---

## Сценарии сбоев и восстановление

### Сломать БД

Запускаю:
```bash
docker-compose exec postgres bash < break-db.sh
```

Скрипт удаляет таблицу users.

Проверяю:
```bash
curl http://localhost/api/status
```

Получаю:
```json
{"status":"error","message":"database error: relation \"users\" does not exist"}
```

В логах приложения вижу попытки переподключения к БД.

### Восстановить

Перезапускаю БД:
```bash
docker-compose restart postgres
```

Или полностью пересоздаю окружение:
```bash
docker-compose down -v
docker-compose up --build
```

init-db.sql выполнится заново и создаст таблицу.

### Остановить приложение

```bash
docker-compose stop app
curl http://localhost/api/status
```

Получаю 502 Bad Gateway — middleware не может достучаться до upstream.

Здоровье проверяю отдельно:
```bash
curl http://localhost/health  # работает, т.к. это в middleware
```

Возвращаю приложение:
```bash
docker-compose start app
```

---

## Итоги того, что я сделал

Урок 1:
- [ ] Исправил go.sum через `go mod tidy`
- [ ] Поменял версию Go на 1.22
- [ ] Предварительно скачал образы при сетевых проблемах
- [ ] Добился, чтобы все 4 сервиса были в healthy
- [ ] Получил ответы от /health и /api/status

Урок 2:
- [ ] Нашел и удалил /etc/nginx/conf.d/default.conf
- [ ] Исправил healthcheck (localhost -> 127.0.0.1)
- [ ] Настроил переопределение default.conf через volume
- [ ] Научился перезагружать nginx без restart

Урок 3:
- [ ] Протестировал rate limiting, увидел 429
- [ ] Изучил token bucket в middleware.js
- [ ] Посмотрел логи в файлах и в БД
- [ ] Убедился, что X-Real-IP передаётся из nginx

Урок 4:
- [ ] Захватил трафик через tcpdump
- [ ] Увидел TCP handshake и HTTP в пакетах
- [ ] Попробовал разные фильтры tcpdump
- [ ] Использовал опции curl

Урок 5:
- [ ] Запустил security scanner
- [ ] Добавил non-root пользователя в Dockerfile
- [ ] Настроил cap_drop и read-only filesystem
- [ ] Попробовал strace на работающем приложении
- [ ] Сделал бэкап и восстановил БД
- [ ] Провёл load test через ab

---

## Что я себе выписал для запоминания на будущее

1. Всегда проверяй, какие конфиги реально загружаются в контейнере (особенно в nginx).
2. Healthcheck в Alpine может вести себя неочевидно — лучше тестировать на 127.0.0.1 или использовать curl.
3. go.sum нужно генерировать на той же системе, где собираешь, или пересоздавать при проблемах.
4. При работе за прокси важно передавать X-Real-IP, иначе rate limiting по IP не сработает.
5. strace — хороший инструмент, но вывод может быть большим, поэтому лучще использовать фильтры (-e trace=...).
6. Security scanner помогает найти очевидные проблемы, но финальные правки всё равно вручную.

---

Выполнял Товпеко Глеб Вадимович @glebffff
