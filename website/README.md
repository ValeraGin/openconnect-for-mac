# OpenConnect for Mac website

English and Russian landing pages and installation guides, published on GitHub Pages.
The landing is one short page: what OpenConnect for Mac is, the connection animation, five advantages,
the install commands and links. No runtime dependencies or tracking; the only
scripts are language detection and the copy button.

## Build and check

```sh
python3 website/build.py --url https://valeragin.github.io/openconnect-for-mac/
python3 website/check.py
python3 -m http.server 8767 --bind 127.0.0.1 --directory website
```

Preview `/dist/` and `/dist/ru/`. The main page template is `src/page.html`;
translations are in `src/en.json` and `src/ru.json`. Installation guides keep their
own templates and their existing URLs. `dist/landing.css` styles the landing,
`dist/style.css` the installation guides. The build copies the README animation
`assets/demo.gif` and `assets/ru/demo.gif` to `dist/assets/demo-{en,ru}.gif`,
and the profile screenshots to `dist/assets/profile-{en,ru}.png`; the page
background matches the animation background `#EEF0EA`. Generated HTML is tracked.

## Publish

Main site — GitHub Pages: [English](https://valeragin.github.io/openconnect-for-mac/) ·
[Русский](https://valeragin.github.io/openconnect-for-mac/ru/). The **Website** workflow builds
and publishes it on every push to `main` that changes `website/`, and can be run
by hand. `configure-pages` supplies the address, so canonical URLs follow it.

GitHub Pages, not Cloudflare Pages: `*.pages.dev` does not resolve from Russian
mobile networks without a VPN, while `github.io` does (both checked 2026-10-16).
The former Cloudflare project `ocmac.pages.dev` was deleted on 2026-10-17.
After a push, check both languages, installation links and the animation.

Always build with the stable project URL. The build generates canonical URLs,
language alternates, social-card URLs, sitemap and robots.txt. A deployment
preview URL must not become the canonical URL. Without `--url`, the build makes
a portable local preview and removes sitemap/robots files.

## Screenshots and assets

`tools/screenshots.sh` captures 24 real windows in English and Russian on the
built-in display with synthetic profiles, without activating the app or taking
keyboard input. Both languages use light appearance. Controls are inactive;
these are not active-window color references. Export requires matching app/CLI
versions, build hashes and focus/display proof for every image.

`assets/captures.json` records the version, build and image hashes. Use
`python3 tools/screenshots.py --verify-only` to check the exported images without
opening windows. `--resume` preserves matching captures after an interrupted run.

`tools/demo-gif.sh` rebuilds `assets/demo.gif` and `assets/ru/demo.gif` from the
verified connection-window stills. It illustrates states, not a live connection.
`tools/social-card.sh` uses the verified connected-window screenshot for the link
cards in `dist/assets/`. Neither script opens a menu or window.
Run both after screenshots, then rebuild the website. Legacy `tools/menu-capture.sh`
opens a tracking menu and is not part of this background capture workflow.

SVG route, DNS, comparison and open-source illustrations are localized for both
languages. `mark.svg`/`icon.svg` match the native app switch. The social card uses
this identity too. See [ASSETS.md](ASSETS.md) for provenance.
