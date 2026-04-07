КОЛЛЕДЖ АВТОНОМНОЙ НЕКОММЕРЧЕСКОЙ ОБРАЗОВАТЕЛЬНОЙ ОРГАНИЗАЦИИ ВЫСШЕГО ОБРАЗОВАНИЯ «НАУЧНО-ТЕХНОЛОГИЧЕСКИЙ УНИВЕРСИТЕТ «СИРИУС» 
(КОЛЛЕДЖ АНОО ВО «УНИВЕРСИТЕТ «СИРИУС»)









ОТЧЕТ 
О ЛАБОРАТОРНОЙ РАБОТЕ №4
Kubernetes: установка кластера, первые поды












студент 3 курса обучения 
группы К0109-23
Вершинина Д А






Сириус 2026

подготовим окружение для выполнение лабы:
<img width="1117" height="353" alt="изображение" src="https://github.com/user-attachments/assets/984f56e7-8acc-402c-90c5-e49979b1c620" />



смотрим состояния 
<img width="1117" height="599" alt="изображение" src="https://github.com/user-attachments/assets/8cce01d0-cc50-4d36-8b6d-22a1c4b62e11" />

смотрим компоненты Control plane
<img width="1117" height="350" alt="изображение" src="https://github.com/user-attachments/assets/1a4d327b-73e0-44e8-a17d-0764184cd890" />


смотрим API ресурсы
<img width="1117" height="416" alt="изображение" src="https://github.com/user-attachments/assets/f8db78c4-6c0e-45c6-8035-a9de24ca9fa7" />

смотрим версию 
<img width="852" height="151" alt="изображение" src="https://github.com/user-attachments/assets/b3666416-fcd5-4998-9c89-717e8b0c79a5" />


Какие поды в kube-system всегда должны быть Running?
kube-apis-server (отвечает за api)
kube-controller-manager (отвечает за контроллеры)
kube-scheduler (отвечает за распределение подов по нодам)
kube-proxy (отвечает за работу сервисов)
coredns (отвечает за dns)
2. первый под 
запустим под императивно:
<img width="1135" height="199" alt="изображение" src="https://github.com/user-attachments/assets/2582bc52-94fe-4e0d-9567-1c2619ec73a0" />


следим за жизненным циклом
<img width="1135" height="118" alt="изображение" src="https://github.com/user-attachments/assets/bdcd15d8-0025-42da-bfca-1c8447c978d9" />


зайдём внутрь:


