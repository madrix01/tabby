# Critter catalog compiler

Measures every character once and writes everything the app needs to compose a critter, so the Flutter side never does geometry.

```
npm install
npm run build      # ../characters/*.svg + items.mjs -> out/critter_catalog.json, out/gallery.html
```

Open `out/gallery.html` after a build. It is drawn from the catalog alone, the same way the app will compose it.

## Catalog format (`version: 1`)

All coordinates are in **character space**:
- The origin is at the feet (bottom centre), and y grows downwards.
- Every character is about 100 tall and at most 150 wide.

The app scales this space to the widget size.

| Key | What |
|---|---|
| `characters[id].skin[]` | Body parts: `{ d, fill, fillRule? }`. Transforms are already applied. Draw these first. |
| `characters[id].ink[]` | Face parts in the ink colour: `{ d }` or `{ cx, cy, r }`. `eye: true` marks blinkable eyes; draw them as a separate layer and scale Y around `anchors.eye[1]`. |
| `characters[id].attach.hat/neck/prop[item]` | A transform string. Output `<g transform="…">{items.<slot>[item].svg}</g>`. |
| `characters[id].attach.eyes[item]` | `{ transform, svg }`. Eyewear is generated per character, one lens per eye. |
| `characters[id].anchors` | The measured points (eye, hat seat, neck, side…). For debugging, or for placing new UI such as speech bubbles. |
| `items` | Item SVG snippets: hats, neck items and props. Eyewear is marked `perCharacter`. |
| `species[]` | Evolution lines. `forms[]` holds `{ character, name, atLevel, size:[min,max] }`; `size` is the scale applied while growing inside that form. |

Composition order: skin, then ink (eyes on their own layer), then neck, then eyes, then hat. The prop goes on its own layer and is not tilted with the body.

## Rules kept for flutter_svg
The catalog uses no `<text>`, no 8-digit hex colours, no `stroke-dasharray` and no CSS variables. Keep it that way when adding items to `items.mjs`.

## Adding things
- **Character:** drop `character_NN.svg` into `../characters/` and add it to a line in `LINES` (the build warns about any character that isn't in a line), then rebuild.
- **Item:** add it to `HATS`, `NECK` or `PROPS` in `items.mjs`. Draw it about 100 wide around its marker `m` and rebuild. Every character gets a placement for it automatically.
