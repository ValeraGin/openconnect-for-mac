# OpenConnect Design Lab

Standalone native macOS prototype for a new settings design. It has no dependency
on the production app, CLI, VPN helper, keychain or profile store. All data is
synthetic. The only persistent value is the last selected demo profile in the
separate `ru.ocmac.designlab` preferences domain. Edits reset on launch.

```sh
bash design-lab/build.sh
open ".local/design-lab/OpenConnect Design Lab.app"
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
or choose Password as the profile's sign-in method. Use the synthetic password
`demo` and code `123456`. Wrong values show errors; expired codes can be retried.
Only completing verification connects the synthetic profile. Cancelling a switch
keeps the previous profile connected. No external browser or network is opened.
The saved-credential buttons open editors; their changes remain in the draft
until Save is pressed. Launch-at-login changes in-memory state only.
Profile additions and edits are intentionally disposable.

Scenarios: disconnected, connected, connecting, server error, no profiles, one
profile, 20 profiles, long values, missing fields, unsaved changes, SOCKS warning;
SSO, password, one-time code, rejected sign-in, expired code, successful sign-in;
password and code editors, and About. The 440 × 540 sign-in and About windows
open from settings; About is also available in the application menu.

Name, URL, username, DNS domains, port and fingerprint use native single-line
NSTextFields. Long values scroll during editing and have full-value tooltips.
Only the subnet list is multiline. Blue identifies navigation/actions; green,
orange and red identify success, warnings and errors. Passive native controls
still use macOS inactive styling.

Icons are original Lucide SVGs from the official repository. The exact source
commit and file list are in `Resources/Lucide/SOURCE.json`; original ISC/MIT
notices are in `Resources/Lucide/LICENSE` and included in the app's About window.
See <https://lucide.dev/license> and <https://github.com/lucide-icons/lucide>.

The prototype covers common settings to validate hierarchy and navigation; it is
not a feature-complete replacement for the production editor.

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
