# OpenConnect for Mac

[Website](https://valeragin.github.io/openconnect-for-mac/) · [Installation](INSTALL.md) · [Troubleshooting](TROUBLESHOOTING.en.md) · [Русский](README.ru.md)

An AnyConnect-compatible VPN client for macOS. OpenConnect handles the tunnel.
A native menu bar app and the `ocmac` CLI manage sign-in, profiles, routes and DNS.

Requires macOS 14.4+ and access to a compatible gateway. The project does not
provide VPN servers. English and Russian interfaces. MIT license; no telemetry.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ValeraGin/openconnect-for-mac/main/install.sh)"
```

Run as your regular user. The [installer](install.sh) offers missing Apple Command
Line Tools and Homebrew, builds the app and installs the system helper.
The helper requires administrator access. System setup may interrupt an existing
VPN session. Building can take several minutes.

For an existing Homebrew installation:

```bash
brew upgrade openconnect-for-mac
ocmac app upgrade
ocmac doctor
```

If the helper is outdated, run `ocmac prepare && sudo ocmac install` again.
See [INSTALL.md](INSTALL.md) for manual installation, migration and cleanup.

## Configuration

One `.ocmac` file describes one connection. Create
`~/.config/ocmac/profiles/work.ocmac` or import a file received from a teammate.

```ini
[Connection]
Name = Work
Url = vpn.example.com/employees
User = your-login

[Routes]
10.0.0.0/8

[DNS]
corp.example.com = vpn

[Auth]
Password = ask
Totp = off
```

- `[Routes]`: IPv4 networks sent through the tunnel. Other traffic uses the normal connection.
- `[DNS]`: domains resolved by a specific resolver. `vpn` uses a gateway-supplied DNS server. Subdomains are included; more specific zones take priority.
- `[Auth]`: credential sources. This example uses manual password and code entry.
  Keychain, KeePassXC and custom commands are also supported.
- A gateway search suffix is separate from its split-DNS policy. It is not a complete list of VPN DNS domains.

Validate before connecting:

```bash
ocmac profile-check ~/.config/ocmac/profiles/work.ocmac
ocmac connect work
```

See [etc/example.ocmac](etc/example.ocmac) for all profile settings. The legacy
`profiles.conf`, `networks.conf` and `zones.conf` formats remain available through
the CLI. Export converts one legacy connection to a self-contained `.ocmac`.

### Sign-in rules

```bash
ocmac connect work --teach
```

Complete the organization’s web sign-in. After success, choose whether to save
form rules, the password in Keychain and the one-time code source. Saving the
profile itself does not save a password. Password and TOTP secret values belong
in credential storage, not in the profile.

`ocmac learn work` provides manual form annotation. Rules can also be managed with
`ocmac rules show`, `ocmac rules import` and `ocmac rules clear`. See
[INSTALL.md](INSTALL.md) for multi-step forms and custom credential commands.

### HostScan / CSD

If required by the gateway, obtain an organization-approved wrapper.
`CsdWrapper` refers to a file; `CsdScriptBase64` embeds the script in the profile.
Opening or validating a profile does not execute it. Connecting can run CSD and
credential commands, so review configuration from other people.

```bash
ocmac prepare
sudo ocmac install
ocmac csd-status work
```

The installed system copy must match the profile. An embedded script is portable,
but still requires system preparation. The [example wrapper](etc/csd-wrapper.sh)
contains sample assessment results; it is not a device assessment ready for deployment.

### Import and export

```bash
ocmac import team.ocmac
ocmac import cisco.xml
ocmac export work team.ocmac
```

Cisco XML imports server addresses, not routes, DNS or credentials. A `.ocmac`
export preserves routes, DNS, form rules and embedded CSD. It does not retrieve
credential-store secrets. Review User, local paths and custom commands before
sharing. Keep corporate configuration within your team.

### SOCKS mode

`[Connection] Mode = proxy` uses `ocproxy` instead of a system tunnel. It requires
`brew install ocproxy`. This mode does not install VPN routes or DNS zones.
Set `[Proxy] Port = 11080` and choose whether to enable the system SOCKS proxy.

## Commands

```bash
ocmac connect work
ocmac connect work --teach
ocmac disconnect
ocmac pause
ocmac resume
ocmac status --json
ocmac doctor
ocmac logs -n 100
ocmac autoconnect resume
ocmac import work.ocmac
ocmac export work team.ocmac
ocmac report report.txt
```

`ocmac help` lists all commands. `status --json` is the interface used by the app.
`doctor` is read-only. Inspect generated reports before publishing them.

## Connection lifecycle

- `autoconnect resume` restores the last selected connection after an outage.
- `autoconnect manual` disables fresh automatic sign-ins.
- `autoconnect always work` selects a profile at login.
- `pause` removes the app’s routes and DNS settings while retaining its session.
- `disconnect` clears the selected connection and remains disconnected.

The supervisor monitors the connection and retries with backoff. An expired SSO
session can require user input. It does not open a sign-in window automatically.

## Implementation

| Component | Responsibility |
| --- | --- |
| `app/` | SwiftUI/AppKit menu bar app; no root privileges |
| `auth/` | WebKit SSO, form rules, credential and QR dialogs |
| `bin/ocmac` | Bash CLI and connection supervisor |
| `libexec/ocmac-helper` | Validated privileged operations, tunnel setup and cleanup |
| OpenConnect | TLS/DTLS transport |

The helper receives cookies through stdin. It tracks its own routes and DNS
entries and removes them on disconnect. The sudoers rule allows the helper,
not an unrestricted shell. A user LaunchAgent runs the supervisor.

## Development

```bash
ocmac selftest
ocmac-auth --selftest
ocmac-auth --learn-selftest
python3 website/build.py --url https://valeragin.github.io/openconnect-for-mac/
python3 website/check.py
```

Build the GUI with `bash app/make-app.sh`. The installer handles the source build.
Tests use temporary state, stub helpers or test gateways; they do not establish
compatibility with every production identity provider. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Compatibility and limits

- Used on macOS 26, Apple Silicon, with an AnyConnect-compatible gateway and Keycloak.
- macOS 14.4 is the deployment target. Intel and macOS 14.4–15 have no real-device verification.
- A clean installation and first sign-in on another Mac have not been verified.
- ocserv and synthetic SSO tests do not confirm production Okta or Microsoft Entra ID compatibility.
- IPv6 tunnel addresses can be configured; IPv6 routes are not managed.
- HostScan and authentication requirements depend on the gateway.
- System installation and removal can interrupt an active connection.

## Documentation

[Connection](assets/connection.png) · [Setup](assets/setup.png) · [Settings](assets/profile.png) · [Sign-in settings](assets/login.png) · [Network](assets/network.png)

Screenshots use demonstration profiles and real windows captured in the background.
Native controls are inactive. [Capture provenance](website/ASSETS.md).

[Installation](INSTALL.md) · [Troubleshooting](TROUBLESHOOTING.en.md) · [Full troubleshooting, Russian](TROUBLESHOOTING.md) · [Changelog](CHANGELOG.md) · [Security](SECURITY.md) · [License](LICENSE)

Independent project, not affiliated with Cisco or the OpenConnect project.
“AnyConnect” describes protocol compatibility.
