# Tabby

Pets you raise. Each critter evolves and wears items. The project started from reverse-engineering the Tabby Cat Chrome extension's pet and item generation.

| Path | What |
|---|---|
| `characters/` | The 46 critter SVGs, the source art (41–46 are drawn by `make_extra.py`). |
| `compiler/` | Measures every character once and builds `critter_catalog.json` with every art set (v3 from `characters/`, v4 from `shapes_v4/`, v6 frens from `frens-svgs/`): normalised paths, anchors, items and evolution lines. Run `npm install && npm run build`. |
| `shapes_v4/` | The 40 v4 shape SVGs, the source art for the v4 set. |
| `critter_engine/` | Flutter package. It renders a critter from a JSON spec (species, form, attachments and inline items) using the catalog. |
| `v3/` | Browser prototype of the current engine. Open `index.html`. |
| `v4/` | v3 rebuilt on the `shapes_v4/` art (`build_shapes.py` makes `shapes.js`). |
| `v6/` | v3 with the Frens art from `frens-svgs/` (8 frens × 7 stages, unisex and cute sets; `build_frens.py` makes `characters.js`). |
| `v5/` | The Tabby Cat new-tab page rebuilt without React, using the extension's art and CSS (`pets.js`), plus v3's moods, growth, glow and send money. |
| `v2/`, `blobs/` | Earlier browser prototypes with other art styles. |

The Flutter API, the JSON spec and the item format are documented in `critter_engine/README.md`. The catalog format is documented in `compiler/README.md`.
