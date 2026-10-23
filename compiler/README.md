# Critter catalog compiler

Measures every character once and writes everything the app needs to compose a critter, so the Flutter side never does geometry.

```
npm install
npm run build      # ../characters/*.svg (v3) + ../shapes_v4/*.svg (v4) + items.mjs -> out/critter_catalog.json, out/gallery.html, ../docs/evolution_sheet*.svg
```

Open `out/gallery.html` after a build. It is drawn from the catalog alone, the same way the app will compose it.

## Catalog format (`version: 2`)

Version 2 adds the v4 set. All new fields are optional, so v3 characters look exactly as they did in version 1.

All coordinates are in **character space**:
- The origin is at the feet (bottom centre), and y grows downwards.
- Every character is about 100 tall and at most 150 wide.

The app scales this space to the widget size.

| Key | What |
|---|---|
| `characters[id].skin[]` | Body parts: `{ d, fill, fillRule?, clip?, stroke? }`. Transforms are already applied. Draw these first. `clip` is an index into `clips` (v4 textures stay inside the body). `stroke` outlines the part in its own colour at that width (v4 legs). |
| `characters[id].clips[]` | v4 only: clip shapes as path data, referenced by index from `skin[].clip` and `ink[].clip`. |
| `characters[id].ink[]` | Face parts: `{ d }` or `{ cx, cy, r }`, in the ink colour unless `fill` is set (v4 eye whites are `#ffffff`). `eye: true` marks blinkable eyes; draw them as a separate layer and scale Y around `anchors.eye[1]`. A `clip` keeps a v4 pupil inside its white. |
| `characters[id].attach.hat/neck/prop[item]` | A transform string. Output `<g transform="…">{items.<slot>[item].svg}</g>`. |
| `characters[id].attach.eyes[item]` | `{ transform, svg }`. Eyewear is generated per character, one lens per eye. |
| `characters[id].anchors` | The measured points (eye, hat seat, neck, side…). For debugging, or for placing new UI such as speech bubbles. v4 characters add `body: [top, bottom]`, the body without its legs. |
| `items` | Item SVG snippets: hats, neck items and props. Eyewear is marked `perCharacter`. |
| `species[]` | Evolution lines. `collection` is `v3` or `v4`. `forms[]` holds `{ character, name, atLevel, size:[min,max] }`; `size` is the scale applied while growing inside that form. v4 character ids are `v4_<shape number>`. |

Composition order: skin, then ink (eyes on their own layer), then neck, then eyes, then hat. The prop goes on its own layer and is not tilted with the body.

## Rules kept for flutter_svg
The catalog uses no `<text>`, no 8-digit hex colours, no `stroke-dasharray` and no CSS variables. Keep it that way when adding items to `items.mjs`.

## Adding things
- **v3 character:** drop `character_NN.svg` into `../characters/` and add it to a line in `LINES` (the build warns about any character that isn't in a line), then rebuild.
- **v4 character:** drop `shape_NN.svg` into `../shapes_v4/` and add it as `v4_NN` to a line in `LINES_V4`, then rebuild. `v4.mjs` parses and measures it the same way `v4/index.html` does.
- **Item:** add it to `HATS`, `NECK` or `PROPS` in `items.mjs`. Draw it about 100 wide around its marker `m` and rebuild. Every character gets a placement for it automatically.
