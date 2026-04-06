#!/usr/bin/env bash
# Генерирует большой nginx access.log (~1M строк) и опционально JSON-вариант.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
require_linux

banner "01: Nginx access.log — топ-10 IP (задача на awk/sort/uniq)"

NGX_DIR="/var/log/nginx"
ACCESS="${NGX_DIR}/access.log"
JSON_LOG="${NGX_DIR}/access_json.log"
LINES="${NGINX_CHALLENGE_LINES:-1000000}"
JSON_LINES="${NGINX_JSON_LINES:-200000}"

mkdir -p "$NGX_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Нужен python3 для быстрой генерации." >&2
  exit 1
fi

echo "Пишу ${LINES} строк в ${ACCESS} …"
python3 - "$ACCESS" "$LINES" <<'PY'
import random
import sys

path, n = sys.argv[1], int(sys.argv[2])
# пул IP, часть «горячих» для реалистичного топа
hot = [f"10.{random.randint(0,50)}.{random.randint(0,255)}.{random.randint(1,254)}" for _ in range(12)]
pool = hot + [f"192.168.{random.randint(0,255)}.{random.randint(1,254)}" for _ in range(500)]
weights = [hot[i % len(hot)] if random.random() < 0.12 else random.choice(pool) for _ in range(n)]

with open(path, "w", buffering=1024 * 1024) as f:
    for ip in weights:
        f.write(
            f'{ip} - - [29/Mar/2026:12:00:00 +0000] "GET / HTTP/1.1" 200 1234 "-" "-"\n'
        )
print("Готово:", path)
PY

echo "Пишу ${JSON_LINES} строк JSON в ${JSON_LOG} …"
python3 - "$JSON_LOG" "$JSON_LINES" <<'PY'
import json
import random
import sys

path, n = sys.argv[1], int(sys.argv[2])
hot = [f"10.{random.randint(0,50)}.{random.randint(0,255)}.{random.randint(1,254)}" for _ in range(12)]
pool = hot + [f"172.{random.randint(16,31)}.{random.randint(0,255)}.{random.randint(1,254)}" for _ in range(400)]

with open(path, "w", buffering=1024 * 1024) as f:
    for _ in range(n):
        ip = hot[random.randrange(len(hot))] if random.random() < 0.15 else random.choice(pool)
        line = {"remote_addr": ip, "request": "GET / HTTP/1.1", "status": 200, "bytes": 1234}
        f.write(json.dumps(line, ensure_ascii=False) + "\n")
print("Готово:", path)
PY

banner "Задача"
echo "• Классический лог: вывести топ-10 IP по числу запросов (awk/cut/sort/uniq/tail)."
echo "• Дополнительно: то же для ${JSON_LOG} (например jq или python)."
echo "Удалить данные: rm -f ${ACCESS} ${JSON_LOG}"
