# СДЕЛАЛ?
ДА, сделал. Всё чётко.
namespace - Изолировать процессы, чтобы видели только то, что надо.
cgroup - Ограничивает ресурсы, которые есть процесс.
chroot - Делает каталог корневым для процесса.

# ПРОБЛЕМЫ
Была проблема с chroot окружением т.к. для ls / не хватало библиотек, но решение изи: надо было просто добавить библиотеки не только из ldd /bin/bash, но и из ldd /bin/ls.
Команда:

for dep in $(ldd /bin/ls | awk '/=>/ {print $3}'); do
    cp --parents "$dep" /tmp/myroot/
done

Фото проблем's:
![ERRSCR](https://github.com/noktirr/SCREENSHOTS/blob/main/1_Linux/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-24%2014-37-48.png)

# SCREENШОТЫ
![SCR1](https://github.com/noktirr/SCREENSHOTS/blob/main/1_Linux/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-24%2014-26-12.png)
![SCR2](https://github.com/noktirr/SCREENSHOTS/blob/main/1_Linux/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-24%2014-28-58.png)
![SCR3](https://github.com/noktirr/SCREENSHOTS/blob/main/1_Linux/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-24%2014-29-43.png)
![SCR4](https://github.com/noktirr/SCREENSHOTS/blob/main/1_Linux/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-24%2014-30-03.png)
![SCR5](https://github.com/noktirr/SCREENSHOTS/blob/main/1_Linux/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-24%2016-16-13.png)