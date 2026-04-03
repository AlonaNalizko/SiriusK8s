# Пара 3 - Docker: сети, volumes, docker-compose

## Блок 1 - Docker networking
Запустим два контейнера в сети
<img width="910" height="480" alt="image" src="https://github.com/user-attachments/assets/96d781dd-b717-4eac-a74a-e879703863b7" />


Внутри alpine попробуем достучать до db по имени и у нас получится - это означает, что dns работает
<img width="747" height="307" alt="image" src="https://github.com/user-attachments/assets/b869553c-ec12-4ef9-bf76-aa0385d54334" />



А вот контейнер, который не в нашей среде такого не сможет
<img width="895" height="52" alt="image" src="https://github.com/user-attachments/assets/23450a7a-6b04-4af9-9b15-d6c5d967afc1" />



## Блок 2 - Volumes и persistent data
Запустим Postgres с volume и создадим тестовые данные
<img width="912" height="351" alt="image" src="https://github.com/user-attachments/assets/fad863dc-d3e5-4bb8-93f7-49a4b74b3a3e" />


Удалит контейнер и снова запустим. Данные будут на месте, потому-что данные хранятся в отдельном Volume, а не в самом контейнере
<img width="912" height="395" alt="image" src="https://github.com/user-attachments/assets/eabe5e99-1173-43b5-9d73-fdfe9edb8ddb" />


Проверим, где находится этот Volume
<img width="904" height="258" alt="image" src="https://github.com/user-attachments/assets/ba64f7e6-8d32-4222-a452-53fb4c48ff49" />



## Блок 3 - docker-compose
Создаем директории для проекта
```bash
mkdir ~/compose-lab && cd ~/compose-lab
mkdir -p backend frontend
```

После этого создается контейнеры для `backend` и `frontend`. И `docker-compose` для управления контейнерами. Поднимаем стек и появляется ошибка, что `backend is unhealthy`. Вылечить его мне не удалось он видимо умер оканчатель, потому-что менял и запуск `docker-compose` думал может не успевает БД подняться(и всё равно не работает), менял app.py(думал может `wget` нету на alpine и поэтому менял на `curl`), но всё равно не работает. Вот ошибка:
<img width="937" height="734" alt="image" src="https://github.com/user-attachments/assets/5e41c28b-2e6b-48af-bf02-067d98a72d62" />


Создание данных в БД
<img width="949" height="138" alt="image" src="https://github.com/user-attachments/assets/a57a2879-2c0f-46b1-bf24-f16564324763" />



После всех проделанных мохинаций вырубаем compose и идём спать `docker compose down`

## Блок 4 - Итог
Посмотрите все volumes
<img width="696" height="239" alt="image" src="https://github.com/user-attachments/assets/db347857-7c46-497a-9224-fd12bd7884c1" />


Очистите всё(включая volumes)
<img width="947" height="970" alt="image" src="https://github.com/user-attachments/assets/2ef5fa53-c212-426d-aa2f-db7b3b8991a2" />




