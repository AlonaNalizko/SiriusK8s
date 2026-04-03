#!/usr/bin/env bash
# Ломает default route и DNS (учебная ВМ).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
require_linux

banner "02: Починить сеть (ip, route, resolv.conf, nsswitch.conf)"

mkdir -p "$BACKUP_NET"
cp -a /etc/nsswitch.conf "${BACKUP_NET}/nsswitch.conf"
# Резолв: сохраняем текущее содержимое (разворачиваем symlink)
if [[ -L /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf "${BACKUP_NET}/resolv.conf" 2>/dev/null || cp -a /etc/resolv.conf "${BACKUP_NET}/resolv.conf.link"
else
  cp -a /etc/resolv.conf "${BACKUP_NET}/resolv.conf"
fi
ip route save > "${BACKUP_NET}/routes.tab"

echo "Бэкап: ${BACKUP_NET}/ (nsswitch.conf, resolv.conf, routes.tab)"
echo "Откат: sudo bash ${SCRIPT_DIR}/99_restore_network.sh"

# Неверный резолвер (TEST-NET-3)
cat > /etc/resolv.conf <<'EOF'
# break_lab: неверный DNS
nameserver 203.0.113.254
options timeout:1 attempts:1
EOF

# Только files — без dns вне /etc/hosts
if grep -q '^hosts:' /etc/nsswitch.conf; then
  sed -i.break_lab 's/^hosts:.*/hosts:          files/' /etc/nsswitch.conf
else
  echo "Не найдена строка hosts: в nsswitch.conf — правьте вручную для усложнения." >&2
fi

# Удаляем default route
while ip route del default 2>/dev/null; do :; done

banner "Готово"
echo "Проверка цели (после починки): curl -I --max-time 10 https://www.avito.ru"
echo "Если SSH пропал — консоль ВМ, затем: sudo bash ${SCRIPT_DIR}/99_restore_network.sh"
