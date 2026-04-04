# LAB3

## block1
---

Первым шагом смотрим сети, там две команды юзаем
<img width="860" height="646" alt="изображение" src="https://github.com/user-attachments/assets/df4aaaca-1000-4589-8f11-c6e192b23969" />

Далее создается изолированная сеть и в ней запускаем два контейнера.
*Проблема*: если правильно поняла, была как у многих проблема с запуском из-за файла /etc/docker/daemon.json. Я его пыталась и сама поправить, и через гпт, в итоге поправила как в группе тг.

<img width="830" height="337" alt="изображение" src="https://github.com/user-attachments/assets/374c66a9-6507-4cfc-a3fa-37c5f9b40e87" />

Также выполнялась проверка пинга и порта.

<img width="590" height="320" alt="изображение" src="https://github.com/user-attachments/assets/7abd0be9-2ceb-4907-bd67-037f1a9633ec" />

Также выполнила сравнение и он его не нашел.

<img width="584" height="149" alt="изображение" src="https://github.com/user-attachments/assets/c0bc070b-1713-4a7b-bb71-2c18fdef5c9e" />

## block2
---
Дальше запускаем Postgres с volume, также тестовые данные создаются.
<img width="874" height="499" alt="изображение" src="https://github.com/user-attachments/assets/0afa2713-2437-4be9-ad3b-9721dab1b7e3" />

Для теста удаляем контейнер, потом заново его запускаем и проверяем живы ли данные (спойлер: живы)
<img width="868" height="465" alt="изображение" src="https://github.com/user-attachments/assets/64b8916b-c4d0-47c7-899c-faecae42f4fb" />

В конце смотрем где физически находится volume
<img width="644" height="307" alt="изображение" src="https://github.com/user-attachments/assets/ee87fe7e-2499-47f6-b2e6-ed6600526d20" />

## block3
---
В этом блоке перед работой создается структура проекта с помощью утилиты mkdir
Также создаем необходимые файлы:
<img width="775" height="665" alt="изображение" src="https://github.com/user-attachments/assets/2f04375b-04d3-4d34-8437-f69bcd6620cf" />
<img width="761" height="135" alt="изображение" src="https://github.com/user-attachments/assets/b6c5be2a-86bf-4219-9594-35cf3194bd29" />
<img width="724" height="196" alt="изображение" src="https://github.com/user-attachments/assets/696f8fb1-d7d0-472b-a708-ccdffdfa6c71" />
<img width="915" height="298" alt="изображение" src="https://github.com/user-attachments/assets/433c237e-965a-40bb-896a-24eaca720b73" />
<img width="749" height="656" alt="изображение" src="https://github.com/user-attachments/assets/69a8c1f4-2a94-45ab-85f0-a60d6fbfaed8" />

Дальше я начала запускать и пришлось поправлять.
*Проблемки*: первая проблема была с тем, что он писал no such file of directory, пофиксила добавив в yml строчку dockerfile: Dockerfile (если правильно поняла, он почему-то не находил его). Вторая проблемка, это из-за первого блока я забыла поменять файл /etc/docker/daemon.json, из-за чего там тупо не было инета. Добавила строку:
```
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
```

короче во запустила
<img width="1235" height="678" alt="изображение" src="https://github.com/user-attachments/assets/faa5dd00-bdec-438a-9487-8fed70620a5f" />

Также надо посмотреть его состояние
<img width="1235" height="674" alt="изображение" src="https://github.com/user-attachments/assets/b008b595-52e4-4b04-967b-f9263f2710b9" />

Создала данные в базке
<img width="1228" height="189" alt="изображение" src="https://github.com/user-attachments/assets/2601facc-0932-455f-a309-94d28524990e" />

Для проверки цепочки пришлось вокруг ноутбука делать танцы с бубном, тк были траблы с nginx, но все робит
<img width="1251" height="134" alt="изображение" src="https://github.com/user-attachments/assets/6b653257-9850-4aab-9ce4-c48136b3cdbe" />

Далее масштабировали back
<img width="1225" height="595" alt="Снимок экрана от 2026-03-31 00-13-43" src="https://github.com/user-attachments/assets/3ca9c828-2cee-4d3a-8c4b-b479f2134b3d" />

Остановка
<img width="1242" height="233" alt="изображение" src="https://github.com/user-attachments/assets/08444627-10d6-41a8-b878-5888d7d4547f" />

## block4

Смотрим volumes и выполняю очистку
<img width="1249" height="666" alt="изображение" src="https://github.com/user-attachments/assets/799381f6-f979-4721-a5fe-f87511cca622" />

---

По итогу могу сказать, что танцы с бубном вокруг каждого файла выполнять обязательно!!!
