# BREAK — учебные поломки Linux

В этой папке два набора материалов для **chaos / break-and-fix** на **Linux** (достаточно отдельной ВМ):

| Компонент | Назначение |
|-----------|------------|
| **`linux-chaos.sh`** | Один скрипт: режимы диска, сети, процессов, памяти, ядра, случайный микс, `--restore` и `--check`. |
| **`break_lab/`** | Отдельные сценарии «под инфографику»: nginx-лог, сеть, диск, бинарники, systemd + скрипты отката. |

Всё намеренно **ломает или нагружает** систему в учебных целях. Запуск **только от root** и **только на тестовой машине**, которую не жалко.

---

## Требования

- ОС: **Linux** (удобнее Ubuntu/Debian-подобные: `apt`, `iptables`, `stress`).
- **`sudo`** / root.
- Для части сценариев: **`python3`**.
- Для `memory`: пакет **`stress`** или **`stress-ng`** (скрипт может попробовать установить сам).
- Доступ к **консоли ВМ** (веб-консоль гипервизора), если после сетевого хаоса пропадёт SSH.

---

## `linux-chaos.sh` — быстрый старт

Каталог с репозитория:

```bash
cd PRACTIC/BREAK
chmod +x linux-chaos.sh   # если ещё не исполняемый
```

Справка (все ключи):

```bash
sudo ./linux-chaos.sh
```

### Режимы `--mode <имя>`

| Команда | Что происходит (кратко) |
|---------|-------------------------|
| `sudo ./linux-chaos.sh --mode disk` | Большой файл в `/tmp` + процесс с удалённым файлом (место не освобождается до убийства процесса). |
| `sudo ./linux-chaos.sh --mode disk-inode` | Масса мелких файлов в `/tmp/chaos_inodes` — давление на **inode**. |
| `sudo ./linux-chaos.sh --mode network` | Ломает **DNS**: `resolv.conf` и/или `nsswitch.conf` (случайный вариант из трёх). |
| `sudo ./linux-chaos.sh --mode network-route` | Удаляет **default route** (шлюз сохраняется в бэкап). |
| `sudo ./linux-chaos.sh --mode network-iptables` | **DROP** исходящего TCP на порт **80** (`iptables`). |
| `sudo ./linux-chaos.sh --mode process` | **Zombie**-процессы + **утечка FD** в отдельном процессе. |
| `sudo ./linux-chaos.sh --mode process-cpu` | Нагрузка **CPU** (по числу ядер). |
| `sudo ./linux-chaos.sh --mode memory` | **Memory pressure** (~75% RAM через `stress` / `stress-ng`). |
| `sudo ./linux-chaos.sh --mode kernel` | Случайный набор «плохих» **sysctl** (сеть / swap / `fs.file-max`). |
| `sudo ./linux-chaos.sh --mode kernel-ulimit` | Файл **`/etc/security/limits.d/chaos.conf`** с малым `nofile`. |
| `sudo ./linux-chaos.sh --mode random` | **2–3** случайных сценария из списка (боевой режим на время). |

Эквивалент случайного режима:

```bash
sudo ./linux-chaos.sh --random
```

### После сценария

```bash
sudo ./linux-chaos.sh --check    # статус, список «активного хаоса», df, маршруты, sysctl…
sudo ./linux-chaos.sh --restore  # откат: процессы, типы файлов, resolv/nsswitch, маршрут, iptables, sysctl по шаблону, limits.d, swap-файл и т.д.
```

### Где хранится состояние

- Каталог: **`/var/lib/linux-chaos/`**
- Лог: **`/var/lib/linux-chaos/chaos.log`**
- JSON активных сценариев: **`/var/lib/linux-chaos/active_chaos.json`**
- Бэкапы конфигов: **`/var/lib/linux-chaos/backups/`**

### Замечания по `--restore`

- Восстановление **sysctl** задаёт типовые значения (например `somaxconn`, `swappiness`, `file-max`), а не полный откат из дампа — если на ВМ были свои настройки, проверьте вручную.
- После **`kernel-ulimit`** новые сессии могли уже подхватить лимиты; после удаления `chaos.conf` перелогиньтесь при необходимости.
- Если что-то осталось от ручных правок — смотрите `chaos.log` и `--check`.

### Идея для зачёта

Скрипт сам подсказывает записать сессию:

```bash
asciinema rec chaos_$(date +%Y%m%d_%H%M%S).cast
# затем sudo ./linux-chaos.sh --mode random
# диагностика и починка; в конце sudo ./linux-chaos.sh --restore
```

---

## `break_lab/` — точечные сценарии

Отдельные bash-скрипты под задачи уровня **SRE/Linux** (лог nginx, сеть, диск с `fallocate`, «битые» бинарники, systemd). Бэкапы и откат — в **`/var/lib/linux_break_lab/`** и скриптах `99_restore_*.sh`.

Подробности: **[break_lab/README.md](break_lab/README.md)**.

Пример:

```bash
cd break_lab
sudo bash 01_nginx_log_challenge.sh
sudo bash 02_network_break.sh
# при необходимости:
sudo bash 99_restore_network.sh
```

Пути в старом `break_lab/README.md` могли ссылаться на `PRACTIC/1_Linux/break_lab` — актуальное расположение: **`PRACTIC/BREAK/break_lab`**.

---

## Сравнение подходов

| | `linux-chaos.sh` | `break_lab/` |
|--|------------------|----------------|
| Удобство | Один вход, `--restore` / `--check`, лог | Модули по темам, свои `99_restore_*` |
| Сценарии | Диск/inode/сеть/iptables/процессы/CPU/память/sysctl/ulimit | Nginx-лог, сеть, диск, ELF/systemd |
| Состояние | `/var/lib/linux-chaos` | `/var/lib/linux_break_lab`, `/opt/break_lab` |

Используйте **`linux-chaos`** для комплексных тренировок и **`break_lab`** для узких тем и совпадения с чек-листами курса.
