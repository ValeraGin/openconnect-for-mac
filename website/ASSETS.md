# Visual assets

The graphite-and-lime switch matches `app/make-icon.swift` and the app's
`AppMark`. `dist/assets/mark.svg` and `icon.svg` use the same identity.
Brand accent: #C3F36B. No remote fonts or third-party stock images are used.

## Screenshots for 0.27.0

`tools/screenshots.sh` captures the production app's real windows on synthetic
profiles, on the built-in display, without activation or keyboard input.
Both languages use light appearance. Native controls and title bars are
inactive. These frames show the app layout; they are not active-window color
references. No personal profiles, VPN sessions, keychain entries or camera
images are used.

`assets/captures.json` records the app version, executable and bundle metadata
hashes, capture mode, image hashes and language. Every frame must prove that
focus was preserved and that it was on the built-in display before any public
image is replaced. `python3 tools/screenshots.py --verify-only` checks the
exported set against the current build without launching UI.

There are twelve screenshots per language in `assets/` and `assets/ru/`:

| File | Content |
| --- | --- |
| `connection.png` | Connected window |
| `connection-idle.png` | Disconnected window |
| `connection-connecting.png` | Connecting window |
| `connection-paused.png` | Paused window |
| `profile.png` | Connection settings |
| `login.png` | Sign-in settings |
| `network.png` | Network settings |
| `advanced.png` | Advanced settings |
| `notifications.png` | Notification settings |
| `about.png` | About the app and its version |
| `setup.png` | New profile in the setup assistant |
| `setup-network.png` | Reviewing server-suggested networks and DNS |

`website/build.py` copies profile screenshots to
`dist/assets/profile-{en,ru}.png`. The README files link to the localized images.

## Animation and link cards

`tools/demo-gif.sh` builds `assets/demo.gif` and `assets/ru/demo.gif` from the
verified disconnected, connecting, connected and paused window stills. These
are illustrative state transitions, not a recording of real authentication or
a VPN connection. Background: #EEF0EA. The build copies them to
`dist/assets/demo-{en,ru}.gif` and derives image dimensions from the GIF header.

`tools/social-card.sh` creates 1200×630 link cards from the verified connected
window image using `tools/make-social-card.swift`. PNG files are the masters;
JPEG files are used by Open Graph. `social-card.*` is the English copy. Upload
of the GitHub social preview is a separate publication action.

Both generators verify capture hashes and version before rendering and never
open menus or windows. The previous menu screenshots are removed; the native
tracking-menu capture tool is reserved for separately agreed interactive checks.
