#!/usr/bin/env python3
"""Capture real passive windows on the built-in display, with synthetic data."""
import argparse
import ctypes
import hashlib
import html
import json
import re
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / '.local/design-lab/OpenConnect for Mac — Demo.app'


def require_active_display():
    # macOS may leave cached NSScreen objects after locking the session.
    # Ask WindowServer before launching another passive capture window.
    graphics = ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
    graphics.CGGetActiveDisplayList.argtypes = [ctypes.c_uint32, ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
    graphics.CGGetActiveDisplayList.restype = ctypes.c_int32
    count = ctypes.c_uint32()
    status = graphics.CGGetActiveDisplayList(0, None, ctypes.byref(count))
    if status != 0 or count.value == 0:
        raise SystemExit('No active macOS display (locked or asleep). Existing captures are preserved; use --gallery-only or resume with --missing after unlocking.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture-passive', action='store_true', required=True)
    parser.add_argument('--missing', action='store_true', help='Capture only missing or outdated images')
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
            ('totpOffer', 'signin'), ('totpSetup', 'signin'), ('smsCode', 'signin'),
            ('paused', 'connection'), ('connected', 'runtime'), ('paused', 'runtime'),
            ('dnsCustom', 'dns'), ('keepass', 'sources'), ('commandSource', 'sources'),
            ('idle', 'totpOptions'), ('totpQR', 'qrImport'), ('idle', 'rules'), ('rulesLearn', 'learning'),
            ('idle', 'compatibility'), ('idle', 'profiles'), ('importPreview', 'transfer'),
            ('idle', 'filePreview'), ('helperMissing', 'setup'), ('helperMissing', 'connection'), ('idle', 'setup'),
            ('idle', 'notifications'), ('notificationsOff', 'notifications'),
            ('diagnosticsWarning', 'diagnostics'), ('idle', 'diagnostics'), ('idle', 'logs'),
            ('diskConflict', 'connection'), ('about', 'technical'), ('idle', 'report'),
            ('idle', 'login-bottom'), ('idle', 'advanced-bottom'), ('idle', 'general-bottom'),
            ('keepass', 'sources-bottom'), ('dnsCustom', 'dns-bottom'), ('idle', 'rules-bottom'),
            ('totpEight', 'signin'), ('keepassLocked', 'sources'), ('dnsInvalid', 'dns'), ('logsEmpty', 'logs')
        ]:
            cases.append((f'{language}-{scenario}-{page}', language, scenario, page,
                          'dark' if language == 'en' else 'light'))
    cards = []
    for name, language, scenario, page, appearance in cases:
        png = destination / f'{name}.png'
        metadata = png.with_suffix('.json')
        already_current = png.exists() and metadata.exists() and json.loads(metadata.read_text()).get('binarySHA256') == binary_hash
        if not args.gallery_only and (not args.only or name in args.only) and not (args.missing and already_current):
            require_active_display()
            ready = png.with_suffix('.ready.json')
            done = png.with_suffix('.capture-done')
            for path in [ready, done, png, metadata]:
                path.unlink(missing_ok=True)
            target_page = page.removesuffix('-bottom')
            command = ['open', '-g', '-n', '-W', str(APP), '--args', '--capture-passive',
                       '--shot', str(png), '--scenario', scenario, '--page', target_page,
                       '--language', language, '--appearance', appearance,
                       '--screen', 'signin' if page == 'signin' else 'about' if page in ['about', 'licenses', 'technical'] else 'settings']
            if page.endswith('-bottom'):
                command += ['--scroll-bottom']
            if page == 'technical':
                command += ['--technical']
            if page == 'licenses':
                command += ['--licenses']
            if scenario == 'error':
                command += ['--details']
            errors = png.with_suffix('.stderr').open('w')
            process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=errors)
            try:
                deadline = time.monotonic() + 20
                while not ready.exists() and time.monotonic() < deadline and process.poll() is None:
                    time.sleep(0.1)
                if not ready.exists():
                    raise RuntimeError(f'{name}: no passive window handoff')
                window_id = json.loads(ready.read_text())['windowID']
                capture_command = ['/usr/sbin/screencapture', '-x', '-o', '-l', str(window_id), str(png)]
                for attempt in range(3):
                    capture = subprocess.run(capture_command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=8)
                    if capture.returncode == 0:
                        break
                    if process.poll() is not None:
                        break
                    time.sleep(0.5)
                if capture.returncode != 0:
                    raise RuntimeError(f'{name}: window capture failed: {capture.stderr.strip()}')
                done.write_text('ok')
                status = process.wait(timeout=20)
                if status != 0 or not metadata.exists():
                    raise RuntimeError(f'{name}: capture exited {status}; see {png.with_suffix(".stderr")}')
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
                errors.close()
        if png.exists() and metadata.exists():
            report = json.loads(metadata.read_text())
            if report.get('binarySHA256') != binary_hash:
                continue
            cards.append(f'<article id="{name}" data-language="{language}"><h2>{html.escape(name)}</h2><a href="{png.name}"><img src="{png.name}?v={binary_hash[:12]}" loading="lazy"></a></article>')
    coverage = f'<p><b>Снимки текущей сборки: {len(cards)} из {len(cases)}.</b> В галерее только успешно проверенные кадры. Если набор неполный, продолжение съёмки доступно после разблокировки Мака.</p>'
    (destination / 'index.html').write_text('''<!doctype html><html lang="ru"><meta charset="utf-8">
<title>OpenConnect for Mac · Новый дизайн</title><style>
body{font:15px -apple-system,BlinkMacSystemFont,sans-serif;background:#f3f3f5;color:#242428;margin:32px auto;max-width:1440px;padding:0 24px}
h1{font-size:28px}p{line-height:1.6;max-width:900px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(560px,1fr));gap:24px}
article{background:white;border:1px solid #ddd;border-radius:12px;padding:16px}h2{font-size:14px;font-weight:500}img{width:100%;display:block}
</style><h1>OpenConnect for Mac · Демо 0.4</h1>
''' + coverage + '''
<p><a href="../capabilities-v04.html">Сверка возможностей рабочего приложения и демо</a></p>
<p><a href="#ru-idle-connection">Подключение</a> · <a href="#ru-idle-login">Настройки входа</a> ·
<a href="#ru-signInSSO-signin">Вход SSO</a> · <a href="#ru-signInPassword-signin">Пароль</a> ·
<a href="#ru-signInCode-signin">Одноразовый код</a> · <a href="#ru-about-about">О приложении</a></p>
<p>Знак приложения используется и в подключении. Пустое состояние — добавление профиля, без щита.
Добавлены источники секретов, KeePassXC, DNS-зоны, правила и разметка форм, пауза, управление текущими маршрутами,
уведомления, мастер, журналы, диагностика, импорт/экспорт и сведения о компонентах. Действия имитируются в памяти.</p>
<p><a href="#ru-dnsCustom-dns">DNS</a> · <a href="#ru-keepass-sources">KeePassXC</a> ·
<a href="#ru-rulesLearn-learning">Разметка</a> · <a href="#ru-idle-notifications">Уведомления</a> ·
<a href="#ru-diagnosticsWarning-diagnostics">Диагностика</a> · <a href="#ru-idle-logs">Журналы</a></p>
<p><label>Язык: <select id="language"><option value="">RU + EN</option><option value="ru">Русский</option><option value="en">English</option></select></label>
<label> Найти экран: <input id="search" placeholder="dns, sources, setup, paused…"></label></p>
<p>Название необязательно: в списке используется адрес. Своё имя задаётся в разделе «Дополнительно». Поля адреса, пользователя и порта однострочные. Многострочный ввод — для подсетей и правил формы.
Иконки <a href="https://lucide.dev/license">Lucide (ISC / MIT)</a>. Синий акцент для навигации и действий;
зелёный, оранжевый и красный — для состояния соединения.</p>
<p>Отдельное нативное демоприложение, окно 680 × 620. Постоянная навигация слева, профиль сверху, сохранение снизу.
«Дополнительно» — отдельный раздел. При открытии выбирается активный профиль, затем последний выбранный, затем первый доступный.</p>
<p>В нижней панели Demo переключаются 39 сценариев, язык и оформление. Кнопка со стрелкой открывает настройки заново и проверяет выбор профиля.
Вход проверяется от начала до конца: пароль <code>demo</code>, код <code>287082</code>.
Все подключения, пароли и параметры — тестовые. Приложение не обращается к рабочему VPN.</p>
<p>Сняты настоящие окна на встроенном экране без фокуса и перехвата мыши. Нативные контролы неактивны: эти кадры проверяют компоновку, а не активные цвета.</p>
<div class="grid">''' + ''.join(cards) + '''</div><script>
function filterCards(){const lang=document.querySelector('#language').value;const query=document.querySelector('#search').value.toLowerCase();document.querySelectorAll('article').forEach(card=>{card.hidden=Boolean((lang&&card.dataset.language!==lang)||!card.id.toLowerCase().includes(query));});}
document.querySelector('#language').addEventListener('change',filterCards);document.querySelector('#search').addEventListener('input',filterCards);
</script></html>''')
    gallery = (destination / 'index.html').read_text()
    accepted_ids = re.findall(r'<article id="([^"]+)"', gallery)
    def available_anchor(match):
        target = match.group(1)
        if target in accepted_ids:
            return match.group(0)
        alternate = next((name for name in accepted_ids if name.endswith('-' + target.rsplit('-', 1)[-1])), '')
        return f'href="#{alternate}"'
    gallery = re.sub(r'href="#([^"]+)"', available_anchor, gallery)
    (destination / 'index.html').write_text(gallery)
    (destination / 'v04.html').write_text(gallery)


if __name__ == '__main__':
    main()
