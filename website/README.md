# Website

Static English and Russian project pages and installation guides. GitHub Pages.
No runtime dependencies, tracking, animations or screenshot galleries.

## Build

```sh
python3 website/build.py --url https://valeragin.github.io/openconnect-for-mac/
python3 website/check.py
python3 -m http.server 8767 --bind 127.0.0.1 --directory website/dist
```

Open `/`, `/ru/`, `/guide/` and `/ru/guide/`.

- `src/page.html`: project overview.
- `src/guide.html`, `src/guide-{en,ru}.html`: installation guides.
- `src/{en,ru}.json`: shared copy and translations.
- `dist/style.css`: shared layout, system monospace font and light/dark themes.
- `dist/copy.js`: command copying; falls back to selecting text.
- `dist/landing.css`: compatibility stylesheet for previously cached pages.
- `dist/assets/`: favicon, share cards and legacy image URLs. Current pages do
  not load the legacy screenshots or animations.

Generated HTML is tracked. Rebuild it when changing templates or translations.
The language choice is stored locally; browser language is used if no choice exists.

## Publish

The Website workflow builds and publishes on pushes to `main` that change
`website/`. It can also be dispatched manually. Keep the public canonical URL
stable: preview URLs must not replace it.

The checker validates page languages, local links, anchors, metadata and
translation keys. Review both languages at narrow and wide viewport widths;
verify command copying and keyboard focus. Use synthetic examples only.

## Content

Installation instructions describe the published client. Check commands and
capabilities against `main` before publishing. Working-branch features must not
be advertised as part of the public installer until the client is released.
