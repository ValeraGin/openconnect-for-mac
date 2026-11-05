#!/usr/bin/env python3
"""Synthetic CLI integration: fake tunnel process/state and logging helper. No VPN/sudo."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='ocmac-setup-network-') as folder:
        base = Path(folder)
        config = base / 'config'; state = base / 'state'; user = base / 'user'
        for d in (config / 'profiles', state, user): d.mkdir(parents=True)
        fake = base / 'openconnect'
        source = base / 'fake.c'; source.write_text('#include <unistd.h>\nint main(void) { sleep(300); return 0; }\n')
        subprocess.run(['cc', str(source), '-o', str(fake)], check=True, capture_output=True)
        process = subprocess.Popen([str(fake), '300'])
        try:
            session = f'{process.pid} 123456'
            (state / 'openconnect.pid').write_text(str(process.pid))
            (state / 'openconnect.started').write_text(session)
            (state / 'tunnel.env').write_text('STATE=connected\nTUNDEV=utun999\nCONNECTED=123456\nMODE=split\nIP4=10.9.0.2\nDNS=10.20.0.53 10.20.0.54\nDEF_DOMAIN=corp.example.com\nGW_SPLIT_INC=10.20.0.0/16 192.168.50.0/24\n')
            (user / 'desired').write_text('test')
            profile = config / 'profiles/test.ocmac'
            profile.write_text('[Connection]\nUrl = vpn.example.test\nMode = tunnel\n[Routes]\n10.20.0.0/16\n192.168.50.0/24\n[DNS]\ncorp.example.com = vpn 5353\n')
            digest = hashlib.sha256(profile.read_bytes()).hexdigest()
            log = base / 'helper.log'; helper = base / 'helper'
            helper.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$TEST_LOG"\nif [ "${TEST_SWITCH:-}" = 1 ]; then printf changed > "$OCMAC_STATE_DIR/openconnect.started"; fi\n')
            helper.chmod(0o755)
            env = {k: v for k, v in os.environ.items() if not k.startswith('OCMAC_')}
            env.update(OCMAC_CONFIG_DIR=str(config), OCMAC_USER_STATE=str(user), OCMAC_STATE_DIR=str(state),
                       OCMAC_LOG_DIR=str(base / 'logs'), OCMAC_SELFTEST_HELPER=str(helper), OCMAC_NOTIFY='0',
                       OCMAC_LANG='ru', TEST_LOG=str(log))
            def run(*args, extra=None):
                return subprocess.run([str(ROOT / 'bin/ocmac'), *args], env={**env, **(extra or {})}, capture_output=True, text=True, timeout=30)
            r = run('status', '--json'); assert r.returncode == 0, r.stderr
            status = json.loads(r.stdout)
            assert status['state'] == 'connected', status['state']
            assert status['gateway_routes'] == ['10.20.0.0/16', '192.168.50.0/24']
            assert status['gateway_domain'] == 'corp.example.com' and status['gateway_session'] == session
            assert status['dns'] == ['10.20.0.53', '10.20.0.54']
            assert not log.exists(), 'status must not invoke helper'
            for args in [('other', session, digest), ('test', 'stale', digest), ('test', session, 'wrong')]:
                assert run('setup-apply', *args).returncode != 0
                assert not log.exists(), 'rejected selection must not reach helper'
            r = run('setup-apply', 'test', session, digest); assert r.returncode == 0, r.stderr
            assert log.read_text().splitlines() == ['route-add 10.20.0.0/16', 'route-add 192.168.50.0/24', 'zone-add corp.example.com vpn 5353']
            log.unlink()
            (user / 'routes.disabled').write_text('192.168.50.0/24\n')
            (user / 'zones.disabled').write_text('corp.example.com\n')
            assert run('setup-apply', 'test', session, digest).returncode == 0
            assert log.read_text().splitlines() == ['route-add 10.20.0.0/16']
            log.unlink()
            (user / 'routes.disabled').unlink(); (user / 'zones.disabled').unlink()
            assert run('setup-apply', 'test', session, digest, extra={'TEST_SWITCH': '1'}).returncode != 0
            assert log.read_text().splitlines() == ['route-add 10.20.0.0/16'], 'stop after session switch'
            (state / 'openconnect.started').write_text(session); (state / 'paused').touch(); log.unlink()
            assert run('setup-apply', 'test', session, digest).returncode != 0 and not log.exists()
            print('PASS: gateway fields reach JSON; no implicit apply; stale session/profile/digest rejected; selected config applied; disabled entries preserved; mid-apply session switch stops; pause rejected')
        finally:
            process.terminate(); process.wait(timeout=5)


if __name__ == '__main__': main()
