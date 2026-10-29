#!/usr/bin/env python3
"""Capture real passive windows on the built-in display, with synthetic data."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / '.local/design-lab/OpenConnect for Mac — Demo.app'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture-passive', action='store_true', required=True)
    parser.add_argument('--only', action='append', help='Case name; repeat to review several')
    parser.add_argument('--gallery-only', action='store_true', help='Rebuild the gallery from existing matching captures')
    args = parser.parse_args()
    destination = ROOT / '.local/design-lab/review'
    destination.mkdir(parents=True, exist_ok=True)
    binary_hash = hashlib.sha256((APP / 'Contents/MacOS/DesignLab').read_bytes()).hexdigest()
    cases = []
    for language in ['ru', 'en']:
        for scenario, page in [
            ('idle', 'connection'), ('connected', 'connection'), ('connecting', 'connection'),
            ('error', 'connection'), ('empty', 'connection'), ('single', 'connection'),
            ('many', 'connection'), ('long', 'connection'), ('missing', 'connection'),
            ('unsaved', 'connection'), ('proxyWarning', 'connection'),
            ('idle', 'login'), ('idle', 'network'), ('proxyWarning', 'network'),
            ('idle', 'advanced'), ('idle', 'general'),
            ('signInSSO', 'signin'), ('signInPassword', 'signin'), ('signInCode', 'signin'),
            ('signInRejected', 'signin'), ('signInExpired', 'signin'), ('signInSuccess', 'signin'),
            ('credentialPassword', 'signin'), ('credentialCode', 'signin'),
            ('about', 'about'), ('about', 'licenses'), ('addressOnly', 'connection'),
            ('totpOffer', 'signin'), ('totpSetup', 'signin'), ('smsCode', 'signin')
        ]:
            cases.append((f'{language}-{scenario}-{page}', language, scenario, page,
                          'dark' if language == 'en' else 'light'))
    cards = []
    for name, language, scenario, page, appearance in cases:
        png = destination / f'{name}.png'
        metadata = png.with_suffix('.json')
        if not args.gallery_only and (not args.only or name in args.only):
            ready = png.with_suffix('.ready.json')
            done = png.with_suffix('.capture-done')
            for path in [ready, done, png, metadata]:
                path.unlink(missing_ok=True)
            command = ['open', '-g', '-n', '-W', str(APP), '--args', '--capture-passive',
                       '--shot', str(png), '--scenario', scenario, '--page', page,
                       '--language', language, '--appearance', appearance,
                       '--screen', 'signin' if page == 'signin' else 'about' if page in ['about', 'licenses'] else 'settings']
            if page == 'licenses':
                command += ['--licenses']
            if scenario == 'error':
                command += ['--details']
            process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                deadline = time.monotonic() + 20
                while not ready.exists() and time.monotonic() < deadline and process.poll() is None:
                    time.sleep(0.1)
                if not ready.exists():
                    raise RuntimeError(f'{name}: no passive window handoff')
                window_id = json.loads(ready.read_text())['windowID']
                subprocess.run(['/usr/sbin/screencapture', '-x', '-o', '-l', str(window_id), str(png)], check=True)
                done.write_text('ok')
                process.wait(timeout=20)
                report = json.loads(metadata.read_text())
                assert report['focusPreserved'] and report['builtInDisplay'] and not report['active']
                report['binarySHA256'] = binary_hash
                metadata.write_text(json.dumps(report, indent=2))
                print(name, 'OK', flush=True)
            finally:
                if process.poll() is None:
                    done.write_text('failed')
                    try:
                        process.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        process.terminate()
        if png.exists() and metadata.exists():
            report = json.loads(metadata.read_text())
            if report.get('binarySHA256') != binary_hash:
                continue
            cards.append(f'<article id="{name}"><h2>{html.escape(name)}</h2><a href="{png.name}"><img src="{png.name}?v={binary_hash[:12]}" loading="lazy"></a></article>')
    (destination / 'index.html').write_text('''<!doctype html><html lang="ru"><meta charset="utf-8">
<title>OpenConnect for Mac · Новый дизайн</title><style>
body{font:15px -apple-system,BlinkMacSystemFont,sans-serif;background:#f3f3f5;color:#242428;margin:32px auto;max-width:1440px;padding:0 24px}
h1{font-size:28px}p{line-height:1.6;max-width:900px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(560px,1fr));gap:24px}
article{background:white;border:1px solid #ddd;border-radius:12px;padding:16px}h2{font-size:14px;font-weight:500}img{width:100%;display:block}
</style><h1>OpenConnect for Mac · Демо 0.3</h1>
<p><a href="../capabilities-v03.html">Сравнение 31 возможности рабочего приложения и демо</a></p>
<p><a href="#ru-idle-connection">Подключение</a> · <a href="#ru-idle-login">Настройки входа</a> ·
<a href="#ru-signInSSO-signin">Вход SSO</a> · <a href="#ru-signInPassword-signin">Пароль</a> ·
<a href="#ru-signInCode-signin">Одноразовый код</a> · <a href="#ru-about-about">О приложении</a></p>
<p>Название необязательно: в списке используется адрес. Своё имя задаётся в разделе «Дополнительно». Поля адреса, пользователя и порта однострочные. Многострочный ввод — только для списка подсетей.
Иконки <a href="https://lucide.dev/license">Lucide (ISC / MIT)</a>. Синий акцент для навигации и действий;
зелёный, оранжевый и красный — для состояния соединения.</p>
<p>Отдельное нативное демоприложение, окно 680 × 620. Постоянная навигация слева, профиль сверху, сохранение снизу.
«Дополнительно» — отдельный раздел. При открытии выбирается активный профиль, затем последний выбранный, затем первый доступный.</p>
<p>В нижней панели Demo переключаются 24 сценария, язык и оформление. Кнопка со стрелкой открывает настройки заново и проверяет выбор профиля.
Вход проверяется от начала до конца: пароль <code>demo</code>, код <code>287082</code>.
Все подключения, пароли и параметры — тестовые. Приложение не обращается к рабочему VPN.</p>
<p>Сняты настоящие окна на встроенном экране без фокуса и перехвата мыши. Нативные контролы неактивны: эти кадры проверяют компоновку, а не активные цвета.</p>
<div class="grid">''' + ''.join(cards) + '</div></html>')
    (destination / 'v03.html').write_text((destination / 'index.html').read_text())


if __name__ == '__main__':
    main()
