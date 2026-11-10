# Try OpenConnect for Mac on your gateway

A useful report describes one Mac, one gateway and the last step that worked.
Reports of failed installation are as useful as successful connections.
Russian and English are both welcome.

## Before you start

- You need macOS 14.4+ and access to an AnyConnect-compatible VPN gateway.
  The project does not provide VPN servers.
- Confirm that you may use this client with your gateway. If the gateway
  requires HostScan / CSD, obtain an approved wrapper from its administrator.
- Installation builds from source using Apple Command Line Tools and Homebrew.
  The system helper needs administrator access. There is no signed DMG in
  GitHub Releases.
- Prefer a spare Mac or separate macOS account for a first-install check.
  Do not delete existing profiles or credentials to simulate a fresh install.
  A separate account still shares system tools and the privileged helper;
  system installation can interrupt an existing VPN session.

The deployment target is not a compatibility result. Check the current
[compatibility limits](README.md#compatibility-and-limits) before testing.

## Record the build

Use the [installation instructions](README.md#install). Record whether you used
the normal installer, Homebrew, or a source checkout, and whether this was a
first installation or an upgrade. After installation, record:

```bash
ocmac version
sw_vers -productVersion
uname -m
```

For a source build, also record `git rev-parse HEAD` from that checkout.
The default installer uses the release selected by the Homebrew tap.
`--head` selects the public `main` branch; it does not install an author's
unpublished local changes. A version number alone may not identify a source
build because unreleased changes can retain the previous version number.

## First-connection checklist

Record each step as passed, failed or not tried. Stop at a failure and describe
what you saw; do not work around it silently.

| Step | What to check |
| --- | --- |
| Install | The documented command finishes. Record any unexpected prerequisite or administrator prompt. |
| Find the app | OpenConnect for Mac is discoverable and its menu opens. A separate Demo app is not the VPN client. |
| Create or import a profile | Start with your own gateway address or an approved teammate profile. Do not reuse the sender's login. Record which path you chose. |
| Prepare the system | The app can find the client and helper. If CSD is required, use the approved wrapper and complete the indicated preparation. |
| Sign in | Complete the gateway's actual sign-in. Check paste in password fields. Record the identity provider product, never its hostname or your credentials. |
| Choose credential storage | Record whether you chose manual entry or storage. On a second sign-in, check that the selected behavior was preserved. Do not include secret values. |
| Reach a resource | Open a resource you are allowed to access, by its normal hostname. A connected status alone is not proof that routes and DNS work. |
| Check the network policy | Verify the routes and DNS behavior you explicitly configured. A gateway search suffix alone is not its split-DNS policy. Record what was configured and observed without internal domains or IP addresses. |
| Pause and resume | Pause, then resume. Check a VPN resource and an ordinary public site after each transition. Public access should follow your configured policy. |
| Disconnect | Disconnect explicitly. Confirm the connection stays down and ordinary networking still works. |
| Use it again | Reopen the app and reconnect later. Record whether the profile, chosen credential sources and network policy persisted. |

Describe optional checks separately: sleep/wake, Wi-Fi changes, Ethernet changes,
SOCKS mode and QR import. Mark them not tried if you did not exercise them.
An automated or simulated check does not replace a real gateway result.

If a preview adds a new setup assistant or server-suggested networks, record the
source commit and whether you accepted or skipped those suggestions. Check that
only your selections were saved. Do not assume the stable release has the same
screens as a preview.

## Send a result

Use the [gateway report form](https://github.com/ValeraGin/openconnect-for-mac/issues/new?template=gateway_report.yml)
for compatibility results, or the [bug report form](https://github.com/ValeraGin/openconnect-for-mac/issues/new?template=bug_report.yml)
for a specific failure. Include:

- Build, macOS version, architecture and installation method.
- Gateway and identity provider product names, if known.
- The last successful step, the failing step, expected and actual behavior.
- Whether normal networking was restored after disconnecting.

If logs are needed, `ocmac report report.txt` creates a diagnostic report.
Read it before attaching it: automated masking cannot identify every internal
name. Do not publish organization names, gateway addresses, internal domains,
profiles, passwords, cookies, tokens or TOTP secrets. Crop or redact screenshots
before sharing them. Send security reports through [SECURITY.md](SECURITY.md).

If you decide to remove the app, follow the
[uninstall instructions](INSTALL.md#8-удаление). Remove its system component
before removing the Homebrew formula.
