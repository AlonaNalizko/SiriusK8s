# LAB2

## block1
---

Создается Flask-приложение: app.py, requirements.txt и плохой Dockerfile.
<img width="1107" height="429" alt="изображение" src="https://github.com/user-attachments/assets/bd18e529-fb41-4464-927c-f317a26d6ee8" />
<img width="726" height="69" alt="изображение" src="https://github.com/user-attachments/assets/b9791d78-4f3a-4f45-8cf4-7db1c3a7aebc" />
<img width="715" height="168" alt="изображение" src="https://github.com/user-attachments/assets/fce84b5e-2b44-45cc-b069-4a23d06da989" />

Потом выполняется запуск. Сначала вылезала ошибка (на скрине), в итоге пофикселась добавлением --network=host
<img width="1231" height="667" alt="изображение" src="https://github.com/user-attachments/assets/065b8820-fb37-4370-93a5-baf207348a46" />

По итогу первого блока все запустилось, размер не получился в 1Gb, но все равно не мало
<img width="1236" height="289" alt="изображение" src="https://github.com/user-attachments/assets/564019c4-ab20-4be8-a5d6-7eb8195c090e" />

*Ответ на контрольный вопрос*: размер получился большим из-за того что используется базовый образ, который не нужен для простого Flask-приложения, также у нас кэш загруженных пакетов остается, а еще из-за содержимого Dockerfile у нас наслаиваются данные.

## block2
---

Здесь мы уже создаем хороший Dockerfile, который будет автоматизировать процесc, также Docker не будет заново скачивать все библиотеки (pip install), а возьмет их из готового кэша.
<img width="706" height="472" alt="изображение" src="https://github.com/user-attachments/assets/6973fab0-d4c1-4574-ba36-60f299ebb837" />

Также создается файл .dockerignore для более быстрой сборки
<img width="717" height="178" alt="изображение" src="https://github.com/user-attachments/assets/0c9b3e71-4b4f-4e65-83a4-e2b47bae09c4" />

Выполняется сборка
<img width="1230" height="661" alt="изображение" src="https://github.com/user-attachments/assets/3b612a61-ba5c-4ee9-8f38-57906df4955f" />

Для сравнения размеров выполняется команда docker images.
<img width="677" height="154" alt="изображение" src="https://github.com/user-attachments/assets/bc125ae8-58e4-45c0-92b1-0c86f2941090" />

Следом выполним запуск с ограничениями ресурсов
<img width="728" height="316" alt="изображение" src="https://github.com/user-attachments/assets/498ae825-e6f6-4289-a70f-cc275f7b299e" />

И выполняется анализ лимитов
<img width="1064" height="98" alt="изображение" src="https://github.com/user-attachments/assets/de23b64a-0345-4610-a81d-08ba76705fad" />

## block3
---

Выполняется просмотр слоев
<img width="1140" height="185" alt="изображение" src="https://github.com/user-attachments/assets/e8a5a8a1-567b-4afc-a0f5-4efc31e8ebec" />
<img width="1215" height="172" alt="изображение" src="https://github.com/user-attachments/assets/7d8f1c6d-cdc7-4663-a2b6-dec1be180c32" />

Для более детального просмтора выполняется команда на скрине, можно увидеть, что здесь 9 слоев, что ускоряет сборку, а также экономит место

<img width="817" height="401" alt="изображение" src="https://github.com/user-attachments/assets/4a142062-9871-43ea-8bde-26f606733f23" />

Затем устанавливаем dive для визуализации слоёв и просматриваем внутриности контейнера
<img width="1231" height="664" alt="изображение" src="https://github.com/user-attachments/assets/beb68cdd-acb1-41f3-99fe-2939a54d241e" />

## block4
---

Здесь просто публикуется в Docker Hub, URL: kamushkinael/flask-demo
<img width="1233" height="589" alt="изображение" src="https://github.com/user-attachments/assets/2cab7903-a711-4a55-869d-0002652f64be" />
<img width="915" height="561" alt="изображение" src="https://github.com/user-attachments/assets/1b3cb423-56d5-43ac-9f9e-06ed51370e49" />
