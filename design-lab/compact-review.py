#!/usr/bin/env python3
"""Compare the same compact form using native layout and Settings components."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import subprocess
import time
from review import require_active_display

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / '.local/design-lab/OpenConnect for Mac — Demo.app'
OUT = ROOT / '.local/compact-design-review'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture-passive', action='store_true', required=True)
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--only', action='append', default=[])
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256((APP / 'Contents/MacOS/DesignLab').read_bytes()).hexdigest()
    cases = []
    for lang in ('ru', 'en'):
        for theme in ('light', 'dark'):
            for state in ('empty', 'long', 'invalid'):
                for layout in ('native', 'library'):
                    cases.append((lang, theme, layout, state))
        for state in ('signin', 'server-empty', 'server-dns-only', 'server-no-domain', 'server-existing', 'server-default', 'server-skipped', 'network', 'network-empty', 'network-error', 'full', 'proxy', 'system', 'verify', 'connected', 'routes', 'routes-many', 'routes-error', 'dns', 'dns-many'):
            cases.append((lang, 'light' if lang == 'ru' else 'dark', 'native', state))
    cards = []
    for lang, theme, layout, state in cases:
        name = '-'.join((lang, theme, layout, state))
        png = OUT / (name + '.png'); report = png.with_suffix('.json')
        current = png.exists() and report.exists() and json.loads(report.read_text()).get('binarySHA256') == digest
        if (not args.only or name in args.only) and not (args.resume and current):
            require_active_display()
            ready = png.with_suffix('.ready.json'); done = png.with_suffix('.capture-done')
            for p in (png, report, ready, done): p.unlink(missing_ok=True)
            screen = 'compactEditor' if state.startswith(('routes', 'dns')) else 'compact'
            command = ['open', '-g', '-n', '-W', str(APP), '--args', '--capture-passive', '--shot', str(png),
                       '--screen', screen, '--language', lang, '--appearance', theme, '--layout', layout, '--compact-state', state]
            with png.with_suffix('.stderr').open('w') as error:
                process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=error)
                try:
                    deadline = time.monotonic() + 20
                    while not ready.exists() and process.poll() is None and time.monotonic() < deadline: time.sleep(.1)
                    if not ready.exists(): raise RuntimeError(f'{name}: capture panel not ready')
                    window = json.loads(ready.read_text())['windowID']
                    for attempt in range(3):
                        result = subprocess.run(['screencapture', '-x', '-o', '-l', str(window), str(png)], capture_output=True, timeout=8)
                        if result.returncode == 0 and png.exists(): break
                        time.sleep(.5)
                    else: raise RuntimeError(f'{name}: native capture failed')
                    done.write_text('ok'); process.wait(timeout=20)
                    if process.returncode != 0 or not report.exists(): raise RuntimeError(f'{name}: capture rejected')
                    meta = json.loads(report.read_text())
                    assert meta['focusPreserved'] and meta['builtInDisplay'] and not meta['active'] and not meta['keyWindow']
                    assert meta['layout'] == layout and meta['compactState'] == state
                    meta['binarySHA256'] = digest; report.write_text(json.dumps(meta, indent=2))
                    print(name + ' OK', flush=True)
                finally:
                    if process.poll() is None: process.terminate(); process.wait(timeout=10)
        if png.exists() and report.exists() and json.loads(report.read_text()).get('binarySHA256') == digest:
            cards.append(f'<article id="{name}"><h2>{html.escape(name)}</h2><a href="{name}.png"><img src="{name}.png?v={digest[:10]}" loading="lazy"></a></article>')
    (OUT / 'index.html').write_text('''<!doctype html><html lang="ru"><meta charset="utf-8"><title>Компактный мастер · сравнение</title>
<style>body{font:15px -apple-system,sans-serif;color:#252528;background:#f2f2f4;max-width:1320px;margin:32px auto;padding:0 24px}p{max-width:950px;line-height:1.6}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}article{background:white;border:1px solid #ddd;border-radius:10px;padding:16px}h2{font-size:13px}img{width:100%;display:block}a{color:#0066cc}</style>
<h1>Компактный мастер: SwiftUI + AppKit / Settings 3.0</h1>
<p>Одинаковые поля, данные и размер окна 560 × 420. Сравниваются SwiftUI Grid с AppKit-полями и реальные Settings.Container / Settings.Section версии 3.0.0. Это сравнение компоновки формы; контроллер окна SettingsWindowController здесь не используется.</p>
<p><b>Основные шаги без прокрутки.</b> После входа показываются предложения сервера: подсети и DNS можно выбрать, изменить или пропустить. До подтверждения они не применяются. Подсети и DNS открываются кнопками «Изменить…» в диалоге 520 × 360; прокручивается только список, действия всегда видны. Отмена отбрасывает правки списка.</p>
<p>Кадры настоящих окон на встроенном экране, без перехвата фокуса и мыши. Контролы неактивны: активные цвета и белёсые края требуют отдельной проверки. Подключение, установка и доступ в этом прототипе имитируются.</p>
<p><a href="#ru-light-native-empty">Стандартный вариант</a> · <a href="#ru-light-library-empty">Settings</a> · <a href="#ru-light-native-network">Сеть</a> · <a href="#ru-light-native-dns">DNS</a></p>
''' + f'<p>Кадры текущей сборки: {len(cards)} / {len(cases)}.</p><div class="grid">' + ''.join(cards) + '</div></html>')
    print(f'{len(cards)}/{len(cases)} frames: {OUT / "index.html"}')


if __name__ == '__main__': main()
