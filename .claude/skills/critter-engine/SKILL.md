---
name: critter-engine
description: Add and use the critter_engine Flutter package (github.com/madrix01/tabby) to render evolving pet critters with hats, eyewear, neck items and props from a JSON spec. Use when installing critter_engine, rendering a CritterView, building or validating critter JSON payloads (species, form, attachments, inline items), defining custom items as JSON, using the glow look (glow, halo, shadow, shading), or adding new characters or items to the catalog.
---

# critter_engine

A Flutter package that draws a "critter" from a JSON spec. A critter is one of 40 flat-colour characters, at some stage of its evolution line, optionally wearing a hat, eyewear and a neck item, and holding a prop. All character geometry is precomputed in a bundled catalog, so the app only composes SVG and never measures anything.

Repo layout (github.com/madrix01/tabby):
- `critter_engine/`: the Flutter package. This is what apps depend on.
- `compiler/`: Node tool that builds `critter_engine/assets/critter_catalog.json` from `characters/*.svg`. Only needed when adding characters or bundled items.
- `v3/index.html`: browser prototype; open it to see the same critters animated.

## 1. Install

Requirements: Flutter >= 3.38 and Dart >= 3.10.7, the package's SDK constraint. Run `flutter --version` first. If the app's Dart is older, upgrade Flutter (`flutter upgrade`); don't edit the package's constraint.

Add a git dependency. The package lives in a subfolder, so `path` is required:

```yaml
# pubspec.yaml
dependencies:
  critter_engine:
    git:
      url: https://github.com/madrix01/tabby.git
      path: critter_engine
      ref: main          # pin a commit SHA for reproducible builds
```

Then run `flutter pub get`. `flutter_svg` comes in transitively, and the catalog asset ships inside the package, so nothing needs to go under the app's own `flutter: assets:`.

If the repo is private, the machine needs git access to it, through an SSH key or a credential helper. Otherwise `pub get` fails with a clone or permission error. In that case use the SSH URL `git@github.com:madrix01/tabby.git`.

## 2. Load the catalog once

```dart
import 'package:critter_engine/critter_engine.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalog = await CritterCatalog.load();   // ~300 KB JSON from the package's assets
  runApp(MyApp(catalog: catalog));
}
```

Keep one `CritterCatalog` for the whole app and pass it down through a constructor, a provider or an InheritedWidget. Don't reload it per widget.

## 3. Render a critter

```dart
final spec = CritterSpec.fromJson(payloadFromBackend);   // Map<String, dynamic>

SizedBox(
  width: 240,                                   // the view fills the width at a fixed 4:3 aspect
  child: CritterView(catalog: catalog, spec: spec),
)
```

- **Sizing:** `CritterView` uses `AspectRatio(4/3)`, so give it a width, or a height via `FittedBox`. Every critter shares the same frame with the feet near the bottom edge, which means a final form draws bigger than a baby one at the same widget size. That's intentional.
- **Rebuilds:** the widget recomposes only when `spec` changes (specs compare by value), so rebuilding parents is cheap.
- **Unknown values:** an unknown `species` renders an empty box. Unknown item ids are skipped and never throw.

## 4. The JSON spec

```json
{
  "v": 1,
  "species": "squidge",
  "form": 2,
  "xp": 400,
  "attachments": { "hat": "crown", "eyes": "shades", "neck": "gold_chain", "prop": "money_bag" },
  "behaviour": { "likesPets": true, "gait": "waddle", "state": "idle" },
  "look": "glow",
  "items": []
}
```

| Field | Meaning |
|---|---|
| `species` | Evolution line id (table below). Required. |
| `form` | Stage within the line, from 0 to forms-1. The server decides it and the engine clamps it. Default 0. |
| `xp` | Optional. Only grows the critter slightly within its current form. It does **not** change `form`. |
| `attachments` | One item id per slot: `hat`, `eyes`, `neck`, `prop`. A missing slot means empty. |
| `behaviour` | Parsed and carried through, but not used for rendering yet (reserved for animation). |
| `look` | `"flat"` (default) or `"glow"`: shaded glossy bodies, eye glints, a contact shadow and a colour halo. Use it on dark backgrounds. `CritterView(look: CritterLook.glow)` overrides the spec. |
| `glow` | Optional tuning for the glow look. The defaults are `halo` 0.35 (range 0–1), `blur` 0.8 (0–3), `brightness` 1 (1–2), `shading` 1.5, `gloss` 0.45 and `shadow` 1.5 (each 0–1.5, where 0 = off), and `color` `#rrggbb` to tint the halo. Values are clamped and missing knobs keep their defaults. `CritterView(glow: CritterGlow(...))` overrides it. |
| `items` | Optional inline item definitions; see section 5. |

Missing fields get defaults, and unknown ids are ignored. Values of the wrong type, such as `"form": "2"`, do throw, so send numbers as numbers.

### Species (evolution lines), with the level each form unlocks at
| id | forms (form 0 → last) | levels |
|---|---|---|
| blip | Blip → Cloudbert → Blobfred | 1, 4, 8 |
| totem | Totem → Cubey → Jellyfin | 1, 4, 8 |
| sprig | Sprig → Antenna → Broccolord | 1, 4, 8 |
| radish | Radish → Mossy | 1, 6 |
| pip | Pip → Bean → Tri | 1, 4, 8 |
| ember | Ember → Twinny → Archie | 1, 4, 8 |
| pinky | Pinky → Fluffpaw → Hornsby | 1, 4, 8 |
| bunbun | Bunbun → Kitto → Piggo | 1, 4, 8 |
| stamp | Stamp → Longcat | 1, 6 |
| squidge | Squidge → Beaky → Mush → Donut | 1, 3, 6, 10 |
| snowy | Snowy → Pebble | 1, 6 |
| cactoo | Cactoo → Splotch → Teapot | 1, 4, 8 |
| drip | Drip → Chick → Ducko | 1, 4, 8 |
| lemon | Lemon → Bunny → Sunny | 1, 4, 8 |

To derive `form` from xp on the client instead, use the exported curve. A form is unlocked once `levelOf(xp) >= form.atLevel`:
```dart
final line = catalog.species['pip']!;
final level = levelOf(xp);                                   // 1 + floor((xp/30)^(1/1.5))
final form = line.forms.lastIndexWhere((f) => f.atLevel <= level);
```
Pick one source of truth for `form`, server or client. If both compute it, they will drift.

### Bundled item ids
| slot | ids |
|---|---|
| `hat` | top_hat, party, crown, cap, beanie, chef |
| `eyes` | goggles, shades, round, hearts |
| `neck` | bow_tie, gold_chain, medal |
| `prop` | gold_bar, gold_stack, money_bag, coffee |

List them at runtime with `catalog.itemIds('hat')`.

## 5. Custom items as JSON

Any slot can use items defined by the backend. An item is placed on every character automatically, from that character's measured eyes, head and neck. You never position an item per character.

```json
{ "id": "viking", "slot": "hat",  "anchor": [50, 60], "svg": "<path d='M10 60 Q10 20 50 20 Q90 20 90 60Z' fill='#9aa0a6'/>" }
{ "id": "scarf",  "slot": "neck", "anchor": [50, 0], "fit": 0.8, "height": 40, "svg": "…" }
{ "id": "rock",   "slot": "prop", "anchor": [0, 0], "svg": "<path d='M0 0 Q4 -26 24 -28 Q46 -26 48 0Z' fill='#9aa0a6'/>" }
{ "id": "visor",  "slot": "eyes", "lens": "<rect x='-12' y='-6' width='24' height='12' rx='6' fill='#3a85f2'/>", "grow": 1.3, "bridge": "#3a85f2", "strap": "#2b2a33" }
```

How to draw them:
- **hat, neck, prop:** draw the item about **100 units wide**. `anchor` is the point in your drawing that lands on the character:
  - hat: the bottom-centre of the brim; this point sits on the head.
  - neck: the top-centre; this point sits under the mouth. `fit` sets the width as a fraction of the neck (default 0.5), and `height` is the drawn height, which keeps the item above the feet.
  - prop: the bottom-left corner; the prop stands on the ground beside the feet. Draw it upwards, using negative y.
- **eyes:** draw **one lens centred on (0,0) at radius 10**. It is copied onto each eye and scaled to that eye's size. One-eyed critters get a single lens. `bridge` is the colour of the bar between the lenses, `strap` is optional, and `grow` makes the lenses bigger or smaller (default 1.15).

There are two ways to provide items:
```dart
// a) inline, per critter: put the definitions in the spec's "items" array and reference them in "attachments".
//    An inline item overrides a bundled one with the same id, so it can re-skin "money_bag".

// b) once for the whole app, e.g. from an item store fetched at startup:
final rejected = catalog.registerItems(itemsJson);   // List<dynamic> of item maps
if (rejected.isNotEmpty) debugPrint('bad items: $rejected');   // id -> reason; the good ones are still added
```

Item SVG comes over the network, so it is validated, and anything outside these rules is rejected:
- **Allowed tags:** `path`, `circle`, `ellipse`, `rect`, `polygon`, `polyline`, `line`, `g`.
- **Not allowed:** `href`, `url(`, `style`, `<text>`, `<image>`, entities or DOCTYPE, and SVG over 50 KB.
- **Colours** in `bridge` and `strap`: `#rgb` or `#rrggbb` only.
- **Use presentation attributes**, such as `fill="#e8494b"` and `stroke-width="3"`, not `style="…"`.
- **Text:** write words or symbols such as "$" as paths, not `<text>`.

A bad inline item is dropped, with a debug message, and the critter still renders.

## 6. Glow look (halo, shading, shadow)

Glow is a lit, glossy render. It adds:
- bodies shaded from light to dark
- a gloss highlight and glints in round eyes
- a soft contact shadow
- a colour halo behind the critter

Turn it on per critter in the JSON, or for a whole screen in code:

```json
{ "species": "pip", "form": 2, "look": "glow" }
```
```dart
CritterView(catalog: catalog, spec: spec, look: CritterLook.glow);                       // forces glow
CritterView(catalog: catalog, spec: spec, look: CritterLook.glow,
    glow: const CritterGlow(halo: .6, blur: 1.5, color: '#ffb347'));                     // forces the tuning too
```

The defaults are the house look, so plain `"look": "glow"` is usually all you need. Override only what you need, either in the spec's `glow` object or with `CritterGlow(...)`. Missing knobs keep their defaults.

| knob | default | range | effect (0 = off) |
|---|---|---|---|
| `halo` | 0.35 | 0–1 | how opaque the halo is |
| `blur` | 0.8 | 0–3 | how big the halo is (3% of the widget width × blur) |
| `brightness` | 1 | 1–2 | how much brighter than the critter the halo is; ignored when `color` is set |
| `shading` | 1.5 | 0–1.5 | light-to-dark body shading (0 = flat colour) |
| `gloss` | 0.45 | 0–1.5 | the highlight and the eye glints |
| `shadow` | 1.5 | 0–1.5 | the contact shadow under the feet |
| `color` | none | `#rrggbb` | paints the halo one colour (for example a warm stage light) instead of the critter's own colours |

Tips:
- **Background:** glow reads best on a dark background. The engine draws only the critter, so the stage is up to your app. A top spotlight works well:
  ```dart
  DecoratedBox(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1.1), radius: 1.3,
      colors: [Color(0xff6b5a48), Color(0xff221c18), Color(0xff0e0c0b)], stops: [0, .55, 1])), child: ...)
  ```
- **Performance:** the halo is a Flutter blur (`ImageFiltered`), which costs a little GPU per critter. For long lists of critters, use `halo: 0` or the flat look.
- **Tuning by eye:** `v3/index.html` in the repo has a **Glow** toggle with live sliders for every knob, and it uses the same defaults. Tune it there, then copy the numbers into your JSON.
- **Bad values:** they are safe. Out-of-range numbers are clamped, and an invalid `color` is ignored.

## 7. Limits to know before building on it
- **No animation yet.** `CritterView` is static. Gaits, blinking, petting, dancing and the evolution flash exist in the browser prototype (`v3/index.html`) and are planned for the package. `behaviour` is parsed for that future use.
- **One item per slot.** A critter can't hold a money bag and a gold bar at once.
- **Art comes from the catalog.** New characters need the compiler (section 8); they can't be sent as JSON.
- **Two-headed character 23** (Twinny in the `ember` line): it gets its hat between the heads and its glasses spanning both.

## 8. Adding characters or bundled items (repo maintainers)

```bash
cd compiler && npm install && npm run build   # rebuilds critter_engine/assets/critter_catalog.json
cd ../critter_engine && flutter test           # parity, svg validity, goldens
```

- **New character:** drop `character_NN.svg` (flat paths/circles, eyes and mouth in `#2b2a33`) into `characters/`, then add it to an evolution line in `compiler/items.mjs` under `LINES`. The build warns about any character that isn't in a line.
- **New bundled item:** add it to `HATS`, `NECK`, `PROPS` or `EYEWEAR` in `compiler/items.mjs`, using the same shapes as the JSON items above.
- **Checking the result:** open `compiler/out/gallery.html` to see every character wearing items.
- **Golden images:** if a change is intentional, refresh them with `flutter test --update-goldens test/golden_test.dart`. Goldens are rendered on macOS; on Linux CI either regenerate them there or skip that test.

## Troubleshooting
| Symptom | Cause / fix |
|---|---|
| `pub get` can't clone | The repo is private, or the URL is missing `path: critter_engine`. |
| `The current Dart SDK version is …` | Flutter is too old; upgrade to 3.38 or later. |
| `Binding has not yet been initialized` | `CritterCatalog.load()` was called in `main()` before `WidgetsFlutterBinding.ensureInitialized()`. |
| `Unable to load asset: packages/critter_engine/…` | Stale build after changing the dependency; run `flutter clean && flutter pub get`. |
| Empty box where the critter should be | Unknown `species` id; check it against the table. |
| An item doesn't show | Unknown id, wrong `slot`, or the inline item was rejected (check debug output or the result of `registerItems`). |
| Glow looks washed out or invisible | It's on a light background; glow is designed for dark backgrounds. Lower `halo`, or use the flat look on light screens. |
| Critter looks tiny | It's a form-0 (baby) form, or the widget is narrow. The frame is shared, so scale with the widget width. |
| `FormatException: critter catalog vN is newer than this engine` | The catalog and package versions are out of step; update the package. |
