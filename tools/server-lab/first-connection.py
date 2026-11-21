#!/usr/bin/env python3
"""First connection of the published package to loopback ocserv on a fresh hosted Mac."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def load(filename):
    spec = importlib.util.spec_from_file_location(filename, Path(__file__).resolve().parents[1] / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


lab = load('ocserv-integration-test.py')
live = load('macos-vpn-test.py')
address = '192.0.2.1'
domain = 'native.lab.test'
zone = Path('/etc/resolver') / domain
keychain = '/Library/Keychains/System.keychain'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, timeout=120, **kwargs)


def status():
    return json.loads(run('ocmac', 'status', '--json', stdout=subprocess.PIPE).stdout)


def verify_resource(phase):
    snapshot = status()
    assert snapshot['state'] == 'connected' and snapshot['tundev'].startswith('utun')
    assert live.route(address)['interface'] == snapshot['tundev']
    assert f'nameserver {address}' in zone.read_text()
    url = f'http://{phase}.{domain}:8080/proof.txt'
    proof = run('/usr/bin/curl', '--noproxy', '*', '--retry', '5', '--retry-all-errors',
                '--retry-delay', '1', '--max-time', '5', '-fsS', url, stdout=subprocess.PIPE)
    assert proof.stdout.strip() == 'ocmac-tunnel-proof'
    print(f'{phase}: resource resolved by macOS and fetched through {snapshot["tundev"]}', flush=True)
    return snapshot['gateway_session']


def verify_ordinary_network(baseline, phase):
    assert live.route('default') == baseline['default']
    assert live.route(address) == baseline[address] and not zone.exists()
    probe = subprocess.run(['/usr/bin/curl', '--noproxy', '*', '--max-time', '4', '-fsS',
                            f'http://{phase}.{domain}:8080/proof.txt'], capture_output=True)
    assert probe.returncode != 0, 'VPN-only resource is still accessible'
    run('/usr/bin/curl', '--noproxy', '*', '--max-time', '15', '-fsS', '-o', '/dev/null',
        'https://valeragin.github.io/openconnect-for-mac/')
    print(f'{phase}: baseline routes restored, private resource unreachable, public site works', flush=True)


def main():
    if os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted' or os.environ.get('RUNNER_OS') != 'macOS':
        raise SystemExit('This test changes trust settings and requires a disposable GitHub-hosted Mac.')
    assert status()['state'] == 'down' and not zone.exists()
    baseline = {host: live.route(host) for host in ('default', address)}
    profile = Path.home() / '.config/ocmac/profiles/release-lab.ocmac'
    assert not profile.exists()
    # Colima shares the runner home with Docker. Keep the certificate and lab files there.
    with tempfile.TemporaryDirectory(dir=Path.home()) as directory:
        tmp = Path(directory)
        ca = tmp / 'ca.pem'
        openssl = subprocess.check_output(['brew', '--prefix', 'openssl@3'], text=True).strip() + '/bin/openssl'
        run(openssl, 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
            '-subj', '/CN=OpenConnect disposable test CA', '-addext', 'basicConstraints=critical,CA:TRUE',
            '-keyout', tmp / 'ca.key', '-out', ca)
        run(openssl, 'req', '-new', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost',
            '-keyout', tmp / 'key.pem', '-out', tmp / 'server.csr')
        extensions = tmp / 'server.ext'
        extensions.write_text('subjectAltName=IP:127.0.0.1,DNS:localhost\nextendedKeyUsage=serverAuth\n')
        run(openssl, 'x509', '-req', '-in', tmp / 'server.csr', '-CA', ca, '-CAkey', tmp / 'ca.key',
            '-CAcreateserial', '-days', '1', '-extfile', extensions, '-out', tmp / 'cert.pem')
        (tmp / 'otp.db').touch()
        run('sudo', 'security', 'add-trusted-cert', '-d', '-r', 'trustRoot', '-k', keychain, ca)
        try:
            run('brew', 'postinstall', 'ca-certificates')
            with lab.server('ocmac-release-lab', tmp, 'password') as (_, port, _):
                source = tmp / profile.name
                source.write_text(f'[Connection]\nUrl = https://127.0.0.1:{port}\nUser = lab-user\n'
                                  f'Auth = password\nDtls = off\n[Routes]\n{address}/32\n[DNS]\n{domain} = vpn\n'
                                  '[Auth]\nPassword = keychain\nKeychainService = ru.ocmac.release-lab\nTotp = off\n')
                run('ocmac', 'profile-check', source)
                run('ocmac', 'import', source)
                run('ocmac', 'secret', 'set-password', 'release-lab', '--stdin', input='lab-password\n')
                run('ocmac', 'autoconnect', 'manual')
                try:
                    run('ocmac', 'connect', 'release-lab')
                    session = verify_resource('first')
                    assert session
                    run('ocmac', 'pause')
                    assert status()['state'] == 'paused'
                    verify_ordinary_network(baseline, 'paused')
                    run('ocmac', 'resume')
                    assert verify_resource('resumed') == session
                    run('ocmac', 'disconnect')
                    verify_ordinary_network(baseline, 'disconnected')
                    run('ocmac', 'connect', 'release-lab')
                    verify_resource('second')
                finally:
                    run('ocmac', 'disconnect')
                time.sleep(6)  # At least one normal supervisor poll after explicit disconnect.
                assert status()['state'] == 'down'
                verify_ordinary_network(baseline, 'final')
        finally:
            run('sudo', 'security', 'remove-trusted-cert', '-d', ca)
            run('brew', 'postinstall', 'ca-certificates')


if __name__ == '__main__':
    main()
