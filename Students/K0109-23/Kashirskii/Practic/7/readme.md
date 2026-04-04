## Что должно быть сделано к концу пары ✅
 - Создать ServiceAccount с ограниченными правами (только read pods)
 - Убедиться что SA не может удалять поды (kubectl auth can-i)
 - Создать NetworkPolicy default-deny-all и разрешить только нужный трафик
 - Проверить изоляцию — один под не видит другой
 - (Бонус) Запустить Falco и сгенерировать alert при входе в контейнер

 Что сдать преподавателю
kubectl auth can-i list pods -n rbac-demo --as=system:serviceaccount:rbac-demo:app-reader → yes
kubectl auth can-i delete pods -n rbac-demo --as=system:serviceaccount:rbac-demo:app-reader → no
kubectl exec frontend -- wget database-svc → timeout (NetworkPolicy работает)
kubectl exec backend -- wget database-svc → 200 OK
openssl verify -CAfile ca.crt webapp.crt → webapp.crt: OK
curl --cacert ca.crt https://webapp.local → ответ от nginx (TLS работает)



В ходе работы, я случайно скопировал файл rbac.yaml как rbac.yaml: и долго думал че не так
а так лаба инетересная


## Скриншоты

![Скриншот 1](img7lab/1.png)
![Скриншот 2](img7lab/2.png)
![Скриншот 3](img7lab/3.png)
![Скриншот 4](img7lab/4.png)
![Скриншот 5](img7lab/5.png)
![Скриншот 6](img7lab/6.png)
![Скриншот 7](img7lab/7.png)
![Скриншот 8](img7lab/8.png)
![Скриншот 9](img7lab/9.png)
![Скриншот 10](img7lab/10.png)
![Скриншот 11](img7lab/11.png)