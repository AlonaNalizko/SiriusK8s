# Отчет по лабораторной работе break 4


в ходе работы надо было понять почему каждый файл не запускается, и починить его или хотя бы понять причину

для начала я посмотрела какие файлы вообще создались и что там проиходят командой file /opt/break_lab/* и там  были скрипты которые создались

теперь я попробывала запустить каждый скрипт, потому что знала что там будет ошибка, и это были сделано с целью понять, какая конкретно..

- запустив скрипт /opt/break_lab/mystery_no_exec мне   отказали в доступе 

- запустив скрипт /opt/break_lab/mystery_bad_interpreter мне сказали что система не понимает как открыть этот файл

- запустив скрипт /opt/break_lab/mystery_truncated_elf мне сказали что это недоделанный или поломанный банарник, то есть начало правильное, а дальше пусто

- запустив скрипт /opt/break_lab/not_a_binary он запустился 

# Починка скриптов

- для починки mystery_no_exec сделать его исполняемым командой `chmod +x /opt/break_lab/mystery_no_exec`

- для починки mystery_bad_interpreter указать правильный интерпритатор, исправлением shebang командой `sed -i 's|#!/bin/no_such_interpreter_break_lab|#!/bin/bash|' /opt/break_lab/mystery_bad_interpreter` 

- для починки mystery_truncated_elf сделать его исполняемым командой `rm /opt/break_lab/mystery_truncated_elf` потом `cp /bin/echo /opt/break_lab/mystery_truncated_elf` и `chmod +x /opt/break_lab/mystery_truncated_elf` после чего все заработает

- not_a_binary это просто bash скрипт - просто текст с правом на выполнение и если его запустить, то он просто выведет hello

все после этого я зпустила все скрипты, все починила, проблем особых не возникло

удалила все командой `sudo rm -rf /opt/break_lab`

[видос починки и запуска скриптов](https://asciinema.org/a/GxyPiFrhbnPG6aAl)
