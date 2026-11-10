#!/bin/bash
# Карточки для ссылок: website/dist/assets/social-card-{en,ru}.{png,jpg} и
# social-card.{png,jpg} (английская — ей же пользуется GitHub social preview).
# Справа — свежий снимок окна соединения. Окон и меню скрипт не открывает.
# Сначала tools/screenshots.sh; версия и хеши кадров проверяются перед отрисовкой.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/app/.build/ocmac.app/Contents/MacOS/ocmac-app"
[ -x "$app" ] || { echo "social-card: соберите app/make-app.sh" >&2; exit 1; }
python3 "$root/tools/screenshots.py" --verify-only
assets="$root/website/dist/assets"
cd "$root"
for lang in en ru; do
    source_dir="$root/assets"; [ "$lang" = ru ] && source_dir="$root/assets/ru"
    swift tools/make-social-card.swift "$lang" "$source_dir/connection.png" "$assets/social-card-$lang"
done
cp "$assets/social-card-en.png" "$assets/social-card.png"
cp "$assets/social-card-en.jpg" "$assets/social-card.jpg"
echo "social-card: $(du -h "$assets"/social-card-*.jpg | awk '{print $2 " " $1}' | xargs)"
