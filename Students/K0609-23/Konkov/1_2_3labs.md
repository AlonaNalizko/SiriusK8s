# 1 Лабораторная:
1.
Для начала были просмотрены namespace-ы текущего процесса. После выполнения команды был получен список неймспейсов, связанных с текущим процессом. Каждый из них отвечает за какойто аспект изоляции (PID, сеть, файловая система и т.д.). ТУт понимаем, что в линуксе процессы могут работать в разных пространствах. Также команда: "lsns" - показала список всех неймспейсов в системе. Видно, что у разных процессов свои неймспейсы, то есть они уже изолированы друг от друга.
<img width="1103" height="1009" alt="image" src="https://github.com/user-attachments/assets/b799d9ac-0d41-4ebc-b2cd-056d4bbe685c" />

Запустил bash в новом PID namespace: "sudo unshare --pid --fork --mount-proc /bin/bash"
Проверил PID: "echo $$". Показало 1, то есть внутри этого окружения мой процесс стал главным.
Дальше: "ps aux". Вывод показал только несколько процессо. Остальных процессов системы нет — значит изоляция работает.
После проверка сети: "sudo unshare --net /bin/bash, ip link show". Отобразился только интерфейс lo (loopback). Обычных интерфейсов типа eth0 нет - это значит, что сеть полностью изолирована

<img width="884" height="521" alt="image" src="https://github.com/user-attachments/assets/c69c92e9-f888-4e4e-9773-eda7df96779a" />

Контрольный вопрос: Почему после exit процессы хоста остались нетронутыми?

Процессы хоста не затронулись, потому что я работал в отдельном PID namespace. Внутри него все процессы изолированы и имеют свою нумерацию (bash был PID 1). После exit завершились только процессы внутри этого namespace, а процессы хоста остались работать, так как находятся в другом пространстве имён.




2.
Создал свою cgroup: "sudo mkdir /sys/fs/cgroup/mytest, echo "20000 100000" | sudo tee /sys/fs/cgroup/mytest/cpu.max" - это ограничивает CPU примерно до 20%.
Запустил нагрузку: "stress-ng --cpu 1 --timeout 30s &".
Добавил процесс в группу: "echo $! | sudo tee /sys/fs/cgroup/mytest/cgroup.procs"
Проверил: "cat /sys/fs/cgroup/mytest/cpu.max". Показало 20000 100000, то есть лимит применился.
Также: "cat /sys/fs/cgroup/mytest/cpu.stat". Там видно, что процесс тротлит.
<img width="900" height="472" alt="image" src="https://github.com/user-attachments/assets/b914175a-a243-42d2-8248-12f4d142f556" />
<img width="682" height="196" alt="image" src="https://github.com/user-attachments/assets/eea8f864-4433-44b9-8db7-5c2236245c64" />
<img width="1145" height="977" alt="image" src="https://github.com/user-attachments/assets/69cd8fb9-d0ba-4e51-abc7-9c03874e34d9" />

Контрольный вопрос: Что произойдёт если лимит памяти превысить? (OOM-killer)

Если процесс превысит лимит памяти, сработает OOM-killer. Он выберет и завершит один из процессов (обычно тот, кто потребляет больше всего памяти), чтобы освободить ресурсы.



Создал минимальную файловую систему: "mkdir -p /tmp/myroot/{bin,lib,lib64,proc,dev}, cp /bin/bash /tmp/myroot/bin/, cp /bin/ls /tmp/myroot/bin/"
Скопировал зависимости и зашёл: "sudo chroot /tmp/myroot /bin/bash"
Внутри проверил: "ls /".
Видны только те папки, которые я сам создал. /home, /etc и т.д. - их нет.
<img width="1197" height="963" alt="image" src="https://github.com/user-attachments/assets/114ea78e-2b8d-4eb4-baff-08396bae4e92" />
<img width="1162" height="312" alt="image" src="https://github.com/user-attachments/assets/ab41ab18-580f-43c3-8694-a45c35f01dc7" />


# 2 Лабораторная:

https://hub.docker.com/r/konkovvv/flask-demo

1. Первый Dockerfile
Создал простое приложение и Dockerfile, потом собрал образ: "docker build -t myapp:bad ."
Он получился очень большим (около 1 ГБ), потому что использовался полный образ Python и копировалось всё подряд.
Запустил: "docker run -d -p 5000:5000 --name app-bad myapp:bad, curl localhost:5000". Приложение работает.
<img width="1280" height="631" alt="image" src="https://github.com/user-attachments/assets/69477c00-71a0-4d9a-a203-d8da0f6f5cf1" />

2. Улучшение образа
Сделал более правильный Dockerfile: использовал python:3.12-slim, добавил .dockerignore, убрал лишние файлы.
Собрал: "docker build -t myapp:good .". Размер стал намного меньше.
<img width="862" height="198" alt="image" src="https://github.com/user-attachments/assets/3bff05fd-e372-42d6-9799-a04972877b78" />

3. Ограничение ресурсов
Запустил контейнер с лимитами: "docker run -d -p 5001:5000 --name app-good --memory="128m" --cpus="0.5" myapp:good".
Проверил: "docker stats app-good". Видно, что контейнер не превышает заданные лимиты.
<img width="963" height="140" alt="image" src="https://github.com/user-attachments/assets/30418644-77c4-47cb-8b1a-458c311d48a9" />

4. СЛои
Посмотрел структуру образа: "docker history myapp:good"
Видно, из каких слоёв он состоит (база, зависимости, приложение).
<img width="1175" height="492" alt="image" src="https://github.com/user-attachments/assets/a14e5e8e-716f-43ba-8064-c63a72a0c07e" />
<img width="1175" height="492" alt="image" src="https://github.com/user-attachments/assets/4beae478-af78-41f7-8c3d-e0ba31a1a1d7" />

5. Публикация
Загрузил образ в Docker Hub: "docker tag myapp:good <username>/flask-demo:v1.0, docker push <username>/flask-demo:v1.0"


Контрольный вопрос: Почему образ такой большой?

Образ получился большим, потому что используется базовый образ python:3.12, который сам по себе тяжёлый, и в него копируется весь проект целиком. Также при pip install остаётся кэш и лишние файлы, что дополнительно увеличивает размер. 


# 3 Лабораторная:

1. Сеть
Создал сеть: "docker network create app-network". Запустил контейнеры и проверил связь: "ping db" - контейнеры видят друг друга по имени.
<img width="863" height="889" alt="image" src="https://github.com/user-attachments/assets/2ac4e25a-c6e7-42ce-a26a-51ef60dc1693" />

2. Volume
Создал volume и запустил PostgreSQL: "docker volume create pgdata". Создал таблицу, потом удалил контейнер и запустил заново.
Данные сохранились — значит volume работает.
<img width="1039" height="353" alt="image" src="https://github.com/user-attachments/assets/195ce11b-68da-406f-8991-44e6e301a10c" />

3. Docker Compose
Создал docker-compose.yml с тремя сервисами: db(postgre), backend (flask), frontend (nginx).
Запустил: "docker compose up -d --build".
Проверил: "docker compose ps". Все сервисы работают.
<img width="1280" height="126" alt="image" src="https://github.com/user-attachments/assets/7946669a-a89e-4505-aeb3-0d3996af6e46" />

4. Проверка работы
Создал данные: "docker compose exec db ...".
Проверил API: "curl localhost:8080/api/items". Ответ пришёл — значит связка frontend -> backend -> db работает.

5. Масштабирование
Увеличил количество backend: "docker compose up -d --scale backend=3".
Проверил: "docker compose ps". Появилось 3 контейнера backend.
<img width="1280" height="166" alt="image" src="https://github.com/user-attachments/assets/766f4ef1-bab2-44e2-8c7c-d889b4a5df0a" />

Проблем с лабой вроде не было, я уже забыл на момент коммита отчёта.
