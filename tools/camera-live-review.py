#!/usr/bin/env python3
"""Check real camera frames through the installed app, without taking focus.

The token-protected diagnostic never decodes QR or imports credentials. It opens
one passive window on the built-in display and closes it automatically. Unlike
normal camera use, this explicit review saves a screenshot in ignored .local/.
Use --request-permission only when the user agrees to a native permission dialog.
"""
import argparse
import json
from pathlib import Path
import subprocess
import time
import urllib.parse

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--camera', default='FaceTime', help='Substring of the camera name')
    parser.add_argument('--request-permission', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / '.local/camera-live-review')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    report = Path.home() / 'Library/Logs/ocmac/camera-check.json'
    ready, done = Path(str(report) + '.ready'), Path(str(report) + '.done')
    for path in (report, ready, done):
        path.unlink(missing_ok=True)
    token = (Path.home() / 'Library/Application Support/ocmac/notify.token').read_text().strip()
    query = {'token': token, 'camera': args.camera}
    if args.request_permission:
        query['request'] = '1'
    subprocess.run(['open', '-g', '-a', str(Path.home() / 'Applications/OpenConnect for Mac.app'),
                    'ocmac://debug-camera?' + urllib.parse.urlencode(query)], check=True)
    deadline = time.monotonic() + (95 if args.request_permission else 40)
    while time.monotonic() < deadline and not report.exists():
        if ready.exists() and not done.exists():
            window = json.loads(ready.read_text())['windowID']
            time.sleep(1)
            subprocess.run(['/usr/sbin/screencapture', '-x', '-o', '-l', str(window),
                            str(args.output / 'preview.png')], check=True, timeout=10)
            done.write_text('ok')
        time.sleep(.1)
    if not report.exists():
        raise RuntimeError('Camera check did not produce a report')
    data = json.loads(report.read_text())
    (args.output / 'report.json').write_text(json.dumps(data, indent=2))
    print(json.dumps(data, indent=2))
    assert data.get('authorized'), 'Camera permission is required'
    assert data.get('frames', 0) >= 8 and data.get('standardDeviation', 0) > 2, 'No usable camera frames'
    assert data.get('focusPreserved'), 'Foreground changed during the check'
    print('Inspect preview.png as well: frame arrival alone does not prove visible preview.')


if __name__ == '__main__':
    main()
