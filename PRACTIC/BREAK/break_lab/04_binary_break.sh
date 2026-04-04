#!/usr/bin/env bash
# Создаёт несколько «незапускаемых» исполняемых файлов для разбора file/chmod/ldd/strace.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
require_linux

banner "04: Незапускаемый бинарник"

LAB="/opt/break_lab"
mkdir -p "$LAB"

# 1) Нет бита исполнения
cp /bin/date "$LAB/mystery_no_exec"
chmod 644 "$LAB/mystery_no_exec"

# 2) Неверный shebang
cat > "$LAB/mystery_bad_interpreter" <<'EOF'
#!/bin/no_such_interpreter_break_lab
echo never
EOF
chmod +x "$LAB/mystery_bad_interpreter"

# 3) Усечённый ELF (SIG или ошибка формата)
head -c 256 /bin/ls > "$LAB/mystery_truncated_elf"
chmod +x "$LAB/mystery_truncated_elf"

# 4) Динамический бинарник с заведомо битым interpreter (если есть patchelf)
if command -v gcc >/dev/null 2>&1; then
  tmpc="$(mktemp /tmp/breakXXXX.c)"
  echo 'int main(void){return 0;}' > "$tmpc"
  if gcc -x c "$tmpc" -o "$LAB/mystery_dyn" 2>/dev/null && command -v patchelf >/dev/null 2>&1; then
    patchelf --set-interpreter /lib/THIS_INTERPRETER_DOES_NOT_EXIST "$LAB/mystery_dyn" || true
  else
    rm -f "$LAB/mystery_dyn"
  fi
  rm -f "$tmpc"
fi

# 5) Текст под видом бинарника
echo 'echo hello' > "$LAB/not_a_binary"
chmod +x "$LAB/not_a_binary"

banner "Файлы в $LAB"
ls -la "$LAB"
echo ""
echo "Разбирайте: file, chmod, ldd, strace -f ./имя , objdump/readelf (при необходимости apt install)."
echo "Удаление каталога: rm -rf $LAB"
