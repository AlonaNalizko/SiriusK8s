# Пара 6 — Kubernetes: ConfigMap, Secret, PersistentVolume


Итого по лабе по поводу того, что нужно сдать:\
![alt text](imgslab6/screen1.png)\
все 3 способа передачи ConfigMap работают
![alt text](imgslab6/screen2.png)\
Данные в base64\
![alt text](imgslab6/screen3.png)\
Расшифрованные данные\
![alt text](imgslab6/screen4.png)\
После создания пода pod-with-secret, мы видим, что внутри пода информация уже не зашифрованная, благодаря этому мы можем записать их в переменные окружения, как и было показано в pod-with-secret.yaml. Затем они логгируются, после чего можно это все посмотреть в логах.\
![alt text](imgslab6/screen5.png)\
Это значит, что PV (Persistent Volume) связан с PVC (Persistent Volume Claim).\
![alt text](imgslab6/screen6.png)\
Ну и под конец подтверждение того, что даже после удаления пода с бдшкой данные сохранились, потому что PVC не удалена и осталась в статусе Bound. Следовательно данные на PV точно так же остались, НО!!!! если удалить PVC в текущем случае у нас удалится и PV.