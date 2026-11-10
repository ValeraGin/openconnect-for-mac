#!/bin/bash
# Настоящие окна на встроенном экране, без активации и чтения личных профилей.
# Контролы неактивны; подтверждение версии и способа съёмки — assets/captures.json.
# --windows остаётся совместимым именем: меню с перехватом ввода больше не открывается.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = --windows ]; then shift; fi
exec python3 "$root/tools/screenshots.py" "$@"
