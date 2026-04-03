# LAB4

## block1
---

Для начала я подняла кластер k3s и начала работу с нодами

<img width="1166" height="572" alt="Снимок экрана от 2026-03-31 01-55-12" src="https://github.com/user-attachments/assets/a06f3afe-79ed-4d67-bc14-d5c6d7ee9f2f" />

Дальше полетела ошибка (пофиксила ее добавив sudo и указав путь к конфигу)

<img width="1263" height="526" alt="Снимок экрана от 2026-03-31 01-55-51" src="https://github.com/user-attachments/assets/8e5b4b55-ad04-4678-a24f-e3bf17e46d4a" />

<img width="1077" height="660" alt="Снимок экрана от 2026-03-31 02-00-52" src="https://github.com/user-attachments/assets/bedf21ce-cf33-4ad8-848f-7ce30f19a318" />

Затем надо было разобрать команды связанные с компонентами Control Plane
<img width="1080" height="504" alt="Снимок экрана от 2026-03-31 02-19-54" src="https://github.com/user-attachments/assets/7c68230d-0e76-44fc-adb0-abfedd2288d6" />

Последним в данном блоке рассматривались API ресурсы кластера, а также версия
<img width="1237" height="661" alt="Снимок экрана от 2026-03-31 02-21-57" src="https://github.com/user-attachments/assets/d3d54010-7b00-4452-9416-f77c37d7e66c" />

*Ответ на вопрос*: ну самое важные это Control Plane и сетевые компоненты, тк без них кластер либо вообще не будет работать, либо у него возникнут серьезные проблемы с сетью или доступом.

## block2
---

Запуск первого пода императивно (честно говоря, не слышала такого слова до этого, поэтому начала тупить че происходит)

<img width="1232" height="367" alt="Снимок экрана от 2026-03-31 02-34-49" src="https://github.com/user-attachments/assets/f8b5de9c-7711-4a01-8df9-837d46f521b7" />

Потом смотрим на его жизнь

<img width="493" height="127" alt="Снимок экрана от 2026-03-31 02-35-18" src="https://github.com/user-attachments/assets/b13aca43-560c-492d-b176-640f4ddbf2dc" />

Можно зайти во внутрь и посмотреть че творится (ну тут смотрим имя, айпишник, переменные окружения, и конкретные процессы)

<img width="713" height="662" alt="Снимок экрана от 2026-03-31 02-36-48" src="https://github.com/user-attachments/assets/3641010e-db10-4314-976e-4bd5084cabe1" />
<img width="990" height="290" alt="Снимок экрана от 2026-03-31 02-37-50" src="https://github.com/user-attachments/assets/cca213a3-a796-48bb-a175-80dc250cde82" />

Смотрим логи
<img width="1018" height="654" alt="Снимок экрана от 2026-03-31 02-38-24" src="https://github.com/user-attachments/assets/bedf70fb-c095-4abe-a34a-656d569984be" />

И выполняем диагностику пода командой
```
kubectl describe pod nginx
```

<img width="1227" height="651" alt="Снимок экрана от 2026-03-31 02-39-17" src="https://github.com/user-attachments/assets/cb38e28f-c002-497c-8e11-42685473c58b" />

## block3
---

Для создания пода через yml создается файл pod.yaml
<img width="1227" height="651" alt="Снимок экрана от 2026-03-31 02-41-32" src="https://github.com/user-attachments/assets/00934802-1227-4f85-8ac4-5be5a23de055" />

Применяем и смотрим на его работу

<img width="1224" height="383" alt="Снимок экрана от 2026-03-31 02-44-12" src="https://github.com/user-attachments/assets/bf4f041a-ab97-4884-aa4c-0331f7199fa6" />

Чекнем логи конкретного контейнера (спойлер: их нет), а также выполняем вход в конкретный контейнер

<img width="613" height="178" alt="Снимок экрана от 2026-03-31 02-45-44" src="https://github.com/user-attachments/assets/34a2a960-0125-46e9-8df8-e30c5e75c09b" />

Тут можно посмотреть , как кубер "видит" описание пода на самом деле (со всеми проставленными лимитами и статусами).
<img width="1226" height="623" alt="изображение" src="https://github.com/user-attachments/assets/c7710ac8-d210-41bd-a5c0-3a986a1ecdac" />

## block4
---

Честно, у меня команда не заработала сначала, я похимичила и теперь все сломалось....

<img width="706" height="345" alt="изображение" src="https://github.com/user-attachments/assets/f3a70331-1dab-425b-894b-0bfde6f4b105" />

---
Как итог могу сказать, что я эту лабу 3 раза переписывала, тк случайно удаляла, то что писала, не закоммитив
