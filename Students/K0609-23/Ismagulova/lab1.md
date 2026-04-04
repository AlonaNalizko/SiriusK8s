# LAB1
## block1
---

Сначала просматриваются все пространства имен, типы: cgroup, ipc, mnt (mount), net, pid, user, uts, а также специфичные для дочерних процессов pid_for_children и time_for_children. Команда lsnc там выведет их количество (их там много).
<img width="1230" height="664" alt="изображение" src="https://github.com/user-attachments/assets/0d2553dc-21f2-4273-ae97-4f00ae22b6b7" />

Далее создается новый PID namespace, внутри которого отсчет идентификаторов процессов (PID) начинается заново и туда еще заходим и проверяем что мы PID 1.
<img width="781" height="315" alt="изображение" src="https://github.com/user-attachments/assets/b832ae9d-aba8-4620-8893-432d1ea02aa3" />

Дальше создается пустой стек, в котором можно увидеть один сетевой интерфейс, который по умолчанию будет выключен
<img width="888" height="168" alt="изображение" src="https://github.com/user-attachments/assets/a6ec053c-e45e-433a-8d94-4f90ba48c65b" />

*Ответ на контрольный вопрос*: потому что все действия, которые выполнялись, они были внутри пространства, также мы используем exit, что означает, что мы заканчиваем действия в самом пространстве, не затрагивая при этом хост

## block2
---

Сначала в cgroups v2 необходимо создать папку в /sys/fs/cgroup/, и ядро Linux автоматически создаст там управляющие файлы. Далее устанавливаются лимит 20% от одного ядра.
<img width="718" height="509" alt="изображение" src="https://github.com/user-attachments/assets/bb9ebb4d-97d4-42c1-a99e-5409195ccb3f" />

Далее необходимо было запустить нагрузку, но вылезла ошибка из-за того, что не была установлена утилита stress-ng, установка выполняется с помошью команды sudo apt install stress-ng -y
<img width="727" height="402" alt="изображение" src="https://github.com/user-attachments/assets/ce067ced-34bd-4ad3-87d7-2c5dcc01e4e1" />

На скрине видно, что выдался PID 21098. На этом этапе процесс пытается занять 200% ресурсов процессора (2 полных ядра).После записи видно, что планировщик задач начал принудительно прерывать выполнение stress-ng, разрешая ему работать только 20мс из каждых 100мс. Суммарное потребление упало до 0.2 ядра.
<img width="718" height="289" alt="изображение" src="https://github.com/user-attachments/assets/4cf7b4ea-a3df-4789-9faa-7307584143ba" />

Выполняется проверка лимита.
<img width="989" height="225" alt="изображение" src="https://github.com/user-attachments/assets/fe1eccf8-b27b-4d91-99fb-31dc974fe1d0" />

В конце данного блока с помощью kill убираем нагрузку

*Ответ на контрольный вопрос*: Если привысить лимит памяти, то OOM-killer завершит процесс именно внутри этой cgroup, а также появится надпись Killed или Out of memory.

## block3
---

Здесь создается минимальный rootfs, а также для начала копируется bash и его минимальные зависимости
<img width="579" height="209" alt="изображение" src="https://github.com/user-attachments/assets/0c2e92e7-8163-4275-9ac8-039a1a60f27b" />

С помощью ldd /bin/bash можно посмотреть, какие библиотеки следует скопировать, в данном случае мне пригодились эти (если честно, я тут очень сильно запуталась, тк скачивала одну, нужна была другая и тд, но в итоге разобралась, мой косяк):

```bash
cp /lib/x86_64-linux-gnu/libtinfo.so.6 /tmp/myroot/lib/
cp /lib/x86_64-linux-gnu/libc.so.6 /tmp/myroot/lib/
cp /lib64/ld-linux-x86-64.so.2 /tmp/myroot/lib64/
cp /lib/x86_64-linux-gnu/libgcc_s.so.1 /tmp/myroot/lib/
cp /lib/x86_64-linux-gnu/libm.so.6 /tmp/myroot/lib/
```
<img width="832" height="155" alt="изображение" src="https://github.com/user-attachments/assets/2f8c472c-8a80-4b4c-91d6-59d97144dd84" />

Входим в chroot окружение. Здесь ошибка была как раз из-за того, что не все библиотеки скачала.
<img width="1183" height="163" alt="изображение" src="https://github.com/user-attachments/assets/a9be3e43-c3d5-458f-b42a-fa9d03bd0636" />
<img width="478" height="143" alt="Снимок экрана от 2026-03-27 23-39-11" src="https://github.com/user-attachments/assets/b0912b74-7f9f-4498-986b-f7fb7275cb06" />
<img width="425" height="136" alt="Снимок экрана от 2026-03-27 23-41-03" src="https://github.com/user-attachments/assets/0081aa22-b633-451e-9d12-1319faf032a4" />

---
Короче все заработало, впервые попробовала поработать stress-ng, а также разобралась с библиотеками




