КОЛЛЕДЖ АВТОНОМНОЙ НЕКОММЕРЧЕСКОЙ ОБРАЗОВАТЕЛЬНОЙ ОРГАНИЗАЦИИ ВЫСШЕГО ОБРАЗОВАНИЯ «НАУЧНО-ТЕХНОЛОГИЧЕСКИЙ УНИВЕРСИТЕТ «СИРИУС» 
(КОЛЛЕДЖ АНОО ВО «УНИВЕРСИТЕТ «СИРИУС»)









ОТЧЕТ 
О ЛАБОРАТОРНОЙ РАБОТЕ №3











студент 3 курса обучения 
группы К0109-23
Вершинина Д А







Сириус 2026



выведем список всех доступных сетей:
<img width="869" height="206" alt="изображение" src="https://github.com/user-attachments/assets/d8817599-7886-448b-acaf-f05d139325d4" />


выведем информацию о bridge 
<img width="878" height="823" alt="изображение" src="https://github.com/user-attachments/assets/e46920ff-3521-42bf-b38a-946a573f2b07" />


создадим изолированную сеть:
<img width="878" height="72" alt="изображение" src="https://github.com/user-attachments/assets/d56beb80-21e4-4232-9cd1-4569087d2e60" />


запустим два контейнера в данной сети:
<img width="878" height="375" alt="изображение" src="https://github.com/user-attachments/assets/3a15a888-e624-473c-bdc5-c8ec9fad06e6" />


внутри сети запустим пинг:
<img width="657" height="723" alt="изображение" src="https://github.com/user-attachments/assets/dda9f699-867a-4fb9-a345-ee25c944563b" />


смотрим, что порт открыт:
<img width="827" height="135" alt="изображение" src="https://github.com/user-attachments/assets/58a8bf94-cabb-4887-85dd-49e104485602" />

без указания сети при подключение, не будет видеть db

Volumes и persistent data
запустим docker с volume
<img width="827" height="135" alt="изображение" src="https://github.com/user-attachments/assets/a4999841-50f8-4158-a90c-5f50c75d6847" />

а также добавим туда тестовые данные:
<img width="876" height="257" alt="изображение" src="https://github.com/user-attachments/assets/6e72a6ba-eb16-42e1-a333-4fa823b7ad60" />

удалим контейнер, а не том 
<img width="876" height="66" alt="изображение" src="https://github.com/user-attachments/assets/77452ef5-152b-42e8-8a8d-f95c373a9345" />


ошибка прав, пробуем запустить ту же команду с sudo
запустим контейнер снова
<img width="876" height="130" alt="изображение" src="https://github.com/user-attachments/assets/6798a1db-b2df-40dd-98da-fde4ad6d0f7a" />

проверяем сохранность данных:
<img width="876" height="147" alt="изображение" src="https://github.com/user-attachments/assets/8d15e79b-f802-416f-bbf0-48d13262457f" />


смотрим где физически находится том 
<img width="876" height="251" alt="изображение" src="https://github.com/user-attachments/assets/5a30cd87-5c30-4099-be95-68e91d436723" />


работа с docker-compose
создаем структуру проекта: 
<img width="876" height="71" alt="изображение" src="https://github.com/user-attachments/assets/632b5100-f285-4627-a1d7-31ddc454789b" />

добавляем необходимые файлы:
запускаем контейнер и смотрим за состоянием:
<img width="869" height="174" alt="изображение" src="https://github.com/user-attachments/assets/29bcea7d-1a3f-4c26-ab34-99638e992dfc" />


добавляем данные:
<img width="869" height="64" alt="изображение" src="https://github.com/user-attachments/assets/b8540307-379b-4e0b-87e1-e6d12ac370b7" />



