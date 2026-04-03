# Пара 1 — Linux-основы контейнеризации
**Время:** 80 минут
**Тема:** Namespaces, cgroups, chroot — как Linux изолирует процессы

**Дополнительно:** учебные поломки — [`PRACTIC/BREAK/README.md`](../BREAK/README.md) (`linux-chaos.sh` и [`break_lab/`](../BREAK/break_lab/README.md)).

---

## Цель занятия

К концу пары студент должен своими руками создать изолированное окружение **без Docker**, используя только инструменты ядра Linux, и понять: Docker — это просто удобная обёртка над этими механизмами.

---

## Что должно быть сделано к концу пары ✅

- [ ] Посмотреть namespace-ы текущих процессов через `/proc`
- [ ] Запустить процесс в новом PID namespace (увидеть PID=1 внутри)
- [ ] Запустить процесс в новом NET namespace (изолированный сетевой интерфейс)
- [ ] Ограничить процесс по CPU через cgroup (убедиться что лимит работает)
- [ ] Сделать chroot в минимальный rootfs (запустить `/bin/sh` внутри)
- [ ] Объяснить: чем namespace отличается от cgroup (устно или письменно)

---

## Ход работы

### Блок 1 — Namespaces (25 мин)

```bash
# Посмотреть namespace-ы своего shell-процесса
ls -la /proc/$$/ns/

# Сколько всего namespace-типов в системе?
lsns

# Запустить bash в НОВОМ PID namespace
sudo unshare --pid --fork --mount-proc /bin/bash

# Внутри — убедиться что мы PID 1
echo "Мой PID: $$"
ps aux
exit

# Запустить в новом сетевом namespace
sudo unshare --net /bin/bash
ip link show        # только loopback — изоляция работает!
exit
```

**Контрольный вопрос:** Почему после `exit` процессы хоста остались нетронутыми?

---

### Блок 2 — cgroups (25 мин)

```bash
# Найти иерархию cgroup v2
ls /sys/fs/cgroup/

# Создать свою cgroup и ограничить CPU до 20%
sudo mkdir /sys/fs/cgroup/mytest
echo "20000 100000" | sudo tee /sys/fs/cgroup/mytest/cpu.max

# Запустить нагрузку и поместить её в cgroup
stress-ng --cpu 2 --timeout 30s &
echo $! | sudo tee /sys/fs/cgroup/mytest/cgroup.procs

# Проверить что лимит применился
cat /sys/fs/cgroup/mytest/cpu.stat
top   # посмотреть %CPU процесса

# Убрать нагрузку
sudo kill $(cat /sys/fs/cgroup/mytest/cgroup.procs)
```

> Если stress-ng не установлен: `sudo apt install stress-ng -y`

**Контрольный вопрос:** Что произойдёт если лимит памяти превысить? (OOM-killer)

---

### Блок 3 — chroot (20 мин)

```bash
# Создать минимальный rootfs
mkdir -p /tmp/myroot/{bin,lib,lib64,proc,dev}

# Скопировать bash и его зависимости
cp /bin/bash /tmp/myroot/bin/
cp /bin/ls   /tmp/myroot/bin/

# Скопировать нужные библиотеки (ldd покажет какие)
ldd /bin/bash
# Пример: cp /lib/x86_64-linux-gnu/libtinfo.so.6 /tmp/myroot/lib/
#         cp /lib/x86_64-linux-gnu/libc.so.6 /tmp/myroot/lib/
#         cp /lib64/ld-linux-x86-64.so.2 /tmp/myroot/lib64/

# Скопировать все зависимости одной командой
for dep in $(ldd /bin/bash | awk '/=>/ {print $3}'); do
    cp --parents "$dep" /tmp/myroot/
done
cp /lib64/ld-linux-x86-64.so.2 /tmp/myroot/lib64/

# Войти в chroot-окружение
sudo chroot /tmp/myroot /bin/bash

# Внутри: видим ТОЛЬКО наш rootfs
ls /          # только bin, lib, lib64, proc
echo "Я внутри chroot!"
exit
```

**Итог:** Вот как работает контейнер — namespace + cgroup + chroot. Docker это автоматизирует.

---

## Что сдать преподавателю

Скриншот или вывод в терминале:
1. `lsns` — список namespace-ов системы
2. `echo $$` внутри нового PID namespace (должно быть 1 или маленькое число)
3. `ip link` в новом NET namespace (только lo)
4. `cat /sys/fs/cgroup/mytest/cpu.max` — ваш лимит
5. `ls /` внутри chroot

---

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| `unshare: unshare failed: Operation not permitted` | Нужны права root: `sudo unshare ...` |
| `chroot: failed to run command '/bin/bash': No such file or directory` | Не скопированы библиотеки — проверить `ldd /bin/bash` |
| `stress-ng: command not found` | `sudo apt install stress-ng -y` |
| `/sys/fs/cgroup/mytest` не создаётся | Система использует cgroup v1 — путь будет `/sys/fs/cgroup/cpu/mytest` |
