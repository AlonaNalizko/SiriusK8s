# <b><span style="color: #5f2e2e;">СДЕЛАЛ? + К.В.</span></b>
<b>ДА, сделал. всё айс.</b>

<span style="color: #5c5c5c;">Контрольных вопросов не было, так что заставил ИИ придумать вопросы)</span> <br>

* <b><span style="color: #a56767;">Блок 1</span> — Почему контейнер, запущенный в дефолтной сети bridge, не может обратиться к контейнеру db по имени, хотя оба контейнера находятся на одной машине?</b> <br>
В дефолтной сети bridge нет встроенного ДНС и контейнеры видят друг друга только по айпи. В пользовательских сетях `Docker` автоматически настраивает DNS-резолвинг по именам контейнеров.

* <b><span style="color: #a56767;">Блок 2</span> — Какая опция в команде docker run или в docker-compose.yml отвечает за то, чтобы данные БД не удалялись при пересоздании контейнера?</b> <br>
`-v` (или volumes: в compose). В таком случае данные сохранятся отдельно от контейнера и будут удалены тока если юзанешь команду `docker volume rm`.

* <b><span style="color: #a56767;">Блок 3</span> — Для чего в файле docker-compose.yml используется секция depends_on и чем её дополняет condition: service_healthy?</b> <br>
depends_on указывает порядок запуска. `Docker` сначала запустит зависимые сервисы и не будет ждать, когда они ряльно будут доступны для подключения. Пример - backend может запуститься раньше, чем db поднимет PostgreSQL и начнет принимать запросы. condition: service_healthy решает эту проблему. `Docker` ждёт пока пройдёт healthcheck и только тогда запустит сервис.

* <b><span style="color: #a56767;">Блок 4</span> — Что произойдет с данными в volume после выполнения docker compose down -v?</b> <br>
Данные полностью удалятся. Флаг `-v` удаляет все volume. Без этого флага volume остаются на диске, и при следующем `docker compose up -d` данные будут тип.


# <b><span style="color: #5f2e2e;">ПРОБЛЕМЫ</span></b>
Была проблема с healthcheck бекэнда. Короче беда в том, что в heathcheck использовался wget для проверки, а в образе его изначально нет. Надо просто в dockerfile после `FROM python:3.12-alpine` добавить `RUN apk add --no-cache wget`. <br>
![SCRA](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-27-30.png) <br>

скрррррр проблемы:<br>
![SCRERR](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-29-16.png)

# <b><span style="color: #5f2e2e;">SCREENШОТЫ</span></b>
![SCR1](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-04-05.png) <br>
![SCR2](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-04-29.png) <br>
![SCR3](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-06-56.png) <br>
![SCR4](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-07-12.png) <br>
![SCR5](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-29-07.png) <br>
![SCR6](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-30-03.png) <br>
![SCR7](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-32-43.png) <br>
![SCR8](https://github.com/noktirr/SCREENSHOTS/blob/main/3_Docker_net_vol/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2018-33-13.png) <br>