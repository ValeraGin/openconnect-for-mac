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
Connect, saved-credential buttons and launch-at-login only change in-memory state.
Connecting completes immediately; choose the Connecting fixture to study its
intermediate state. Profile additions and edits are intentionally disposable.

Scenarios: disconnected, connected, connecting, server error, no profiles, one
profile, 20 profiles, long values, missing fields, unsaved changes, SOCKS warning.
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
