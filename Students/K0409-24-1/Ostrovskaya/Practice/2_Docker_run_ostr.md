2_laba
Структура: # 1. Выводы # 2. Вопросы # 3. Трудности

# 1. Выводы в терминале
1. Статистика контейнера (docker stats)
CONTAINER ID   NAME         CPU %     MEM USAGE / LIMIT   MEM %     NET I/O     BLOCK I/O   PIDS
211927d883b9   app-good     0.00%     0B / 0B             0.00%     0B / 0B     0B / 0B     0
2. Сравнение образов (docker images)
sofa@FILOSOF:~/docker-lab$ docker images myapp
IMAGE          ID            DISK USAGE    CONTENT SIZE
myapp:bad      ce7fcf175f56    1.62GB        416MB
myapp:good     c91341e70998    81.4MB        19.6MB
3. Слои образа (docker history)
sofa@FILOSOF:~/docker-lab$ docker history myapp:good
IMAGE          CREATED            CREATED BY                                      SIZE
e045d0748769   39 hours ago       CMD ["python" "app.py"]                         0B
<missing>      39 hours ago       RUN /bin/sh -c pip install --no-cache-dir...    15.1MB
<missing>      3 weeks ago        RUN /bin/sh -c apk add --no-cache...            44.1MB
<missing>      8 weeks ago        ADD alpine-minirootfs...                        9.11MB
...

# 2. Вопросы
1. Почему образ myapp:bad такой большой (1.62GB)?
Использован полный образ python:3.12 (на базе Debian), пакеты установлены с кэшем pip, скопированы все файлы контекста без .dockerignore.
2. Почему myapp:good такой маленький (81.4MB)?
Использован Multistage build: сборка в одном образе, запуск в другом. Базовый образ — легковесный Alpine Linux. Кэш pip очищен, лишние файлы исключены.
3. Что показывают слои (docker history)?
Каждая инструкция Dockerfile создает новый слой. Слои кэшируются при сборке. Видно, какие команды занимают место (например, установка пакетов — 15.1MB).


# 3. Трудности
- Имя файла: Docker не видел Dockerfile.py. Переименовала в Dockerfile.
- Права доступа: Ошибка ModuleNotFoundError. Пакеты ставились с --user в /root/.local, а запускались от appuser. Убрала флаг --user, установила пакеты системно.
- Сеть: Таймаут при скачивании с PyPI. Проблема решилась повторным запуском сборки.

Скину доработки 31.03.2026