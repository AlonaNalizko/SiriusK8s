КОЛЛЕДЖ АВТОНОМНОЙ НЕКОММЕРЧЕСКОЙ ОБРАЗОВАТЕЛЬНОЙ ОРГАНИЗАЦИИ ВЫСШЕГО ОБРАЗОВАНИЯ «НАУЧНО-ТЕХНОЛОГИЧЕСКИЙ УНИВЕРСИТЕТ «СИРИУС» 
(КОЛЛЕДЖ АНОО ВО «УНИВЕРСИТЕТ «СИРИУС»)









ОТЧЕТ 
О ЛАБОРАТОРНОЙ РАБОТЕ №1
Linux-основы контейнеризации










студент 3 курса обучения 
группы К0109-23
Вершинина Д А








Сириус 2026



Скриншоты для преподавателя:

Список namespace-ов системы
<img width="861" height="843" alt="Снимок экрана от 2026-04-07 08-28-40" src="https://github.com/user-attachments/assets/10b15a78-745f-481b-bbe5-a07d57642244" />

echo $$ внутри нового PID namespace

<img width="841" height="150" alt="Снимок экрана от 2026-04-07 08-32-41" src="https://github.com/user-attachments/assets/af3981aa-432a-4b72-9788-92ca5c1ba356" />


Почему после exit процессы хоста остались нетронутыми ?
Так как каждый namespace это своё пространство, то они не управляют процессами хоста, и exit завершает внутри конкретного namespace, не затрагиваем остальные, в том числе родительские.

ip link в новом NET namespace (только lo):

<img width="945" height="51" alt="Снимок экрана от 2026-04-07 08-33-34" src="https://github.com/user-attachments/assets/39bc3f0d-c285-47e9-ac57-f859d2b49842" />


лимит:
<img width="1041" height="172" alt="изображение" src="https://github.com/user-attachments/assets/a42dfade-b35b-45ba-9a6d-0f79f4269fdc" />


Что произойдёт если лимит памяти превысить? (OOM-killer)
сработает OOM-killer(механизм ядра Linux) который завершит процессы для освобождения памяти. 

ls / внутри chroot:

<img width="810" height="102" alt="изображение" src="https://github.com/user-attachments/assets/90af78db-5c6e-4fa4-8ec0-d61db9c0967d" />

