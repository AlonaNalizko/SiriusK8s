# <b>СДЕЛАЛ? + К.В.</b>
<b>ДА, сделал.</b>

Контрольные вопросы: <br>

* <b>Блок 1 — Какие поды в kube-system всегда должны быть Running?</b>

    etcd, kube-apiserver, kube-controller-manager и kube-scheduler. Плюс coredns (или kube-dns), kube-proxy на каждой ноде, а если через kubeadm — то еще kube-controller-manager и kube-scheduler со статическими подами. Если любой из них не Running то кластер, скорее всего, либо развалился, либо только стартует.

* <b>Блок 4 — Почему Pod не удалился, а перезапустился? Кто за это отвечает?</b>

    Потому что в манифесте пода не было restartPolicy: Never — по умолчанию стоит Always. За перезапуск отвечает kubelet на той ноде, где под запущен: он мониторит состояние контейнеров через CRI и если видит, что процесс (или livenessProbe) умер — дергает рантайм, чтобы пересоздать контейнер внутри того же пода. Сам Pod остается на месте, просто рестартует его содержимое.

# <b>ПРОБЛЕМЫ</b>
нет проблем

# <b>SCREENШОТЫ</b>
![SCR1](https://github.com/noktirr/SCREENSHOTS/blob/main/4_Kub_init/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-26%2015-50-22.png) <br>
![SCR2](https://github.com/noktirr/SCREENSHOTS/blob/main/4_Kub_init/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-26%2016-00-03.png) <br>
![SCR3](https://github.com/noktirr/SCREENSHOTS/blob/main/4_Kub_init/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-26%2016-00-49.png) <br>
![SCR4](https://github.com/noktirr/SCREENSHOTS/blob/main/4_Kub_init/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-26%2016-01-06.png) <br>
![SCR5](https://github.com/noktirr/SCREENSHOTS/blob/main/4_Kub_init/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-26%2016-01-28.png) <br>