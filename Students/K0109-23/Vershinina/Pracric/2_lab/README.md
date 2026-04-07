КОЛЛЕДЖ АВТОНОМНОЙ НЕКОММЕРЧЕСКОЙ ОБРАЗОВАТЕЛЬНОЙ ОРГАНИЗАЦИИ ВЫСШЕГО ОБРАЗОВАНИЯ «НАУЧНО-ТЕХНОЛОГИЧЕСКИЙ УНИВЕРСИТЕТ «СИРИУС» 
(КОЛЛЕДЖ АНОО ВО «УНИВЕРСИТЕТ «СИРИУС»)









ОТЧЕТ 
О ЛАБОРАТОРНОЙ РАБОТЕ №2
Docker: образы, Dockerfile, запуск











студент 3 курса обучения 
группы К0109-23
Вершинина Д А







Сириус 2026
Вывод docker images myapp:bad
<img width="922" height="134" alt="изображение" src="https://github.com/user-attachments/assets/52753e0b-7743-473f-946d-7713b3388c88" />


Контрольный вопрос: Почему образ такой большой?
Так как в файл добавляется также информация об установленных зависимостях, каждый новый слой сохраняется при запуске “run”. Хранится кэш-файлы от пакетных менеджеров. 
Вывод docker images myapp:good
<img width="922" height="134" alt="изображение" src="https://github.com/user-attachments/assets/40d53c05-e9a5-43d9-95e5-eaa406663b4e" />

Вывод docker history myapp:good — слои образа
<img width="1031" height="600" alt="изображение" src="https://github.com/user-attachments/assets/dc98555b-002d-40d3-87ed-395a36bc4800" />

визуализация слоев
<img width="1031" height="666" alt="изображение" src="https://github.com/user-attachments/assets/86bfa8d3-041a-4247-8576-95349cf566ae" />


5. https://hub.docker.com/repository/docker/dashalovenorth/flask-demo:v1.

