#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
require_linux

BACKUP_NET="/var/lib/linux_break_lab/network_backup"

if [[ ! -f "${BACKUP_NET}/routes.tab" ]]; then
  echo "Нет бэкапа ${BACKUP_NET}/routes.tab — восстановите маршруты вручную (ip route)." >&2
  exit 1
fi

cp -a "${BACKUP_NET}/nsswitch.conf" /etc/nsswitch.conf
if [[ -f "${BACKUP_NET}/resolv.conf" ]]; then
  cp -a "${BACKUP_NET}/resolv.conf" /etc/resolv.conf
elif [[ -f "${BACKUP_NET}/resolv.conf.link" ]]; then
  cp -a "${BACKUP_NET}/resolv.conf.link" /etc/resolv.conf
fi

# На однопользовательской ВМ без хитрых policy routing обычно достаточно restore
if ! ip route restore < "${BACKUP_NET}/routes.tab" 2>/dev/null; then
  echo "ip route restore не удался — добавьте default route вручную из saved файла или консоли." >&2
  echo "Содержимое бэкапа:"
  cat "${BACKUP_NET}/routes.tab" >&2
  exit 1
fi

echo "Сеть восстановлена из ${BACKUP_NET}. Проверка: ip route; ping -c1 8.8.8.8"
