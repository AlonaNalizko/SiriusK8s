# Результаты седьмой работы.
Сделал всё. Основные сложности были с curl --cacert ca.crt https://webapp.local, соединение никак не хотело устанавливаться, в итоге перезапустил Ingress nginx и неожиданно заработало. 

## Что понял:
----------------
+ RBAC — управление доступом в Kubernetes
+ NetworkPolicy — управляет сетевым взаимодействием pod'ов
+ Можно создать свой CA и подписывать сертификаты
+ Secret хранит TLS-ключи и сертификаты

# Скриншоты.
![image1](https://github.com/Darkiss80/Screenshots/blob/main/7Lab/image1.png)
![image2](https://github.com/Darkiss80/Screenshots/blob/main/7Lab/image2.png)
![image3](https://github.com/Darkiss80/Screenshots/blob/main/7Lab/image3.png)