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

The default window is the compact assistant comparison at 560 × 420. The app menu opens the full settings prototype, fixed at 680 × 620. Connection, Sign-in, Network, Advanced and
Application, Notifications and Diagnostics are always visible in the sidebar. Profile changes retain the current
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
Profile additions and edits are intentionally disposable. Export and report buttons
can save a synthetic file only after the user chooses its destination.

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
Version 0.4 has 39 fixtures, adding pause, custom/invalid DNS, KeePassXC locked/unlocked,
command sources, form mapping, blocked notifications, missing helper, diagnostics
failure, external-file conflict, sample import, QR import, eight-digit TOTP and empty logs.
The 440 × 540 sign-in and About windows
open from settings; About is also available in the application menu.

Name, URL, username, DNS domains, port, upstream proxy and User-Agent use native single-line
NSTextFields. Long values scroll during editing and have full-value tooltips.
Only subnet lists and sign-in rules are multiline. Blue identifies navigation/actions; green,
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
`capabilities.json` documents 39 source-backed comparisons, new UX and omissions.
Regenerate it and the readable `.local/design-lab/capabilities-v04.html` report:

```sh
python3 design-lab/compare-capabilities.py
```

Production has no editable certificate fingerprint or per-profile reconnect
setting, so those controls were removed. Autoconnect is a global policy. IPv4
full-tunnel routing is labelled explicitly. Secondary screens now cover DNS resolvers/ports,
credential sources, KeePassXC, form rules/mapping, compatibility, notifications,
diagnostics, logs, pause/resume, setup and import/export. Profile management covers
ordering and a legacy conversion example. About links to component/file information.
The connection card and navigation reuse the real app mark; the empty state uses
Lucide folder-plus, not a shield.

Actions simulate the intended behavior without invoking the production engine.
Integration must retain the real ProfileDoc parser (comments, unknown fields and
backup/conflict semantics), server-owned WebView forms, system permissions, QR
capture, live credential sources, TOTP timer and log streams. Source inspection and
synthetic tests do not replace live VPN regression testing.

The helper-missing fixture blocks tunnel sign-in while permitting SOCKS. Pause keeps
the synthetic session alive and disables runtime routes/DNS without editing the
saved profile. Secret writes apply independently of profile Save. The setup resource
check is transient, so it does not leave the profile dirty or block sign-in.

```sh
python3 design-lab/review.py --capture-passive
python3 design-lab/review.py --capture-passive --only ru-idle-connection
python3 design-lab/review.py --capture-passive --missing
```

Review explicitly requires a non-mirrored built-in screen. The diagnostic panel
cannot become key/main or receive mouse input. The runner uses `open -g -n -W` in accessory mode and
captures the native window with `screencapture`; JSON sidecars validate focus and
display before accepting images. No external-screen fallback or active capture.
Native controls are inactive; do not use these frames to approve active colors.
The versioned gallery is `.local/design-lab/review/v04.html` (also `index.html`).
Locked/asleep sessions stop before launching a capture window. `--missing` resumes
without reshooting accepted frames; `--gallery-only` works while locked. The gallery
shows accepted/expected counts so an incomplete run cannot appear complete.
Long forms also have `-bottom` captures; the capture host scrolls only its own passive
window. Metadata records the selected detail and scroll request. Normal interactive launch is
only for the user to open when ready; automated review never activates it.

Review after the RU/EN pass (2026-10-30): 178 planned passive frames, covering all
39 fixtures plus overflow, second wizard/mapping steps, code/secret errors, empty
lists, credential-source summaries and edited drafts during an active session.
`ReviewStates.swift` supplies reachable sample states only in the passive launch path;
model tests exercise the changed state semantics. Sign-in content scrolls inside its
fixed window while Close stays visible. Empty profiles have localized labels;
paused profiles, unsaved edits and file conflicts have explicit status text.
Credential-source summaries are localized, and the settings TOTP example follows
its configured digits/algorithm/period. Current-session controls read the saved
profile rather than unsaved form edits. Native active-color review remains separate.


Setup assistant revision (2026-11-05): the empty screen offers **Set up connection**,
missing-helper warnings offer **Finish setup**, and Application retains a secondary
**Run setup assistant again…** action. The first step edits the selected profile's
address, username, sign-in method and traffic mode in place. Save and continue
validates and saves before proceeding. The system step appears only for a tunnel
that needs the helper; ready systems and SOCKS skip it. Back cannot bypass validation.
The last step opens the existing sign-in window, optionally checks a sample HTTP(S)
resource after connection, and returns to Connection when done. Closing preserves
profile edits and returns to the originating section. Installation and network access
remain simulated. Focused RU/EN captures cover the entry points, empty/long/invalid
profiles, missing/ready helper, SOCKS, sign-in and successful access.


Compact comparison (2026-11-05): the default demo compares SwiftUI Grid + AppKit
inputs with actual `Settings.Container` / `Settings.Section` from Settings 3.0.0.
The package is pinned in `Package.resolved`; its MIT notice is bundled and shown
under About → Licenses. This compares form layout only, not SettingsWindowController.
The layout selector preserves entered values. RU/EN and light/dark are selectable.
The production app and VPN engine are not affected by this prototype.

Connection, Network, optional System, and Verify are separate fixed-height steps;
none uses a scroll view. Route/DNS counts have explicit Edit buttons that open
520 × 360 dialogs. Only the lists scroll. Save validates a working copy; Cancel
leaves the original list intact. Selected-network mode requires at least one
subnet before continuing (a stricter proposed UX than production's warning).
All preparation, connection and access actions are clearly simulated.

```sh
python3 design-lab/compact-review.py --capture-passive --resume
```

The comparison gallery is `.local/compact-design-review/index.html`. Its 50 states
include both layouts in both languages and both themes, long/invalid inputs,
network modes, missing helper, verification and route/DNS editors with large lists.
Controls remain inactive for focus-preserving capture; these images do not settle
the reported corner highlights in active windows.
