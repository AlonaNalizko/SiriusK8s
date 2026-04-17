# Цель работы

Изучить основные принципы SRE (Site Reliability Engineering) на практике: rate limiting, контейнеризацию, логирование и отказоустойчивость.

# Ход выполнения

## Часть 1. Проверка окружения и запуск стека

### Шаг 1. Проверил статус контейнеров после запуска.

![alt text](<screens/Вставленное изображение.png>)

sudo docker ps показывает 4 контейнера:

    practic-postgres-1 — healthy

    practic-app-1 — healthy

    practic-rate-limiter-1 — unhealthy (но работает)

    practic-nginx-1 — unhealthy (но работает)

### Шаг 2. Проверил логи запуска всех сервисов.

![alt text](<screens/Вставленное изображение (3).png>)

Логи postgres, app, rate-limiter, nginx при старте. Видно, как postgres инициализируется, app стартует на порту 8080, rate-limiter слушает 3000, nginx готов к работе.

### Шаг 3. Проверил работу эндпоинтов.

![alt text](<screens/Вставленное изображение (2).png>)

    curl http://localhost/health → {"status":"middleware healthy"}

    curl http://localhost/api/status → {"message":"API working","user_count":3,"timestamp":"..."}

## Часть 2. Nginx (Lesson 1)

### Шаг 4. Изучил конфигурацию nginx.

![alt text](<screens/Вставленное изображение (5).png>)

Содержимое nginx.conf. Видны:

    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s

    limit_req_zone $binary_remote_addr zone=health_limit:10m rate=100r/s

    Проксирование на rate-limiter:3000

### Шаг 5. Проверил синтаксис конфигурации.

![alt text](<screens/Вставленное изображение (11).png>)

    sudo docker compose exec nginx nginx -t → syntax is ok, test is successful

### Шаг 6. Посмотрел логи nginx.

![alt text](<screens/Вставленное изображение (6).png>)

Логи nginx при запуске.

### Шаг 7. Проверил версию nginx и app.

![alt text](<screens/Вставленное изображение (4).png>)

    sudo docker exec practic-nginx-1 nginx -v → nginx version: nginx/1.29.8

    sudo docker exec practic-app-1 ./app -h → ошибка bind: address already in use (потому что app уже запущен)

## Часть 3. Docker контейнеризация (Lesson 2)

### Шаг 8. Изучил размеры образов.

![alt text](<screens/Вставленное изображение (7).png>) 

sudo docker images | grep practic 

    practic-app: 41.8MB (virtual), 13.2MB (actual)

    practic-rate-limiter: 184MB (virtual), 45.4MB (actual)

### Шаг 9. Посмотрел слои образа app.

![alt text](<screens/Вставленное изображение (12).png>)

sudo docker history practic-app --no-trunc | head -10 — видна многоступенчатая сборка: builder из golang:1.21-alpine, затем alpine:latest с скопированным бинарником.

### Шаг 10. Проверил файловую систему контейнера.

![alt text](<screens/Вставленное изображение (14).png>)

sudo docker compose exec app ls -lah /app → бинарник app размером 7.4M.

### Шаг 11. Проверил healthcheck контейнера.

![alt text](<screens/Вставленное изображение (8).png>)

sudo docker inspect practic-app-1 | grep -A 5 "Health" → "Status": "healthy", проверка через curl http://localhost:8080/health.

## Часть 4. Rate Limiting (Lesson 3)

### Шаг 12. Выполнил тест rate limiting — 35 быстрых запросов.

![alt text](<screens/Вставленное изображение (16).png>)

Результат:
    Запросы 1-28: 200 OK

    Запрос 29: 429

    Запрос 30: 200

    Запросы 31-32: 429

Это доказывает работу token bucket алгоритма (burst 20, восстановление 10 req/s).

### Шаг 13. Посмотрел логи rate-limiter в реальном времени.

![alt text](<screens/Вставленное изображение (15).png>)

sudo docker logs -f practic-rate-limiter-1 показывает каждый запрос с временной меткой:

Всего в логах 71 запрос.

### Шаг 14. Per-IP rate limiting тест.

![alt text](<screens/Вставленное изображение (17).png>)

Сначала исчерпал лимит для 192.168.1.100, затем протестировал три IP:

    192.168.1.100: 429

    192.168.1.101: 429

    192.168.1.102: 429

### Шаг 15. Тест с разными IP (X-Real-IP header).

![alt text](<screens/Вставленное изображение (10).png>)

for ip in 192.168.1.1 192.168.1.2 192.168.1.3 → все три получили 200 (лимит не был исчерпан).

![alt text](<screens/Вставленное изображение (25).png>)

Финальная часть теста rate-limiting:

    Request from 192.168.1.1: HTTP 200

    Request from 192.168.1.2: HTTP 429

    Request from 192.168.1.3: HTTP 429

    Recovery test: все 10 запросов успешны (200)

    Concurrent requests: все 5 успешны

## Часть 5. Логирование (Lesson 4)

### Шаг 16. Запросил логи из PostgreSQL.

![alt text](<screens/Вставленное изображение (18).png>)

sudo docker exec practic-postgres-1 psql -U postgres -d demo -c "SELECT timestamp, method, path, status_code, rate_limited FROM request_logs ORDER BY timestamp DESC LIMIT 10;"

В таблице видно:
    записи с status_code=200 и rate_limited=f

    записи с status_code=429 и rate_limited=t

## Часть 6. Сценарии отказа (Intentional Failures)

### Шаг 17. Поломка базы данных.

![alt text](<screens/Вставленное изображение (21).png>)

    DROP TABLE users CASCADE; → таблица удалена

    curl http://localhost/api/status → {"error":"database error: pq: relation 'users' does not exist"}

### Шаг 18. Восстановление базы данных.

![alt text](<screens/Вставленное изображение (22).png>)

    psql -f init.sql → таблица создана, данные вставлены

    curl http://localhost/api/status → {"message":"API working","user_count":3,"..."}

### Шаг 19. Остановка сервиса app (502 Bad Gateway).

![alt text](<screens/Вставленное изображение (23).png>)

    sudo docker stop practic-app-1

    curl http://localhost/api/status → {"error":"Bad gateway"} HTTP: 502

## Часть 7. Безопасность и отладка (Lesson 5)

### Шаг 20. Security scanner.

![alt text](<screens/Вставленное изображение (19).png>)

./check-docker-security.sh practic-app-1

    [CRITICAL] Container running as root (User: '')

### Шаг 21. strace — трассировка системных вызовов.

![alt text](<screens/Вставленное изображение (20).png>)

docker compose exec app strace -c ./app → вывод показывает:

    rt_sigaction (114 вызовов)

    mmap (20 вызовов)

    socket (5 вызовов)

    bind (3 вызова, 1 ошибка)

    и другие системные вызовы

## Часть 8. Итоговые тесты

### Шаг 22. Запуск test-api.sh и test-rate-limiting.sh.

![alt text](<screens/Вставленное изображение (24).png>)
Тест начал выполняться.

### Шаг 23. Результаты тестов

![alt text](<screens/Вставленное изображение (25).png>)
Результаты теста:

    Recovery test: все 10 запросов успешны

    Concurrent requests: все 5 успешны

    Per-Client Rate Limiting: разные коды для разных IP

    Throughput: 100 req/s

# Выводы

В ходе лабораторной работы я:

    Настроил и запустил multi-container приложение (nginx + rate-limiter + go app + postgres).

    Изучил конфигурацию nginx как reverse proxy с rate limiting.

    Понял принцип работы token bucket алгоритма (burst 20, refill 10 req/s).

    Протестировал rate limiting — увидел коды 200 и 429.

    Проверил per-IP rate limiting через заголовок X-Real-IP.

    Изучил dual logging (файлы + PostgreSQL).

    Провел сценарии отказа:

        падение БД → ошибка 500

        остановка app → ошибка 502

        восстановление после паузы → 200 OK

    Проанализировал безопасность контейнеров — обнаружена проблема с запуском от root.

    Использовал strace для анализа системных вызовов приложения.

# Ошибки
## Ошибка сборки Go приложения — checksum mismatch

Проблема: При сборке образа app возникла ошибка verifying github.com/lib/pq@v1.10.9: checksum mismatch. Контрольная сумма скачанного пакета не совпадала с записанной в go.sum.

Как исправил: Удалил старый go.sum и создал новый с правильной контрольной суммой. Также проверил, что в go.mod указана правильная версия зависимости. После этого пересобрал образ командой docker compose build --no-cache app.

## Ошибк: "os" imported and not used

Проблема: При сборке Go приложения компилятор выдал ошибку ./main.go:8:2: "os" imported and not used. В коде был импортирован пакет "os", который нигде не использовался.

Как исправил: Открыл файл main.go в редакторе nano и удалил строку "os" из блока импорта. После этого сборка прошла успешно.

## Ошибка: Логи rate-limiter не показывали запросы

Проблема: При выполнении sudo docker logs -f practic-rate-limiter-1 в логах были только сообщения о запуске, но не было записей о входящих HTTP запросах.

Как исправил: В middleware.js не было вывода в консоль. Добавил строку console.log([${new Date().toISOString()}] ${req.method} ${req.url}); сразу после создания сервера. После пересборки контейнера логи стали показывать каждый запрос с временной меткой.
