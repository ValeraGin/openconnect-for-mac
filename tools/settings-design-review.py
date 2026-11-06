#!/usr/bin/env python3
"""Review production settings on synthetic data, built-in display, without focus."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import runpy
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'app/.build/ocmac.app'
OUT = ROOT / '.local/settings-design-review'
PAGES = ['connection', 'login', 'network', 'advanced', 'general', 'notifications', 'diagnostics', 'logs', 'about']
DETAILS = ['sources', 'rules', 'totp', 'routes', 'dns', 'identity', 'compatibility', 'csd', 'health', 'file']


def cases():
    result = []
    for lang in ['ru', 'en']:
        theme = 'light' if lang == 'ru' else 'dark'
        for page in PAGES:
            result.append((f'{lang}-{page}', lang, theme, page, '', 'normal', []))
        for detail in DETAILS:
            result.append((f'{lang}-detail-{detail}', lang, theme, 'advanced', detail, 'normal', []))
        for variant in ['empty', 'many', 'long', 'invalid']:
            result.append((f'{lang}-{variant}', lang, theme, 'connection', '', variant, []))
        for state in ['connected', 'paused', 'starting', 'needsLogin', 'lost']:
            result.append((f'{lang}-{state}', lang, theme, 'connection', '', 'normal', ['--state', state]))
        for page, detail, variant, extra in [
            ('connection', '', 'normal', ['--helper-missing']),
            ('network', '', 'proxy', []), ('login', 'sources', 'keepass', []),
            ('login', 'sources', 'command', []), ('network', 'routes', 'large', []),
            ('network', 'dns', 'large', []), ('logs', '', 'normal', ['--empty-logs']),
            ('diagnostics', '', 'normal', ['--diagnostic-error'])]:
            suffix = extra[0][2:] if extra else variant
            result.append((f'{lang}-{page}-{detail or "page"}-{suffix}', lang, theme, page, detail, variant, extra))
        for detail in ['routes', 'dns']:
            result.append((f'{lang}-{detail}-bottom', lang, theme, 'network', detail, 'large', ['--capture-scroll-bottom']))
        for page in ['connection', 'login', 'network', 'about']:
            result.append((f'{lang}-{page}-other-theme', lang, 'dark' if theme == 'light' else 'light', page, '', 'normal', []))
    return result


def fixture(path, variant):
    profiles = path / 'config/profiles'; profiles.mkdir(parents=True, exist_ok=True)
    for directory in ['logs', 'root', 'state']: (path / directory).mkdir(exist_ok=True)
    if variant == 'empty': return
    name = 'Demonstration VPN profile with a very long optional display name' if variant == 'long' else 'Example VPN'
    url = 'vpn-europe-production-gateway.example.com/employees/engineering/backup' if variant == 'long' else 'vpn.example.com/employees'
    if variant == 'invalid': url = 'invalid address'
    connection = f'[Connection]\nName = {name}\nUrl = {url}\nUser = alice@example.com\n'
    if variant == 'proxy': connection += 'Mode = proxy\n[Proxy]\nPort = 11080\nSystemProxy = on\n'
    auth = '[Auth]\nPassword = keychain\nTotp = keychain\nKeychainService = ru.ocmac.design-review\n'
    if variant == 'keepass': auth = '[Auth]\nPassword = keepassxc\nTotp = keepassxc\nKeePassEntry = Work/VPN\nKeePassDb = ~/Demo/Passwords.kdbx\n'
    if variant == 'command': auth = '[Auth]\nPassword = command\nPasswordCommand = printf demo\nTotp = command\nTotpCommand = printf 123456\n'
    count = 25 if variant == 'large' else 2
    routes = '[Routes]\n' + ''.join(f'10.{i}.0.0/16\n' for i in range(count))
    dns = '[DNS]\n' + ''.join(f'zone-{i}.example.com = vpn\n' for i in range(count))
    for i in range(20 if variant == 'many' else 1):
        (profiles / ('main.ocmac' if i == 0 else f'profile-{i:02d}.ocmac')).write_text(connection + auth + routes + dns)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', action='append')
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--gallery-only', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256((APP / 'Contents/MacOS/ocmac-app').read_bytes()).hexdigest()
    require_display = runpy.run_path(str(ROOT / 'design-lab/review.py'))['require_active_display']
    for name, lang, theme, page, detail, variant, extra in cases():
        if args.gallery_only or (args.only and name not in args.only): continue
        png = OUT / f'{name}.png'; meta = png.with_suffix('.json')
        if args.resume and png.exists() and meta.exists() and json.loads(meta.read_text()).get('binarySHA256') == digest: continue
        require_display()
        data = OUT / 'fixtures' / name; fixture(data, variant)
        ready = png.with_suffix('.ready.json'); done = png.with_suffix('.capture-done')
        for item in [png, meta, ready, done]: item.unlink(missing_ok=True)
        command = ['open', '-g', '-n', '-W']
        for key, directory in [('OCMAC_CONFIG_DIR', 'config'), ('OCMAC_STATE_DIR', 'root'), ('OCMAC_USER_STATE', 'state'), ('OCMAC_LOG_DIR', 'logs')]:
            command += ['--env', f'{key}={data / directory}']
        command += [str(APP), '--args', '--stage', '--capture-passive', '--screenshot', 'settings', '--settings-page', page,
                    '--shot', str(png), f'--{theme}', '-InterfaceLanguage', lang, '-AppleLanguages', f'({lang})']
        if detail: command += ['--settings-detail', detail]
        command += extra
        with png.with_suffix('.stderr').open('w') as log:
            process = subprocess.Popen(command, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 25
                while not ready.exists() and time.monotonic() < deadline and process.poll() is None: time.sleep(0.1)
                if not ready.exists(): raise RuntimeError(f'{name}: no passive window handoff')
                window = json.loads(ready.read_text())['windowID']
                subprocess.run(['/usr/sbin/screencapture', '-x', '-o', '-l', str(window), str(png)], check=True, timeout=10)
                done.write_text('ok')
                if process.wait(timeout=20) != 0 or not meta.exists(): raise RuntimeError(f'{name}: capture verification failed')
                report = json.loads(meta.read_text())
                assert report['focusPreserved'] and report['builtInDisplay'] and not report['active']
                report.update(binarySHA256=digest, page=page, detail=detail, variant=variant, language=lang)
                meta.write_text(json.dumps(report, indent=2))
                print(name, 'OK', flush=True)
            finally:
                if process.poll() is None:
                    done.write_text('failed')
                    try: process.wait(timeout=20)
                    except subprocess.TimeoutExpired: process.terminate()
    cards = []; accepted = 0
    for name, *_ in cases():
        png = OUT / f'{name}.png'; meta = png.with_suffix('.json')
        valid = png.exists() and meta.exists() and json.loads(meta.read_text()).get('binarySHA256') == digest
        accepted += int(valid)
        cards.append(f'<article id="{name}"><h2>{html.escape(name)}</h2>' + (f'<a href="{name}.png"><img loading="lazy" src="{name}.png"></a>' if valid else '<p>Не снято для текущей сборки</p>') + '</article>')
    (OUT / 'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Новый интерфейс — ревью</title>
<style>body{font:15px system-ui;background:#17191c;color:#eee;margin:32px}h2{font-size:16px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:24px}article{background:#24272b;padding:16px;border-radius:12px}img{width:100%;height:auto}a{color:#8abaff}</style>
<h1>Новый интерфейс рабочего приложения</h1><p>''' + f'Кадров текущей сборки: {accepted}/{len(cases())}. RU/EN, светлая/тёмная тема, вымышленные данные.' + '''</p><p>Настоящие окна сняты на встроенном экране без фокуса. Контролы неактивны: эти кадры проверяют компоновку, а не активные цвета.</p><main>''' + ''.join(cards) + '</main>')
    print(f'Gallery: {accepted}/{len(cases())}: {OUT / "index.html"}')

if __name__ == '__main__': main()
