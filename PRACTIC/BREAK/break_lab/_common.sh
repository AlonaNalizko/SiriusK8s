#!/usr/bin/env bash
# shellcheck source=break_lab/_common.sh
set -euo pipefail

LIB_DIR="/var/lib/linux_break_lab"
BACKUP_NET="${LIB_DIR}/network_backup"
BACKUP_SESSION="$(date +%Y%m%d_%H%M%S)"

require_root() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "Запустите от root: sudo $0" >&2
    exit 1
  fi
}

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Скрипты рассчитаны только на Linux." >&2
    exit 1
  fi
}

banner() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
