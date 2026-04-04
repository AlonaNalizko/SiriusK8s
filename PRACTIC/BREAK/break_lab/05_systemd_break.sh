#!/usr/bin/env bash
# Устанавливает падающий unit script-server для journalctl/ systemctl.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
require_linux

banner "05: systemd unit + диагностика"

LAB="/opt/break_lab"
mkdir -p "$LAB"

cat > "$LAB/script_server.sh" <<'EOF'
#!/usr/bin/env bash
# Намеренно падает — для учебной диагностики в journalctl
set -euo pipefail
echo "script-server: старт $(date -Is)" >&2
# раскомментируйте для варианта с OOM вместо немедленного exit:
# python3 -c 'a=[]; [a.append(b" ") for _ in range(10**9)]'
exit 1
EOF
chmod +x "$LAB/script_server.sh"

UNIT="/etc/systemd/system/script-server.service"
cat > "$UNIT" <<EOF
[Unit]
Description=Break Lab Script Server
After=network.target

[Service]
Type=simple
ExecStart=${LAB}/script_server.sh
Restart=always
RestartSec=2
MemoryMax=64M
CPUQuota=30%

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now script-server.service

banner "Готово"
echo "Сервис в restart loop. Смотрите:"
echo "  journalctl -u script-server -b --no-pager"
echo "  systemctl status script-server"
echo "Откат: sudo bash ${SCRIPT_DIR}/99_restore_systemd.sh"
