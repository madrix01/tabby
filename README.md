# Tabby

Pets you raise. Each critter evolves and wears items. The project started from reverse-engineering the Tabby Cat Chrome extension's pet and item generation.

| Path | What |
|---|---|
| `characters/` | The 46 critter SVGs, the source art (41–46 are drawn by `make_extra.py`). |
| `compiler/` | Measures every character once and builds `critter_catalog.json` with both art sets (v3 from `characters/`, v4 from `shapes_v4/`): normalised paths, anchors, items and evolution lines. Run `npm install && npm run build`. |
| `shapes_v4/` | The 40 v4 shape SVGs, the source art for the v4 set. |
| `critter_engine/` | Flutter package. It renders a critter from a JSON spec (species, form, attachments and inline items) using the catalog. |
| `v3/` | Browser prototype of the current engine. Open `index.html`. |
| `v2/`, `blobs/` | Earlier browser prototypes with other art styles. |

The Flutter API, the JSON spec and the item format are documented in `critter_engine/README.md`. The catalog format is documented in `compiler/README.md`.
