# Результаты шестой работы.
Сделал всё. Возникла проблема с kubectl get pvc, был Pending, поменял в конфигурационном файле настройку и всё исправилось.

## Что понял:
----------------
+ ConfigMap — хранит конфигурацию
+ Secret — хранит чувствительные данные , но по умолчанию НЕ шифруется
+ base64 — это не шифрование, а просто кодирование
+ PersistentVolume (PV) и PersistentVolumeClaim (PVC) — обеспечивают постоянное хранение данных
+ Данные не удаляются при удалении pod

# Скриншоты.
![image1](https://github.com/Darkiss80/Screenshots/blob/main/6Lab/image1.png)
![image2](https://github.com/Darkiss80/Screenshots/blob/main/6Lab/image2.png)
![image3](https://github.com/Darkiss80/Screenshots/blob/main/6Lab/image3.png)
![image4](https://github.com/Darkiss80/Screenshots/blob/main/6Lab/image4.png)
