#!/usr/bin/env python3
"""Export version-checked passive captures; never activate the app or open a menu."""
import argparse
import datetime
import hashlib
import json
import plistlib
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'app/.build/ocmac.app'
EXPORTS = {
    'profile.png': 'connection',
    'login.png': 'login',
    'network.png': 'network',
    'advanced.png': 'advanced',
    'notifications.png': 'notifications',
    'about.png': 'about',
    'setup.png': 'setup-0-empty',
    'setup-network.png': 'setup-3-dns',
    'connection.png': 'connection-window-connected',
    'connection-idle.png': 'connection-window-down',
    'connection-connecting.png': 'connection-window-starting',
    'connection-paused.png': 'connection-window-paused',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='Private capture directory')
    parser.add_argument('--resume', action='store_true')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--export-only', action='store_true', help='Validate and export existing frames without opening windows')
    mode.add_argument('--verify-only', action='store_true', help='Verify public image hashes and build identity without opening windows')
    args = parser.parse_args()
    version = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
    cli_version = subprocess.check_output([str(ROOT / 'bin/ocmac'), 'version'], text=True).strip()
    if cli_version != f'ocmac {version}':
        raise SystemExit('App and CLI versions differ; rebuild app/make-app.sh first')
    binary_digest = digest(APP / 'Contents/MacOS/ocmac-app')
    plist_digest = digest(APP / 'Contents/Info.plist')
    if args.verify_only:
        manifest = json.loads((ROOT / 'assets/captures.json').read_text())
        expected = {str(Path('assets') / ('ru' if lang == 'ru' else '') / name)
                    for lang in ['en', 'ru'] for name in EXPORTS}
        if (manifest.get('appVersion') != version or manifest.get('binarySHA256') != binary_digest
                or manifest.get('plistSHA256') != plist_digest
                or manifest.get('capture') != 'screencapture-passive-window'
                or manifest.get('appearanceMode') != 'inactive' or manifest.get('syntheticData') is not True
                or {item['path'] for item in manifest['images']} != expected):
            raise SystemExit('Public captures do not match the current build')
        for item in manifest['images']:
            if (digest(ROOT / item['path']) != item['sha256'] or item.get('focusPreserved') is not True
                    or item.get('builtInDisplay') is not True):
                raise SystemExit(f'Public capture proof rejected: {item["path"]}')
        print(f'Verified {len(expected)} public captures for {version}')
        return
    out = (args.output or ROOT / f'.local/release-{version}/screenshots').resolve()
    command = [sys.executable, str(ROOT / 'tools/settings-design-review.py'), '--output', str(out), '--appearance', 'light']
    for lang in ['en', 'ru']:
        for case in EXPORTS.values():
            command += ['--only', f'{lang}-{case}']
    if args.resume:
        command.append('--resume')
    if not args.export_only:
        subprocess.run(command, check=True)
    pending = []
    for lang in ['en', 'ru']:
        directory = ROOT / 'assets' / ('ru' if lang == 'ru' else '')
        for name, case in EXPORTS.items():
            png = out / f'{lang}-{case}.png'
            metadata = json.loads(png.with_suffix('.json').read_text())
            valid = (metadata.get('binarySHA256') == binary_digest and metadata.get('plistSHA256') == plist_digest
                     and metadata.get('appVersion') == version and metadata.get('syntheticData') is True
                     and metadata.get('capture') == 'screencapture-passive-window'
                     and metadata.get('appearanceMode') == 'inactive'
                     and metadata.get('focusPreserved') is True and metadata.get('builtInDisplay') is True
                     and metadata.get('appearance') == 'NSAppearanceNameAqua'
                     and all(metadata.get(k) is False for k in ['active', 'keyWindow', 'mainWindow']))
            if not valid or not png.is_file():
                raise SystemExit(f'Capture proof rejected: {png.name}')
            pending.append((png, directory / name, lang, metadata))
    manifest = dict(appVersion=version, binarySHA256=binary_digest, plistSHA256=plist_digest,
                    exportedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    capture='screencapture-passive-window', appearanceMode='inactive', syntheticData=True, images=[])
    # Validate every frame before replacing any public image.
    for source, target, lang, metadata in pending:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
        manifest['images'].append(dict(path=str(target.relative_to(ROOT)), sha256=digest(target), language=lang,
                                       screen=metadata['screen'], page=metadata['page'],
                                       focusPreserved=True, builtInDisplay=True))
    (ROOT / 'assets/captures.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Exported {len(pending)} verified captures for {version}; inactive controls, no focus changes.')


if __name__ == '__main__':
    main()
