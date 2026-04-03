#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
require_linux

systemctl stop script-server.service 2>/dev/null || true
systemctl disable script-server.service 2>/dev/null || true
rm -f /etc/systemd/system/script-server.service
systemctl daemon-reload
systemctl reset-failed script-server.service 2>/dev/null || true

echo "Unit script-server удалён. Файлы в /opt/break_lab/ не трогались (удалите вручную при необходимости)."
