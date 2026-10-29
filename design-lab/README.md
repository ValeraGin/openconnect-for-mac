# OpenConnect for Mac — Demo

Standalone native macOS prototype for a new settings design. It has no dependency
on the running production app, CLI, VPN helper, keychain or profile store. It reuses
the production TOTP algorithm and QR payload parser through source symlinks. All data is
synthetic. The only persistent value is the last selected demo profile in the
separate `ru.ocmac.designlab` preferences domain. Edits reset on launch.

```sh
bash design-lab/build.sh
open ".local/design-lab/OpenConnect for Mac — Demo.app"
bash design-lab/test.sh
```

The window is fixed at 680 × 620. Connection, Sign-in, Network, Advanced and
Application are always visible in the sidebar. Profile changes retain the current
section. Opening settings selects an existing active profile, then the last
selected profile, then the first available profile. Unsaved edits prompt before
switching profiles; invalid edits cannot be saved or connected.

The bottom **Demo** strip controls scenarios, language (RU/EN), and appearance.
The arrow-in-window button simulates reopening settings; reset restores the
current fixture. These are laboratory controls, not part of the proposed product.
Connect opens a separate sign-in window. Follow SSO → password → code → success,
or choose Password and SMS as the profile's sign-in method. Use the synthetic password
`demo` and code `287082`. Wrong values show errors; expired sign-in can be restarted.
Only completing verification connects the synthetic profile. Cancelling a switch
keeps the previous profile connected. No external browser or network is opened.
The saved-credential buttons open editors; credential changes apply immediately
to the in-memory profile independently of Save, like production secret storage.
Launch-at-login changes in-memory state only.
Profile additions and edits are intentionally disposable.

Profile names are optional: the address is the fallback display label, while
the stable profile ID stays unchanged. A custom name lives under Advanced.
After successful authenticator sign-in, the demo offers optional TOTP setup.
It checks a secret or otpauth payload against the recorded code using the real
algorithm at a fixed test time (Unix 59, public RFC test secret). It never saves
the one-time digits as a secret. SMS profiles do not receive this offer.

Scenarios: disconnected, connected, connecting, server error, no profiles, one
profile, 20 profiles, long values, missing fields, unsaved changes, SOCKS warning;
SSO, password, one-time code, rejected sign-in, expired code, successful sign-in;
password and secret editors, an unnamed profile, TOTP offer/setup, SMS, and About.
The 440 × 540 sign-in and About windows
open from settings; About is also available in the application menu.

Name, URL, username, DNS domains, port, upstream proxy and User-Agent use native single-line
NSTextFields. Long values scroll during editing and have full-value tooltips.
Only the subnet list is multiline. Blue identifies navigation/actions; green,
orange and red identify success, warnings and errors. Passive native controls
still use macOS inactive styling.

The app identity uses the existing `app/Resources/AppIcon.icns`, `assets/mark.svg`
and name OpenConnect for Mac. Demo is a separate build label, not a replacement brand.
Interface icons are original Lucide SVGs from the official repository. The exact source
commit and file list are in `Resources/Lucide/SOURCE.json`; original ISC/MIT
notices are in `Resources/Lucide/LICENSE` and included in the app's About window.
See <https://lucide.dev/license> and <https://github.com/lucide-icons/lucide>.

The prototype covers common settings to validate hierarchy and navigation; it is
not a feature-complete replacement for the production editor.
`capabilities.json` documents 31 source-backed comparisons, new UX and omissions.
Regenerate it and the readable `.local/design-lab/capabilities-v03.html` report:

```sh
python3 design-lab/compare-capabilities.py
```

Production has no editable certificate fingerprint or per-profile reconnect
setting, so those controls were removed. Autoconnect is a global policy. IPv4
full-tunnel routing is labelled explicitly. Before production integration, design
work remains for DNS resolvers/ports, credential sources, form rules, notifications,
diagnostics, logs, pause/resume and setup/import/export. Source inspection does not
replace live VPN regression testing.

```sh
python3 design-lab/review.py --capture-passive
python3 design-lab/review.py --capture-passive --only ru-idle-connection
```

Review explicitly requires a non-mirrored built-in screen. The diagnostic panel
cannot become key/main or receive mouse input. The runner uses `open -g` and
captures the native window with `screencapture`; JSON sidecars validate focus and
display before accepting images. No external-screen fallback or active capture.
Native controls are inactive; do not use these frames to approve active colors.
The gallery is `.local/design-lab/review/index.html`. Normal interactive launch is
only for the user to open when ready; automated review never activates it.
