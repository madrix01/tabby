# critter_engine

Renders a critter (character + attachments) from a JSON spec. The geometry comes from `assets/critter_catalog.json`, which `../compiler` builds (`npm run build` writes it straight into this package).

```dart
final catalog = await CritterCatalog.load();                 // once
catalog.registerItems(itemsJsonFromBackend);                 // optional: items shared by every critter

CritterView(catalog: catalog, spec: CritterSpec.fromJson(payload));
```

## Spec

```json
{
  "v": 1,
  "species": "pip", "form": 2, "xp": 230,
  "attachments": { "hat": "viking", "eyes": "goggles", "neck": "gold_chain", "prop": "gold_bar" },
  "behaviour": { "likesPets": true, "gait": "waddle", "state": "idle" },
  "items": [ { "id": "viking", "slot": "hat", "anchor": [50, 62], "svg": "<path d='…' fill='#9aa0a6'/>" } ]
}
```

- **`species` / `form`:** the evolution line and the stage in it. The server decides `form`, and the engine clamps it to the line. Unknown species render nothing.
- **`xp`:** optional. It only grows the critter slightly within its current form.
- **`attachments`:** item ids. They resolve against this spec's `items` first, then the catalog. Unknown ids are skipped.
- **`behaviour`:** carried through for the animation layer (phase 3).

## Look

Set `"look": "glow"` in the spec, or pass `CritterView(look: CritterLook.glow)` to override it. Glow mode adds:
- bodies shaded from light (top-left) to dark (bottom)
- a glossy highlight and glints in round eyes
- a soft contact shadow under the feet
- a colour halo: a blurred, brightened copy of the critter drawn behind it, so a flame glows orange and a blue body glows blue

Every part can be tuned with an optional `glow` object, or with `CritterView(glow: CritterGlow(...))`:

```json
"look": "glow",
"glow": { "halo": 0.35, "blur": 0.8, "brightness": 1, "shading": 1.5, "gloss": 0.45, "shadow": 1.5, "color": "#ffb347" }
```

| knob | default | range | what it changes |
|---|---|---|---|
| `halo` | 0.35 | 0–1 | how opaque the halo is (0 = no halo) |
| `blur` | 0.8 | 0–3 | how big the halo is |
| `brightness` | 1 | 1–2 | how much brighter than the critter the halo is |
| `shading` | 1.5 | 0–1.5 | strength of the light-to-dark body shading (0 = flat colour) |
| `gloss` | 0.45 | 0–1.5 | the highlight and the eye glints |
| `shadow` | 1.5 | 0–1.5 | the contact shadow |
| `color` | none | `#rrggbb` | paints the halo in one colour (e.g. a warm stage light) instead of the critter's own colours |

Out-of-range values are clamped, and missing knobs keep their defaults. The `glow_knobs` golden shows four presets. Glow reads best on a dark background. The background or stage is the host app's job; see the `glow` golden for a spotlight example. `flat` is the default, and unknown values fall back to it.

## Items as JSON

| slot | fields |
|---|---|
| `hat` | `svg` drawn about 100 wide, `anchor` = bottom-centre of the hat |
| `neck` | `svg`, `anchor` = top-centre, `fit` = width as a fraction of the neck, `height` = drawn height |
| `prop` | `svg`, `anchor` = bottom-left of the prop; it stands on the ground beside the feet |
| `eyes` | `lens` = one lens centred on (0,0) at radius 10, `grow`, `bridge` colour, optional `strap` colour |

Every character places every item automatically from its measured anchors. You never position an item per character.

The SVG arrives over the network, so it is validated:
- **Allowed tags:** `path`, `circle`, `ellipse`, `rect`, `polygon`, `polyline`, `line`, `g`.
- **Rejected:** `href`, `url(`, `style`, entities and `<text>`, and anything over 50 KB.
- **Colours:** `#rgb` or `#rrggbb` only.

Bad items are dropped with a debug message, and the other items still render.

## Tests

```
flutter test                        # parsing, placement parity with the compiler, svg validity, goldens
flutter test --update-goldens test/golden_test.dart
```

`test/goldens/gallery.png` should match `../compiler/out/gallery.html`.
