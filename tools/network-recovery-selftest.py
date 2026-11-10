#!/usr/bin/env python3
"""Synthetic interface switch in the real supervisor loop. No VPN, signals or sudo."""
from pathlib import Path
import os, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='ocmac-network-recovery-') as folder:
        base = Path(folder)
        source = base / 'process.c'
        source.write_text('#include <unistd.h>\nint main(void) { sleep(300); return 0; }\n')
        process_file = base / 'openconnect'
        subprocess.run(['cc', str(source), '-o', str(process_file)], capture_output=True, check=True)
        process = subprocess.Popen([str(process_file)])
        try:
            for policy in ['manual', 'resume']:
                case = base / policy
                for d in ['bin', 'stub', 'config/profiles', 'state', 'root', 'logs']:
                    (case / d).mkdir(parents=True, exist_ok=True)
                (case / 'libexec').symlink_to(ROOT / 'libexec', target_is_directory=True)
                client = case / 'bin/ocmac'
                text = (ROOT / 'bin/ocmac').read_text()
                text = text.replace('PATH="/usr/bin:/bin:/usr/sbin:/sbin"',
                                    f'PATH="{case}/stub:/usr/bin:/bin:/usr/sbin:/sbin"', 1)
                client.write_text(text); client.chmod(0o755)
                counter = case / 'iface-counter'
                scutil = case / 'stub/scutil'
                scutil.write_text(f'''#!/bin/bash
count=$(cat '{counter}' 2>/dev/null || echo 0)
count=$((count+1)); echo "$count" > '{counter}'
if [ "$count" = 1 ]; then echo 'PrimaryInterface : en0'; else echo 'PrimaryInterface : en7'; fi
'''); scutil.chmod(0o755)
                state = case / 'root'
                (state / 'openconnect.pid').write_text(str(process.pid))
                started = subprocess.run(['ps', '-p', str(process.pid), '-o', 'lstart='], capture_output=True, text=True, check=True).stdout.strip()
                (state / 'openconnect.started').write_text(f'{process.pid} {started}\n')
                tunnel = 'STATE=connected\nTUNDEV=utun999\nCONNECTED=123456\nMODE=split\nDNS=\n'
                (state / 'tunnel.env').write_text(tunnel)
                (case / 'state/desired').write_text('test\n')
                (case / 'state/autoconnect').write_text(policy+'\n')
                (case / 'config/profiles/test.ocmac').write_text('[Connection]\nUrl = vpn.example.test/group\n')
                helper = case / 'helper'
                helper.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$OCMAC_STATE_DIR/helper.log"\n')
                helper.chmod(0o755)
                env = {k:v for k,v in os.environ.items() if not k.startswith('OCMAC_')}
                env.update(OCMAC_CONFIG_DIR=str(case/'config'), OCMAC_USER_STATE=str(case/'state'),
                           OCMAC_STATE_DIR=str(state), OCMAC_LOG_DIR=str(case/'logs'),
                           OCMAC_SELFTEST_HELPER=str(helper), OCMAC_NOTIFY='0', OCMAC_LANG='ru',
                           OCMAC_ACCESS_EVERY='999999999999')
                result = subprocess.run([str(client), 'supervise', '--iterations=1'], env=env, capture_output=True, text=True, timeout=25)
                assert result.returncode == 0, result.stderr
                calls = (state/'helper.log').read_text().splitlines()
                assert calls == ['reconnect-now'], (policy, calls)
                assert (state/'tunnel.env').read_text() == tunnel
                assert (case/'state/desired').read_text() == 'test\n'
                assert process.poll() is None
                print(f'PASS: {policy}, en0 -> en7 requests transport recovery; no tunnel-stop/new login; session and intent retained')
        finally:
            process.terminate(); process.wait(timeout=5)


if __name__ == '__main__': main()
