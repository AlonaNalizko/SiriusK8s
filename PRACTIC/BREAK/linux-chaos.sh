#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#   linux-chaos.sh — Linux Chaos Engineering Lab
#   Курс: Linux Internals — Senior Linux Engineers
#
#   ВНИМАНИЕ: Запускай ТОЛЬКО на виртуальной машине!
#   Этот скрипт намеренно ломает систему для учебных целей.
#   Все изменения обратимы. Есть режим --restore для восстановления.
#
#   Использование:
#     ./linux-chaos.sh --mode disk        # сломать диск
#     ./linux-chaos.sh --mode network     # сломать сеть
#     ./linux-chaos.sh --mode process     # сломать процессы
#     ./linux-chaos.sh --mode memory      # сломать память
#     ./linux-chaos.sh --mode kernel      # сломать параметры ядра
#     ./linux-chaos.sh --mode random      # случайная комбинация 2-3 сценариев
#     ./linux-chaos.sh --restore          # восстановить систему
#     ./linux-chaos.sh --check            # проверить что именно сломано
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── ЦВЕТА ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── КОНФИГ ──────────────────────────────────────────────────────────────────
CHAOS_DIR="/var/lib/linux-chaos"
BACKUP_DIR="${CHAOS_DIR}/backups"
LOG_FILE="${CHAOS_DIR}/chaos.log"
STATE_FILE="${CHAOS_DIR}/active_chaos.json"

# ─── ФУНКЦИИ ВЫВОДА ──────────────────────────────────────────────────────────
log() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${RESET} $*" | tee -a "${LOG_FILE}"; }
ok()  { echo -e "${GREEN}[✓]${RESET} $*" | tee -a "${LOG_FILE}"; }
err() { echo -e "${RED}[✗]${RESET} $*" | tee -a "${LOG_FILE}"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $*" | tee -a "${LOG_FILE}"; }
section() {
  echo ""
  echo -e "${BOLD}${PURPLE}═══════════════════════════════════════${RESET}"
  echo -e "${BOLD}${PURPLE}  $*${RESET}"
  echo -e "${BOLD}${PURPLE}═══════════════════════════════════════${RESET}"
  echo ""
}

# ─── ИНИЦИАЛИЗАЦИЯ ───────────────────────────────────────────────────────────
init_chaos() {
  mkdir -p "${CHAOS_DIR}" "${BACKUP_DIR}"
  touch "${LOG_FILE}"
  if [[ ! -f "${STATE_FILE}" ]]; then
    echo '{"active": []}' > "${STATE_FILE}"
  fi
}

register_chaos() {
  local name="$1"
  local description="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Добавить в список активных хаосов
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('${STATE_FILE}') as f:
    state = json.load(f)
state['active'].append({'name': '${name}', 'desc': '${description}', 'time': '${timestamp}'})
with open('${STATE_FILE}', 'w') as f:
    json.dump(state, f, indent=2)
" 2>/dev/null || true
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# CHAOS SCENARIOS
# ═══════════════════════════════════════════════════════════════════════════

# ─── DISK CHAOS ───────────────────────────────────────────────────────────────
chaos_disk_fill_tmp() {
  section "💾 DISK CHAOS: Заполняем /tmp большим файлом"
  warn "Создаём 2GB файл в /tmp..."

  local free_kb
  free_kb=$(df /tmp | awk 'NR==2{print $4}')
  local fill_mb=$(( free_kb / 1024 * 80 / 100 ))  # 80% свободного места
  fill_mb=$(( fill_mb > 2048 ? 2048 : fill_mb ))

  dd if=/dev/urandom of=/tmp/chaos_bigfile bs=1M count="${fill_mb}" 2>/dev/null
  ok "Создан файл /tmp/chaos_bigfile (${fill_mb}MB)"
  log "df -h /tmp:"
  df -h /tmp | tee -a "${LOG_FILE}"

  register_chaos "disk_fill_tmp" "Создан большой файл в /tmp (${fill_mb}MB)"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} /tmp почти полон."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Найти что занимает место в /tmp"
  echo "  2. Определить: это безопасно удалять?"
  echo "  3. Освободить место не убивая важные процессы"
}

chaos_disk_inode_exhaust() {
  section "💾 DISK CHAOS: Исчерпание inode"
  warn "Создаём 200,000 пустых файлов в /tmp/chaos_inodes/..."

  mkdir -p /tmp/chaos_inodes

  # Создаём батчами для скорости
  python3 -c "
import os
base = '/tmp/chaos_inodes'
for i in range(200000):
    open(f'{base}/f{i}', 'w').close()
print('Done')
" 2>/dev/null && ok "Создано ~200K файлов" || {
    # Fallback если python3 недоступен
    for i in $(seq 1 50000); do touch "/tmp/chaos_inodes/f${i}"; done
    ok "Создано ~50K файлов"
  }

  log "df -i /tmp:"
  df -i /tmp | tee -a "${LOG_FILE}"

  register_chaos "disk_inode_exhaust" "Исчерпание inode в /tmp через 200K пустых файлов"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} inode в /tmp практически исчерпаны."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Найти почему нельзя создать новый файл (хотя место есть)"
  echo "  2. Использовать df -i для диагностики"
  echo "  3. Найти директорию с тысячами файлов"
  echo "  4. Безопасно очистить"
}

chaos_disk_deleted_fd() {
  section "💾 DISK CHAOS: Процесс держит дескриптор удалённого файла"
  warn "Запускаем процесс который пишет в файл, потом удалим файл..."

  # Создаём скрипт-процесс который пишет в файл
  cat > /tmp/chaos_writer.sh << 'EOF'
#!/bin/bash
# Этот процесс пишет в файл непрерывно
exec 3>/tmp/chaos_growing_log.txt
while true; do
  echo "$(date): Writing data $(dd if=/dev/urandom bs=1k count=1 2>/dev/null | base64)" >&3
  sleep 0.1
done
EOF
  chmod +x /tmp/chaos_writer.sh

  # Запустить в фоне
  nohup /tmp/chaos_writer.sh &>/dev/null &
  local writer_pid=$!
  echo "${writer_pid}" > "${CHAOS_DIR}/writer_pid"

  sleep 2

  # Удалить файл пока процесс держит его открытым
  rm -f /tmp/chaos_growing_log.txt
  ok "Файл удалён но процесс (PID: ${writer_pid}) продолжает в него писать"

  sleep 2
  log "Проверка через df..."
  df -h / | tee -a "${LOG_FILE}"

  register_chaos "disk_deleted_fd" "Процесс PID:${writer_pid} держит дескриптор удалённого файла"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} Файл удалён но место не освобождается."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. df -h показывает диск почти полон, но du не объясняет почему"
  echo "  2. Найти процесс удерживающий дескриптор (hint: lsof)"
  echo "  3. Освободить место без перезагрузки"
  echo "  4. Объяснить механизм (inode + dentry)"
}

# ─── NETWORK CHAOS ────────────────────────────────────────────────────────────
chaos_network_dns() {
  section "🌐 NETWORK CHAOS: Сломать DNS"

  # Бэкап
  cp /etc/resolv.conf "${BACKUP_DIR}/resolv.conf.bak" 2>/dev/null || true
  cp /etc/nsswitch.conf "${BACKUP_DIR}/nsswitch.conf.bak" 2>/dev/null || true

  warn "Ломаем /etc/resolv.conf и /etc/nsswitch.conf..."

  # Случайно выбрать тип поломки
  local break_type=$(( RANDOM % 3 ))

  case $break_type in
    0)
      # Поставить неработающий DNS сервер
      cat > /etc/resolv.conf << 'EOF'
# Chaos Engineering — DNS broken
nameserver 192.0.2.1
nameserver 192.0.2.2
EOF
      log "Установлен несуществующий DNS сервер (192.0.2.1)"
      register_chaos "network_dns_bad_server" "В resolv.conf установлен несуществующий DNS 192.0.2.1"
      ;;
    1)
      # Закомментировать dns в nsswitch.conf
      sed -i 's/^\(hosts:.*\)dns\(.*\)$/\1#dns\2/' /etc/nsswitch.conf
      log "DNS отключён в nsswitch.conf"
      register_chaos "network_dns_nsswitch" "DNS закомментирован в /etc/nsswitch.conf"
      ;;
    2)
      # Оба варианта
      cat > /etc/resolv.conf << 'EOF'
# Chaos Engineering
nameserver 192.0.2.1
EOF
      sed -i 's/^\(hosts:.*\)dns\(.*\)$/\1#dns\2/' /etc/nsswitch.conf
      log "Сломаны resolv.conf И nsswitch.conf"
      register_chaos "network_dns_both" "Сломаны resolv.conf И nsswitch.conf"
      ;;
  esac

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} DNS не работает."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. curl google.com не работает — найти почему"
  echo "  2. Проверить: ping по IP работает? (ping 8.8.8.8)"
  echo "  3. Найти что именно сломано в DNS конфигурации"
  echo "  4. Починить curl google.com"
}

chaos_network_route() {
  section "🌐 NETWORK CHAOS: Сломать маршрутизацию"

  # Сохранить текущую таблицу маршрутов
  ip route show > "${BACKUP_DIR}/routes.bak" 2>/dev/null || true

  warn "Удаляем дефолтный маршрут..."

  local gw
  gw=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
  local dev
  dev=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')

  if [[ -n "${gw}" ]]; then
    echo "${gw} ${dev}" > "${BACKUP_DIR}/default_route.bak"
    ip route del default 2>/dev/null || true
    ok "Удалён дефолтный маршрут через ${gw}"
    register_chaos "network_route" "Удалён дефолтный маршрут (шлюз: ${gw})"

    echo ""
    echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} Нет дефолтного маршрута — нет интернета."
    echo -e "${YELLOW}Задача студента:${RESET}"
    echo "  1. curl google.com не работает, ping 8.8.8.8 не работает"
    echo "  2. Диагностировать: ip route show"
    echo "  3. Восстановить маршрутизацию"
    echo "  4. Дополнительно: ping 192.168.x.x (локальная сеть) работает?"
  else
    warn "Не удалось найти дефолтный маршрут — пропускаем"
  fi
}

chaos_network_iptables() {
  section "🌐 NETWORK CHAOS: Заблокировать порт через iptables"

  # Сохранить правила
  iptables-save > "${BACKUP_DIR}/iptables.bak" 2>/dev/null || true

  warn "Блокируем исходящие соединения на порт 80 (HTTP)..."
  iptables -A OUTPUT -p tcp --dport 80 -j DROP 2>/dev/null || {
    warn "iptables недоступен, пропускаем"
    return
  }

  ok "Добавлено правило: DROP OUTPUT port 80"
  register_chaos "network_iptables_port80" "iptables DROP для исходящего порта 80"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} HTTP (порт 80) заблокирован."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. curl http://example.com зависает — найти почему"
  echo "  2. curl https://example.com работает — почему разница?"
  echo "  3. Найти правило iptables и удалить его"
  echo "  4. Инструменты: iptables -L -n -v, ss, curl"
}

# ─── PROCESS CHAOS ───────────────────────────────────────────────────────────
chaos_process_zombie() {
  section "⚙️ PROCESS CHAOS: Создать zombie-процессы"

  warn "Создаём 5 zombie-процессов..."

  cat > /tmp/chaos_zombie.py << 'PYEOF'
#!/usr/bin/env python3
import os, time, sys

zombies = []
for i in range(5):
    pid = os.fork()
    if pid == 0:
        # Дочерний процесс — умирает сразу
        sys.exit(0)
    else:
        # Родитель не вызывает wait() — дочерний становится зомби
        zombies.append(pid)
        print(f"Created zombie PID: {pid}")

print(f"Zombie PIDs: {zombies}")
print("Parent sleeping (holding zombie children)...")
# Родитель живёт долго не вызывая wait()
time.sleep(3600)
PYEOF

  python3 /tmp/chaos_zombie.py &
  local zombie_parent=$!
  echo "${zombie_parent}" > "${CHAOS_DIR}/zombie_parent_pid"

  sleep 1
  ok "Zombie процессы созданы (родитель PID: ${zombie_parent})"

  log "Количество zombie:"
  ps aux | grep -c Z | tee -a "${LOG_FILE}" || true

  register_chaos "process_zombie" "5 zombie процессов, родитель PID:${zombie_parent}"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} В системе есть zombie-процессы."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Найти zombie-процессы (STAT = Z в ps)"
  echo "  2. Найти их родителя"
  echo "  3. Объяснить: почему нельзя убить zombie через kill -9?"
  echo "  4. Как правильно избавиться от zombie?"
}

chaos_process_highload() {
  section "⚙️ PROCESS CHAOS: Создать высокую нагрузку на CPU"

  local cpu_count
  cpu_count=$(nproc)

  warn "Запускаем ${cpu_count} процессов нагрузки на CPU..."

  for i in $(seq 1 "${cpu_count}"); do
    (while true; do :; done) &
  done

  # Сохранить PID-ы
  jobs -p > "${CHAOS_DIR}/cpu_pids"

  ok "Запущено ${cpu_count} CPU-нагрузочных процессов"

  sleep 1
  log "Текущий Load Average:"
  cat /proc/loadavg | tee -a "${LOG_FILE}"

  register_chaos "process_highload" "${cpu_count} бесконечных CPU процессов"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} LA растёт, CPU перегружен."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Используй top/htop — найди процессы с 100% CPU"
  echo "  2. Найди их PID через ps"
  echo "  3. Убей все одной командой (hint: pkill или kill с группой)"
  echo "  4. Дождись пока LA вернётся в норму"
}

chaos_process_fd_leak() {
  section "⚙️ PROCESS CHAOS: Утечка файловых дескрипторов"

  warn "Запускаем процесс с утечкой файловых дескрипторов..."

  cat > /tmp/chaos_fd_leak.py << 'PYEOF'
#!/usr/bin/env python3
import time, os, tempfile

fds = []
print(f"Starting FD leak process PID: {os.getpid()}")
while True:
    try:
        # Открываем файл но никогда не закрываем
        f = tempfile.NamedTemporaryFile(dir='/tmp', prefix='chaos_fd_', delete=False)
        fds.append(f)
        if len(fds) % 100 == 0:
            print(f"Leaked FDs: {len(fds)}")
    except Exception as e:
        print(f"Can't open more files: {e}")
        time.sleep(10)
    time.sleep(0.01)
PYEOF

  python3 /tmp/chaos_fd_leak.py &
  local leak_pid=$!
  echo "${leak_pid}" > "${CHAOS_DIR}/fd_leak_pid"

  sleep 3
  local fd_count
  fd_count=$(ls /proc/${leak_pid}/fd 2>/dev/null | wc -l || echo "?")
  ok "Запущен процесс утечки (PID: ${leak_pid}, текущих FD: ~${fd_count})"

  register_chaos "process_fd_leak" "Утечка FD в процессе PID:${leak_pid}"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} Процесс непрерывно открывает файлы."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Найди процесс с подозрительно большим количеством FD"
  echo "  2. Инструменты: lsof -p PID, ls /proc/PID/fd | wc -l"
  echo "  3. Что за файлы он открывает? Все ли нужны?"
  echo "  4. Каков ulimit -n ? Что произойдёт когда достигнет лимита?"
}

# ─── MEMORY CHAOS ─────────────────────────────────────────────────────────────
chaos_memory_pressure() {
  section "🧠 MEMORY CHAOS: Memory pressure (stress)"

  if ! command -v stress &>/dev/null && ! command -v stress-ng &>/dev/null; then
    warn "stress/stress-ng не установлен. Устанавливаем..."
    apt-get install -y stress 2>/dev/null || yum install -y stress 2>/dev/null || {
      err "Не удалось установить stress. Пропускаем."
      return
    }
  fi

  local total_mb
  total_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
  local stress_mb=$(( total_mb * 75 / 100 ))  # 75% RAM

  warn "Запускаем memory stress: ${stress_mb}MB (75% RAM)..."

  if command -v stress-ng &>/dev/null; then
    stress-ng --vm 1 --vm-bytes "${stress_mb}M" --vm-keep --timeout 3600 &
  else
    stress --vm 1 --vm-bytes "${stress_mb}M" --vm-keep &
  fi

  local stress_pid=$!
  echo "${stress_pid}" > "${CHAOS_DIR}/memory_stress_pid"

  sleep 2
  log "Состояние памяти:"
  free -h | tee -a "${LOG_FILE}"

  register_chaos "memory_pressure" "Memory stress ${stress_mb}MB (PID:${stress_pid})"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} 75% RAM занято stress процессом."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Используй free -h, vmstat 1, /proc/meminfo"
  echo "  2. Найди процесс потребляющий память (top M, htop, atop m)"
  echo "  3. Смотри: используется ли swap? Каков swappiness?"
  echo "  4. OOM killer убил что-нибудь? Проверь dmesg"
}

chaos_memory_swap_fill() {
  section "🧠 MEMORY CHAOS: Заполнить swap"

  local swap_total
  swap_total=$(grep SwapTotal /proc/meminfo | awk '{print int($2/1024)}')

  if [[ "${swap_total}" -eq 0 ]]; then
    warn "Swap не настроен. Создаём swap файл..."
    dd if=/dev/zero of=/tmp/swapfile bs=1M count=512 2>/dev/null
    mkswap /tmp/swapfile 2>/dev/null
    swapon /tmp/swapfile 2>/dev/null
    swap_total=512
    echo "/tmp/swapfile" > "${CHAOS_DIR}/created_swap"
  fi

  local fill_mb=$(( swap_total * 80 / 100 ))
  warn "Пытаемся заполнить ${fill_mb}MB swap..."

  # Запускаем несколько процессов с памятью чтобы вытолкнуть в swap
  for i in 1 2 3; do
    (python3 -c "
import time
# Выделить память которую ядро вытолкнет в swap
data = bytearray(${fill_mb} // 3 * 1024 * 1024)
# Записать что-нибудь чтобы страницы были dirty
for i in range(0, len(data), 4096):
    data[i] = i % 256
time.sleep(3600)
" &) 2>/dev/null
  done

  sleep 3
  log "Использование swap:"
  free -h | tee -a "${LOG_FILE}"
  swapon --show 2>/dev/null | tee -a "${LOG_FILE}" || true

  register_chaos "memory_swap_fill" "Попытка заполнить swap"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} Активное давление на память и swap."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Проверить: swapon --show, free -h"
  echo "  2. Найти что потребляет столько памяти"
  echo "  3. Проверить vm.swappiness — какое значение сейчас?"
  echo "  4. Как защитить критический процесс от OOM?"
}

# ─── KERNEL CHAOS ─────────────────────────────────────────────────────────────
chaos_kernel_sysctl() {
  section "🔬 KERNEL CHAOS: Сломать sysctl параметры"

  # Бэкап
  sysctl -a 2>/dev/null > "${BACKUP_DIR}/sysctl.bak" || true

  warn "Устанавливаем неоптимальные/проблемные sysctl параметры..."

  local break_type=$(( RANDOM % 3 ))

  case $break_type in
    0)
      # Отключить ip_forward (сломает NAT/routing)
      sysctl -w net.ipv4.ip_forward=0 2>/dev/null || true
      # Очень маленький somaxconn
      sysctl -w net.core.somaxconn=1 2>/dev/null || true
      log "Установлено: ip_forward=0, somaxconn=1"
      register_chaos "kernel_sysctl_network" "ip_forward=0, somaxconn=1"

      echo -e "${YELLOW}Поломка:${RESET} somaxconn=1 (очередь входящих соединений = 1)"
      echo "  Симптом: веб-сервер под нагрузкой отказывает новым соединениям"
      ;;
    1)
      # Агрессивный swap
      sysctl -w vm.swappiness=100 2>/dev/null || true
      # Маленький port range
      sysctl -w net.ipv4.ip_local_port_range="32000 32100" 2>/dev/null || true
      log "Установлено: swappiness=100, ip_local_port_range=32000-32100"
      register_chaos "kernel_sysctl_memory" "swappiness=100, ip_local_port_range=32000-32100"

      echo -e "${YELLOW}Поломка:${RESET} swappiness=100 + крошечный диапазон портов"
      echo "  Симптом 1: система активно использует swap даже при свободной RAM"
      echo "  Симптом 2: 'Cannot assign requested address' при многих соединениях"
      ;;
    2)
      # Маленький fs.file-max
      local current_max
      current_max=$(sysctl -n fs.file-max 2>/dev/null || echo "1000000")
      echo "fs.file-max=${current_max}" >> "${BACKUP_DIR}/sysctl_custom.bak"
      sysctl -w fs.file-max=1024 2>/dev/null || true
      log "Установлено: fs.file-max=1024"
      register_chaos "kernel_sysctl_files" "fs.file-max=1024"

      echo -e "${YELLOW}Поломка:${RESET} fs.file-max=1024 (максимум открытых файлов в системе)"
      echo "  Симптом: 'Too many open files' для новых процессов"
      ;;
  esac

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} Параметры ядра изменены."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Найди что изменилось: sysctl -a | grep -v '^#'"
  echo "  2. Определи какой параметр вызывает проблему"
  echo "  3. Верни правильные значения через sysctl -w"
  echo "  4. Сделай изменения постоянными через /etc/sysctl.d/"
}

chaos_kernel_ulimit() {
  section "🔬 KERNEL CHAOS: Сломать ulimits"

  warn "Устанавливаем критически низкий nofile лимит для новых процессов..."

  # Записать скрипт который запускается с низкими лимитами
  cat > /tmp/chaos_low_limit.sh << 'EOF'
#!/bin/bash
# Запускает новые процессы с критически низким лимитом FD
ulimit -n 10
exec "$@"
EOF
  chmod +x /tmp/chaos_low_limit.sh

  # Добавить в /etc/security/limits.d
  cat > /etc/security/limits.d/chaos.conf << 'EOF'
# Chaos Engineering - LOW LIMITS
* soft nofile 64
* hard nofile 128
EOF

  ok "Установлен низкий лимит в /etc/security/limits.d/chaos.conf"
  register_chaos "kernel_ulimit" "nofile soft=64 hard=128 в limits.d/chaos.conf"

  echo ""
  echo -e "${RED}${BOLD}[CHAOS ACTIVE]${RESET} Лимиты открытых файлов критически малы."
  echo -e "${YELLOW}Задача студента:${RESET}"
  echo "  1. Узнай текущие лимиты: ulimit -a"
  echo "  2. Найди файл где они установлены: /etc/security/limits.d/"
  echo "  3. Удали chaos.conf или исправь значения"
  echo "  4. Какой нормальный лимит для production сервера?"
}

# ─── RESTORE ─────────────────────────────────────────────────────────────────
restore_all() {
  section "🔧 ВОССТАНОВЛЕНИЕ СИСТЕМЫ"

  log "Начинаем восстановление..."

  # Убить все chaos процессы
  warn "Останавливаем chaos процессы..."

  for pid_file in "${CHAOS_DIR}"/*_pid; do
    [[ -f "${pid_file}" ]] || continue
    local pid
    pid=$(cat "${pid_file}" 2>/dev/null || true)
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      ok "Убит процесс PID: ${pid} (${pid_file})"
    fi
    rm -f "${pid_file}"
  done

  # Убить по паттернам
  pkill -f chaos_writer.sh 2>/dev/null || true
  pkill -f chaos_zombie.py 2>/dev/null || true
  pkill -f chaos_fd_leak.py 2>/dev/null || true
  pkill -f chaos_low_limit.sh 2>/dev/null || true
  pkill -f "stress" 2>/dev/null || true
  pkill -f "stress-ng" 2>/dev/null || true
  # Убить CPU нагрузку
  while IFS= read -r pid; do
    kill "${pid}" 2>/dev/null || true
  done < "${CHAOS_DIR}/cpu_pids" 2>/dev/null || true

  sleep 1

  # Удалить chaos файлы
  warn "Удаляем chaos файлы..."
  rm -f /tmp/chaos_bigfile
  rm -rf /tmp/chaos_inodes/
  rm -f /tmp/chaos_fd_*
  rm -f /tmp/chaos_*.sh /tmp/chaos_*.py
  rm -f /tmp/swapfile 2>/dev/null || true
  ok "Временные файлы удалены"

  # Восстановить /etc/resolv.conf
  if [[ -f "${BACKUP_DIR}/resolv.conf.bak" ]]; then
    cp "${BACKUP_DIR}/resolv.conf.bak" /etc/resolv.conf
    ok "resolv.conf восстановлен"
  fi

  # Восстановить /etc/nsswitch.conf
  if [[ -f "${BACKUP_DIR}/nsswitch.conf.bak" ]]; then
    cp "${BACKUP_DIR}/nsswitch.conf.bak" /etc/nsswitch.conf
    ok "nsswitch.conf восстановлён"
  fi

  # Восстановить маршруты
  if [[ -f "${BACKUP_DIR}/default_route.bak" ]]; then
    local gw dev
    read -r gw dev < "${BACKUP_DIR}/default_route.bak"
    ip route add default via "${gw}" dev "${dev}" 2>/dev/null || true
    ok "Дефолтный маршрут восстановлён"
  fi

  # Восстановить iptables
  if [[ -f "${BACKUP_DIR}/iptables.bak" ]]; then
    iptables-restore < "${BACKUP_DIR}/iptables.bak" 2>/dev/null || true
    ok "iptables восстановлен"
  fi

  # Восстановить sysctl
  if [[ -f "${BACKUP_DIR}/sysctl.bak" ]]; then
    # Восстановить key параметры
    sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
    sysctl -w net.core.somaxconn=128 2>/dev/null || true
    sysctl -w vm.swappiness=60 2>/dev/null || true
    sysctl -w net.ipv4.ip_local_port_range="32768 60999" 2>/dev/null || true
    sysctl -w fs.file-max=1048576 2>/dev/null || true
    ok "sysctl параметры восстановлены"
  fi

  # Удалить chaos ulimits
  rm -f /etc/security/limits.d/chaos.conf
  ok "Лимиты восстановлены"

  # Отключить swap файл если создавали
  if [[ -f "${CHAOS_DIR}/created_swap" ]]; then
    swapoff /tmp/swapfile 2>/dev/null || true
    rm -f /tmp/swapfile
    ok "Swap файл удалён"
  fi

  # Очистить состояние
  echo '{"active": []}' > "${STATE_FILE}"

  echo ""
  echo -e "${GREEN}${BOLD}═══════════════════════════════════════${RESET}"
  echo -e "${GREEN}${BOLD}  ✅ Система восстановлена!${RESET}"
  echo -e "${GREEN}${BOLD}═══════════════════════════════════════${RESET}"
  echo ""

  log "Текущее состояние:"
  df -h / | tee -a "${LOG_FILE}"
  free -h | tee -a "${LOG_FILE}"
  echo ""
  log "Для проверки DNS:"
  nslookup google.com 2>/dev/null | head -5 | tee -a "${LOG_FILE}" || echo "DNS проверка..."
}

# ─── CHECK ───────────────────────────────────────────────────────────────────
check_chaos() {
  section "🔍 ДИАГНОСТИКА ТЕКУЩЕГО ХАОСА"

  echo -e "${BOLD}Активные хаосы:${RESET}"
  if [[ -f "${STATE_FILE}" ]] && command -v python3 &>/dev/null; then
    python3 -c "
import json
with open('${STATE_FILE}') as f:
    state = json.load(f)
if state['active']:
    for c in state['active']:
        print(f'  ⚡ [{c[\"name\"]}] {c[\"desc\"]} ({c[\"time\"]})')
else:
    print('  (нет активных хаосов)')
" 2>/dev/null || cat "${STATE_FILE}"
  fi

  echo ""
  echo -e "${BOLD}Состояние системы:${RESET}"
  echo -e "\n${CYAN}--- Диск ---${RESET}"
  df -h
  echo -e "\n${CYAN}--- inode ---${RESET}"
  df -i
  echo -e "\n${CYAN}--- Память ---${RESET}"
  free -h
  echo -e "\n${CYAN}--- Load Average ---${RESET}"
  cat /proc/loadavg
  echo -e "\n${CYAN}--- Zombie процессы ---${RESET}"
  ps aux | awk '$8=="Z" {print "  ZOMBIE: PID="$2" CMD="$11}' || echo "  (нет)"
  echo -e "\n${CYAN}--- DNS ---${RESET}"
  nslookup google.com 2>&1 | head -5 || echo "  DNS не работает"
  echo -e "\n${CYAN}--- Маршруты ---${RESET}"
  ip route show
  echo -e "\n${CYAN}--- sysctl (ключевые) ---${RESET}"
  echo "  somaxconn: $(sysctl -n net.core.somaxconn 2>/dev/null)"
  echo "  ip_forward: $(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
  echo "  swappiness: $(sysctl -n vm.swappiness 2>/dev/null)"
  echo "  file-max: $(sysctl -n fs.file-max 2>/dev/null)"
}

# ─── RANDOM MODE ─────────────────────────────────────────────────────────────
chaos_random() {
  section "🎰 RANDOM CHAOS MODE"
  warn "Выбираем случайную комбинацию 2-3 хаосов..."

  local all_chaos=(
    "chaos_disk_fill_tmp"
    "chaos_disk_inode_exhaust"
    "chaos_disk_deleted_fd"
    "chaos_network_dns"
    "chaos_network_route"
    "chaos_process_zombie"
    "chaos_process_highload"
    "chaos_process_fd_leak"
    "chaos_memory_pressure"
    "chaos_kernel_sysctl"
  )

  local count=$(( RANDOM % 2 + 2 ))  # 2 или 3
  local selected=()

  while [[ ${#selected[@]} -lt ${count} ]]; do
    local idx=$(( RANDOM % ${#all_chaos[@]} ))
    local chaos="${all_chaos[$idx]}"

    # Не дублировать
    local dup=false
    for s in "${selected[@]:-}"; do
      [[ "$s" == "$chaos" ]] && dup=true && break
    done

    [[ "$dup" == "false" ]] && selected+=("$chaos")
  done

  echo -e "${BOLD}Выбранные хаосы (${count} штуки):${RESET}"
  for c in "${selected[@]}"; do
    echo "  🔥 ${c}"
  done
  echo ""

  echo -e "${RED}${BOLD}Таймер: У тебя 30 минут чтобы найти и починить всё!${RESET}"
  echo ""

  # Запустить выбранные хаосы
  for c in "${selected[@]}"; do
    ${c} || warn "Хаос ${c} не удался, продолжаем..."
    sleep 1
  done

  echo ""
  echo -e "${BOLD}${RED}═══════════════════════════════════════${RESET}"
  echo -e "${BOLD}${RED}  ⏱  СТАРТ! У тебя 30 минут!${RESET}"
  echo -e "${BOLD}${RED}  Запусти: asciinema rec chaos_$(date +%Y%m%d_%H%M%S).cast${RESET}"
  echo -e "${BOLD}${RED}═══════════════════════════════════════${RESET}"
  echo ""
  echo -e "Подсказки когда нашёл — не раньше:"
  echo "  ./linux-chaos.sh --check    # что именно сломано"
  echo "  ./linux-chaos.sh --restore  # восстановить после"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════
main() {
  # Проверить root
  if [[ "${EUID}" -ne 0 ]]; then
    err "Запускай от root: sudo $0 $*"
    exit 1
  fi

  init_chaos

  local mode="${1:-}"
  local submode="${2:-}"

  echo ""
  echo -e "${BOLD}${PURPLE}"
  echo "  ██████╗██╗  ██╗ █████╗  ██████╗ ███████╗"
  echo "  ██╔════╝██║  ██║██╔══██╗██╔═══██╗██╔════╝"
  echo "  ██║     ███████║███████║██║   ██║███████╗"
  echo "  ██║     ██╔══██║██╔══██║██║   ██║╚════██║"
  echo "  ╚██████╗██║  ██║██║  ██║╚██████╔╝███████║"
  echo "   ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝"
  echo -e "${RESET}"
  echo -e "${BOLD}  Linux Chaos Engineering Lab${RESET}"
  echo -e "  ${YELLOW}ВНИМАНИЕ: Только для виртуальных машин!${RESET}"
  echo ""

  case "${mode}" in
    --mode)
      case "${submode:-}" in
        disk)        chaos_disk_fill_tmp; chaos_disk_deleted_fd ;;
        disk-inode)  chaos_disk_inode_exhaust ;;
        network)     chaos_network_dns ;;
        network-route) chaos_network_route ;;
        network-iptables) chaos_network_iptables ;;
        process)     chaos_process_zombie; chaos_process_fd_leak ;;
        process-cpu) chaos_process_highload ;;
        memory)      chaos_memory_pressure ;;
        kernel)      chaos_kernel_sysctl ;;
        kernel-ulimit) chaos_kernel_ulimit ;;
        random)      chaos_random ;;
        *)
          err "Неизвестный режим: ${submode}"
          echo "Доступные: disk, disk-inode, network, network-route, process, process-cpu, memory, kernel, kernel-ulimit, random"
          exit 1
          ;;
      esac
      ;;
    --restore) restore_all ;;
    --check)   check_chaos ;;
    --random | random)  chaos_random ;;
    *)
      echo -e "${BOLD}Использование:${RESET}"
      echo "  sudo $0 --mode disk           # Заполнить диск + zombie-файл"
      echo "  sudo $0 --mode disk-inode     # Исчерпать inode"
      echo "  sudo $0 --mode network        # Сломать DNS"
      echo "  sudo $0 --mode network-route  # Удалить дефолтный маршрут"
      echo "  sudo $0 --mode network-iptables # Заблокировать порт 80"
      echo "  sudo $0 --mode process        # Zombie + FD leak"
      echo "  sudo $0 --mode process-cpu    # Высокая нагрузка CPU"
      echo "  sudo $0 --mode memory         # Memory pressure"
      echo "  sudo $0 --mode kernel         # Сломать sysctl"
      echo "  sudo $0 --mode kernel-ulimit  # Сломать ulimits"
      echo "  sudo $0 --mode random         # Случайная комбинация (боевой режим!)"
      echo ""
      echo "  sudo $0 --check               # Что сейчас сломано"
      echo "  sudo $0 --restore             # Восстановить всё"
      echo ""
      echo -e "${YELLOW}Совет: начни с --mode random и запиши через asciinema!${RESET}"
      exit 0
      ;;
  esac
}

main "$@"
