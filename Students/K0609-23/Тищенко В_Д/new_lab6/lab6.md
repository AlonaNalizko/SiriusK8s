Отчёт по лабораторной работе №6
Тема: Настройка ядра Linux через sysctl (somaxconn, tcp_tw_reuse, ip_local_port_range)

В ходе работы я научилась настраивать параметры ядра для высоконагруженного веб-сервера через sysctl, а также делать изменения постоянными.

Что делала:

-посмотрела текущие значения: sysctl net.core.somaxconn;

-sysctl net.ipv4.tcp_tw_reuse;

-sysctl net.ipv4.ip_local_port_range.

Попробовал временно изменить параметры:

-увеличила максимальную длину очереди ожидающих соединений: sudo sysctl -w net.core.somaxconn=65535;

-включила переиспользование TCP-сокетов в состоянии TIME_WAIT: sudo sysctl -w net.ipv4.tcp_tw_reuse=1;

-расширила диапазон локальных портов: sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535".

Ошибки и как исправила:

сначала забыла sudo — получила Permission denied, исправила;

забыла кавычки для диапазона портов — исправила.

Постоянное изменение параметров:

создала файл конфигурации: sudo vim /etc/sysctl.d/99-web.conf;

добавила в него строки:

net.core.somaxconn = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
применила изменения: sudo sysctl -p /etc/sysctl.d/99-web.conf.

Ошибки и как исправила:

сначала не знала, в какой каталог класть файл — узнала, что /etc/sysctl.d/;

забыла -p при применении — исправила.

снова проверила значения: sysctl net.core.somaxconn — показал 65535;

sysctl net.ipv4.tcp_tw_reuse — показал 1;

sysctl net.ipv4.ip_local_port_range — показал 1024 65535.

Чему я научилась
-смотреть текущие параметры ядра через sysctl;

-временно менять параметры через sysctl -w;

-создавать конфигурационные файлы в /etc/sysctl.d/;

-делать изменения постоянными;

-применять конфигурацию через sysctl -p;

-настраивать параметры для высоконагруженного веб-сервера.

Ссылки на записи сессий:
https://asciinema.org/a/DszWwiFs93wOYekk
