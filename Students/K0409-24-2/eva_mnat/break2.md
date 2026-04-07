После запуска скрипта-ломалки пропал default-маршрут, сломался DNS и настройка nsswitch.
Вручную добавил маршрут: ip route add default via 192.168.38.2 dev ens160,
прописал DNS 8.8.8.8 и 1.1.1.1 в /etc/resolv.conf,
в /etc/nsswitch.conf исправил hosts: на files dns.
Проверил: пинг до IP и доменов работает, сайты открываются. Сеть восстановлена.
https://asciinema.org/a/38et87Pb74uU7gU3 
