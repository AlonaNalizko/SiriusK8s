#!/usr/bin/env bash
# Заполняет root большим файлом; опционально «удалённый, но открытый» файл.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
require_linux

banner "03: Освободить диск (без перезагрузки)"

LIB_DIR="/var/lib/linux_break_lab"
mkdir -p "$LIB_DIR"
FILL="${DISK_BREAK_FILE:-${LIB_DIR}/disk_fill.bin}"
ORPHAN_MB="${ORPHAN_MB:-512}"
TARGET_GB="${DISK_FILL_GB:-6}"

avail_bytes=$(df -B1 / | awk 'NR==2 {print $4}')
sixgb=$((TARGET_GB * 1024 * 1024 * 1024))
margin=$((512 * 1024 * 1024))

if (( avail_bytes > sixgb + margin )); then
  fill_bytes=$sixgb
else
  fill_bytes=$(( avail_bytes * 75 / 100 ))
  echo "Меньше ${TARGET_GB}GiB свободно — заполняю ~75% оставшегося: $(( fill_bytes / 1024 / 1024 )) MiB" >&2
fi

echo "Создаю файл ${FILL} размером $(( fill_bytes / 1024 / 1024 )) MiB …"
fallocate -l "$fill_bytes" "$FILL"

# Держатель удалённого файла (inode занят процессом)
HOLDER="${LIB_DIR}/orphan_holder.sh"
cat > "$HOLDER" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
BLOB="/var/lib/linux_break_lab/orphan_blob"
rm -f "$BLOB"
exec 3>"$BLOB"
MB="${1:-512}"
dd if=/dev/zero of=/proc/self/fd/3 bs=1M count="$MB" status=none
rm -f "$BLOB"
exec -a break_lab_orphan_holder sleep infinity
EOS
chmod +x "$HOLDER"
nohup "$HOLDER" "$ORPHAN_MB" >/dev/null 2>&1 &
echo $! > "${LIB_DIR}/orphan_holder.pid"
sleep 0.5

banner "Готово"
echo "Заполнитель:     $FILL"
echo "Фон (deleted):   PID $(cat "${LIB_DIR}/orphan_holder.pid"), имя процесса break_lab_orphan_holder"
echo "Подсказки: du, df, lsof | grep deleted, kill, tune2fs -m (осторожно с reserve)"
echo "Убить держатель: kill \$(cat ${LIB_DIR}/orphan_holder.pid)"
