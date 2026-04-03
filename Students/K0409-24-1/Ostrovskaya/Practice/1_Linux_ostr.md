1_laba
Структура отчета: 
# 1 выводы в терминале
# 2. вопросы
# 3. трудности

1.  `lsns` — список namespace-ов системы

user@user-VMware20-1:~$ lsns
        NS TYPE   NPROCS   PID USER COMMAND
4026531834 time       72  2747 user /usr/bin/pipewire
4026531835 cgroup     72  2747 user /usr/bin/pipewire
4026531836 pid        72  2747 user /usr/bin/pipewire
4026531837 user       72  2747 user /usr/bin/pipewire
4026531838 uts        72  2747 user /usr/bin/pipewire
4026531839 ipc        72  2747 user /usr/bin/pipewire
4026531840 net        72  2747 user /usr/bin/pipewire
4026531841 mnt        70  2747 user /usr/bin/pipewire
4026532782 mnt         0       root 
4026532845 mnt         0       root 
4026532913 mnt         2  2750 user /snap/snapd-desktop-integration/315/usr/bin/
![alt text](1_lsns-1.jpg)

2.  `echo $$` внутри нового PID namespace (должно быть 1 или маленькое число)

user@user-VMware20-1:~$ sudo unshare --pid --fork --mount-proc /bin/bash
root@user-VMware20-1:/home/user# echo $$
1


3. `ip link` в новом NET namespace (только lo)

root@user-VMware20-1:/home/user# ip link
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

4. `cat /sys/fs/cgroup/mytest/cpu.max` — ваш лимит

user@user-VMware20-1:~$ cat /sys/fs/cgroup/mytest/cpu.max
20000 100000

5. `ls /` внутри chroot

user@user-VMware20-1:~$ sudo chroot /tmp/myroot /bin/bash
bash-5.2# ls /
bin  dev  lib  lib64  proc



# Вопросы:
1. Почему после exit процессы хоста остались нетронутыми? (Блок 1)
Потому что PID namespace иерархичен. Родительский namespace (хост) видит дочерние, но дочерний не видит родителя. Когда мы сделали exit, мы убили только процессы внутри нашей изолированной "коробки". Хост-система даже не заметила, так как для неё это был просто один обычный процесс, который завершился.

2. Что произойдёт если лимит памяти превысить? (Блок 2)
Сработает OOM-killer (Out Of Memory killer). Ядро Linux увидит, что процесс нарушил лимит, и принудительно убьёт его (сигналом SIGKILL), чтобы он не "повесил" всю систему.

3. Чем namespace отличается от cgroup? (Итог)
Namespace — это ИЗОЛЯЦИЯ ("стены"). Процесс не видит другие процессы, сеть или файлы хоста.
Cgroup — это ОГРАНИЧЕНИЕ ("нормы"). Процесс видит всё, но не может взять больше ресурсов (CPU, памяти), чем ему разрешили.

# Сложности:
1. Cgroups: процесс завершился раньше времени
 stress-ng с таймаутом 30 сек успел завершиться, пока мы искали его PID.
-> запустила без таймаута: stress-ng --cpu 2 &
2. Chroot: не работали команды внутри
 ls ругался на отсутствие libselinux.so.1 и libpcre2-8.so.0.
-> Скопировала недостающие библиотеки вручную.

Скину доработки 31.03.2026