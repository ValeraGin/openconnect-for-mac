#!/bin/bash
# Анимация настоящего окна соединения на демо-данных, без запуска окон.
# Сначала tools/screenshots.sh: версия и хеши исходных кадров проверяются.
# Смена состояний иллюстративная; это не запись настоящего VPN-подключения.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/app/.build/ocmac.app/Contents/MacOS/ocmac-app"
[ -x "$app" ] || { echo "demo-gif: соберите app/make-app.sh" >&2; exit 1; }
python3 "$root/tools/screenshots.py" --verify-only
command -v ffmpeg >/dev/null && command -v magick >/dev/null \
    || { echo "demo-gif: нужны ffmpeg и magick (brew install ffmpeg imagemagick)" >&2; exit 1; }
# Сценарий: кадр и сколько секунд он на экране.
frames=(connection-idle:1.4 connection-connecting:1.0 connection:2.8 connection-paused:2.2 connection:1.8)
bg="#EEF0EA"   # фон сайта, чтобы анимация не выглядела вырезанной
tmp=$(mktemp -d /private/tmp/ocmac-demo.XXXXXX)
trap 'rm -rf "$tmp"' EXIT
for lang in en ru; do
    out="$root/assets/demo.gif"; [ "$lang" = ru ] && out="$root/assets/ru/demo.gif"
    dir="$tmp/$lang"; mkdir -p "$dir"
    source_dir="$root/assets"; [ "$lang" = ru ] && source_dir="$root/assets/ru"
    for item in "${frames[@]}"; do cp "$source_dir/${item%%:*}.png" "$dir/${item%%:*}.png"; done
    # Общий холст удерживает окно на одном месте при смене состояния.
    w=0; h=0
    for item in "${frames[@]}"; do
        read -r fw fh < <(magick identify -format '%w %h\n' "$dir/${item%%:*}.png")
        if (( fw > w )); then w=$fw; fi
        if (( fh > h )); then h=$fh; fi
    done
    list="$dir/list.txt"; : > "$list"
    for item in "${frames[@]}"; do
        name=${item%%:*}
        # Ширина совпадает с колонкой иллюстрации на сайте.
        scale="373x"
        # Прозрачные углы окна — в фон: иначе кадры GIF накладываются друг на друга.
        # PNG24: почти серый кадр magick пишет серым PNG, и concat его теряет.
        magick "$dir/$name.png" -background "$bg" -alpha remove -alpha off -gravity north -extent "${w}x${h}" \
            -bordercolor "$bg" -border 32 -resize "$scale" PNG24:"$dir/$name.final.png"
        printf "file '%s'\nduration %s\n" "$dir/$name.final.png" "${item##*:}" >> "$list"
    done
    # concat берёт длительность последнего кадра, только если он повторён.
    last=${frames[${#frames[@]}-1]}
    printf "file '%s'\n" "$dir/${last%%:*}.final.png" >> "$list"
    ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" \
        -vf "split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none" \
        -loop 0 "$out"
    echo "demo-gif: $lang → ${out#"$root"/} ($(du -h "$out" | cut -f1 | tr -d ' '))"
done
