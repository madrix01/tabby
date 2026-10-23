---
name: critter-backend
description: Backend contract for the critter pets rendered by the critter_engine Flutter app (github.com/madrix01/tabby). Use when building, validating or reviewing any JSON a backend sends to the frontend about critters/blobs/pets — the critter spec (species, form/evolution stage, xp, attachments, mood incl. empty_wallet, look/glow), custom item definitions (hats, eyewear, neck items, props as SVG), the item store list, or the money transfer (send money) payload — and when you need the valid slugs for species, forms, items, moods or looks, or the xp-to-level/evolution math.
---

# Critter backend contract

The Flutter app (package `critter_engine`) draws a critter entirely from JSON the backend sends. This skill is the contract for that JSON: every payload type, every field, and every valid slug.

`critter_payload.schema.json`, next to this file, is a JSON Schema (draft 2020-12) generated from the app's own catalog. Validate outgoing payloads against it in tests or CI. When the catalog changes, regenerate it with `cd compiler && npm run build`; don't hand-edit it.

## The rules that matter most
1. **Send ids, not art.** For a bundled item, send its slug (`"hat": "crown"`). Send SVG only for items the app doesn't ship (section 3).
2. **The server owns `form`.** `form` is the evolution stage. Compute it on the server (section 6) and send it. The app never evolves a critter by itself.
3. **Types are strict.** Numbers must be JSON numbers and strings must be strings. `"form": "2"` makes the app throw while parsing.
4. **Values are tolerant.** An unknown species renders nothing, unknown item ids and mood values are skipped, an out-of-range form is clamped, and out-of-range glow numbers are clamped. A typo won't crash the app, but the thing simply won't show, so validate against the schema.
5. **Unknown keys are ignored.** You can add fields for your own use without breaking older apps.

## 1. Payload types

| # | Payload | Used for | Schema `$defs` |
|---|---|---|---|
| A | **Critter spec** | One critter, shown anywhere in the app | `critterSpec` (also the schema root) |
| B | **Item definition** | A custom hat, eyewear, neck item or prop that isn't bundled | `item` |
| C | **Item list** | An item store sent once and registered for every critter | `itemList` |
| D | **Money transfer** | The send-money animation between two critters | `moneyTransfer` |

There is no envelope or `type` field in the contract. The endpoint decides which payload it is. If one channel carries several types, wrap them yourself, for example `{ "type": "money_transfer", "data": { … } }`.

## 2. Critter spec (A)

```json
{
  "v": 1,
  "species": "pip",
  "form": 2,
  "xp": 620,
  "attachments": { "hat": "crown", "eyes": "shades", "neck": "gold_chain", "prop": "money_bag" },
  "mood": "happy",
  "look": "glow",
  "glow": { "halo": 0.35, "blur": 0.8, "brightness": 1, "shading": 1.5, "gloss": 0.45, "shadow": 1.5 },
  "behaviour": { "likesPets": true, "gait": "waddle", "state": "idle" },
  "items": []
}
```

| field | type | required | default | rules |
|---|---|---|---|---|
| `v` | int | no | | Always `1` for now. |
| `species` | string | **yes** | | One of the species slugs in section 4. |
| `form` | int | no | `0` | Stage index, from 0 to forms−1 of that species (section 4). |
| `xp` | number | no | | Grows the critter slightly within its current form. It does **not** change the form. |
| `attachments` | object | no | `{}` | Keys are `hat`, `eyes`, `neck`, `prop`; each value is an item slug (section 5) or the id of an item in `items`. Leave a key out for an empty slot. |
| `mood` | string | no | none | `happy`, `sad`, `food`, `entertainment`, `travel`, `shopping` or `empty_wallet`. Leave it out for the critter's normal face. |
| `look` | string | no | `flat` | `flat` or `glow`. |
| `glow` | object | no | the defaults above | Only applies when `look` is `glow`. Send only the knobs you want to change (section 7). |
| `behaviour` | object | no | as shown | Reserved for animation. `likesPets` is a bool, and `gait` and `state` are strings. Carried through but not rendered yet. |
| `items` | array | no | `[]` | Inline custom item definitions (B). |

Smallest valid payload: `{ "species": "blip" }`.

## 3. Custom item definition (B) and item list (C)

The app places any item on any of its 46 characters automatically, from that character's measured eyes, head and neck. Never send per-character positions.

```json
{ "id": "viking", "slot": "hat",  "anchor": [50, 60], "svg": "<path d='M10 60 Q10 20 50 20 Q90 20 90 60Z' fill='#9aa0a6'/>" }
{ "id": "scarf",  "slot": "neck", "anchor": [50, 0], "fit": 0.8, "height": 40, "svg": "<path d='M0 0 Q50 22 100 0 L100 12 Q50 34 0 12Z' fill='#e8494b'/>" }
{ "id": "rock",   "slot": "prop", "anchor": [0, 0], "svg": "<path d='M0 0 Q4 -26 24 -28 Q46 -26 48 0Z' fill='#9aa0a6'/>" }
{ "id": "visor",  "slot": "eyes", "lens": "<rect x='-12' y='-6' width='24' height='12' rx='6' fill='#3a85f2'/>", "grow": 1.3, "bridge": "#3a85f2", "strap": "#2b2a33" }
```

| slot | required | optional | how to draw |
|---|---|---|---|
| `hat` | `id`, `svg`, `anchor` | | About 100 units wide. `anchor` is the bottom-centre of the brim, which sits on the head. |
| `neck` | `id`, `svg`, `anchor` | `fit` (0.05–2, default 0.5), `height` (1–400, default 40) | About 100 wide. `anchor` is the top-centre, which sits under the mouth. `fit` is the width as a fraction of the neck. |
| `prop` | `id`, `svg`, `anchor` | | `anchor` is the bottom-left corner. The prop stands on the ground to the right of the feet; draw it upwards, with negative y. |
| `eyes` | `id`, `lens` | `lensRight`, `grow` (0.3–3, default 1.15), `bridge` (#hex, default `#2b2a33`), `strap` (#hex) | One lens centred on (0,0) at radius 10. It is copied onto each eye and scaled to that eye. `lensRight` gives the right eye a different lens, as in 3D glasses. |

**SVG rules.** The app enforces these and drops any item that breaks them:
- **Allowed tags:** `path`, `circle`, `ellipse`, `rect`, `polygon`, `polyline`, `line` and `g`.
- **Forbidden anywhere in the string:** `href`, `url(`, `style`, `<!`, `<?` and `javascript:`. That means no `<image>`, no gradients, no CSS and no entities.
- **No `<text>`:** draw letters and symbols such as "₹" or "$" as paths.
- **Colours** in `bridge` and `strap` must be `#rgb` or `#rrggbb`. In SVG, use presentation attributes such as `fill="#e8494b"` and `stroke-width="3"`.
- **Size:** at most 50,000 characters per SVG string.

**Where the id is looked up.** An id in `attachments` is resolved against the spec's own `items` first, then registered items (C), then bundled items. So an inline item can reskin a bundled one by reusing its id, for example a custom `money_bag`.

**Item list (C)** is a plain JSON array of item definitions. The app calls `registerItems(list)` once, after which every spec can reference those ids. Invalid entries are rejected one by one, with a reason, and the valid ones are still registered.

## 4. Species slugs and evolution stages

Each species is an evolution line. `form` is the index into its stages.

| `species` | form 0 | form 1 | form 2 | form 3 | max `form` |
|---|---|---|---|---|---|
| `blip` | Blip | Cloudbert (Lv 4) | Blobfred (Lv 8) | | 2 |
| `totem` | Totem | Cubey (Lv 4) | Jellyfin (Lv 8) | | 2 |
| `sprig` | Sprig | Antenna (Lv 4) | Broccolord (Lv 8) | | 2 |
| `radish` | Radish | Mossy (Lv 6) | | | 1 |
| `pip` | Pip | Bean (Lv 4) | Tri (Lv 8) | | 2 |
| `ember` | Ember | Twinny (Lv 4) | Archie (Lv 8) | | 2 |
| `pinky` | Pinky | Fluffpaw (Lv 4) | Hornsby (Lv 8) | | 2 |
| `bunbun` | Bunbun | Kitto (Lv 4) | Piggo (Lv 8) | | 2 |
| `stamp` | Stamp | Longcat (Lv 6) | | | 1 |
| `squidge` | Squidge | Beaky (Lv 3) | Mush (Lv 6) | Donut (Lv 10) | 3 |
| `snowy` | Snowy | Pebble (Lv 6) | | | 1 |
| `cactoo` | Cactoo | Splotch (Lv 4) | Teapot (Lv 8) | | 2 |
| `drip` | Drip | Chick (Lv 4) | Ducko (Lv 8) | | 2 |
| `lemon` | Lemon | Bunny (Lv 4) | Sunny (Lv 8) | | 2 |
| `mochi` | Mochi | Mochiko (Lv 4) | Mochimaru (Lv 8) | | 2 |
| `nimbo` | Nimbo | Cumulo (Lv 4) | Seraphluff (Lv 8) | | 2 |

Form 0 is always unlocked at level 1. The display names (Blip, Cloudbert…) are what the app shows. Don't send them; the app derives them from `species` and `form`.

Source art files, for designers: `blip` 13 → 25 → 01 · `totem` 34 → 11 → 29 · `sprig` 02 → 17 → 16 · `radish` 32 → 36 · `pip` 28 → 03 → 15 · `ember` 37 → 23 → 08 · `pinky` 18 → 04 → 39 · `bunbun` 05 → 35 → 21 · `stamp` 30 → 20 · `squidge` 24 → 06 → 10 → 27 · `snowy` 19 → 07 · `cactoo` 09 → 14 → 38 · `drip` 33 → 31 → 26 · `lemon` 40 → 12 → 22 · `mochi` 41 → 43 → 44 · `nimbo` 42 → 45 → 46 (`characters/character_NN.svg`; 41–46 are drawn by `characters/make_extra.py`). `docs/evolution_sheet.svg` shows every line.

## 5. Item slugs (bundled)

| slot | slugs |
|---|---|
| `hat` | `top_hat`, `party`, `crown`, `cap`, `beanie`, `chef` |
| `eyes` | `goggles`, `shades`, `round`, `hearts`, `three_d` |
| `neck` | `bow_tie`, `gold_chain`, `medal` |
| `prop` | `gold_bar`, `gold_stack`, `money_bag`, `coffee` |

One item per slot: a critter can't hold two props at once.

### Moods
| `mood` | what the app shows |
|---|---|
| `happy` | grin, cheeks |
| `sad` | frown, worried brows, tear, rain cloud above the head |
| `food` | chewing mouth, burger thought bubble |
| `entertainment` | grin, red and blue `three_d` glasses (these **replace** the spec's `eyes`), popcorn bubble |
| `travel` | smile, plane bubble, suitcase on the ground |
| `shopping` | excited open mouth, shopping-bag bubble, shopping bags on the ground |
| `empty_wallet` | sad face (frown, brows, tear; no rain cloud), an empty wallet held upside down, a red `₹0` thought bubble. Use it for zero or insufficient balance. |

## 6. XP, levels and evolution (server-side)

The app uses this curve. Use the same one on the server so the level numbers match what users see:

```
level(xp)     = 1 + floor((xp / 30) ^ (1 / 1.5) + 1e-9)
xpForLevel(L) = 30 * (L - 1) ^ 1.5
form          = last stage index whose unlock level <= level(xp)
```

| level | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| xp needed (rounded up) | 30 | 85 | 156 | 240 | 336 | 441 | 556 | 679 | 810 |

Evolution thresholds: Lv 4 is **156** xp, Lv 8 is **556**, Lv 6 is **336**, Lv 3 is **85** and Lv 10 is **810**.

```python
import math
UNLOCKS = {"squidge": [1, 3, 6, 10], "radish": [1, 6], "stamp": [1, 6], "snowy": [1, 6]}   # every other species: [1, 4, 8]
def level(xp): return 1 + math.floor((max(0, xp) / 30) ** (1 / 1.5) + 1e-9)
def form_for(species, xp):
    lv = level(xp)
    return max(i for i, at in enumerate(UNLOCKS.get(species, [1, 4, 8])) if at <= lv)
```

When a user's xp crosses a threshold, send the new `form`. The app currently just renders the new stage. The planned evolution animation will play when `form` goes up compared with what the app last showed, so make sure you always send the current form.

## 7. Glow tuning

Only applies with `"look": "glow"`. Every knob is optional, and a missing knob keeps its default.

| knob | default | range | effect (0 = off) |
|---|---|---|---|
| `halo` | 0.35 | 0–1 | halo opacity |
| `blur` | 0.8 | 0–3 | halo size |
| `brightness` | 1 | 1–2 | halo brightness; ignored when `color` is set |
| `shading` | 1.5 | 0–1.5 | body shading |
| `gloss` | 0.45 | 0–1.5 | highlight and eye glints |
| `shadow` | 1.5 | 0–1.5 | contact shadow |
| `color` | none | `#rrggbb` | tints the halo |

## 8. Money transfer (D)

```json
{
  "amount": 5000,
  "currencySymbol": "₹",
  "from": { "species": "squidge", "form": 3, "attachments": { "hat": "crown", "neck": "gold_chain" } },
  "to":   { "species": "drip", "form": 2, "attachments": { "hat": "cap", "eyes": "round" } }
}
```

| field | type | required | rules |
|---|---|---|---|
| `amount` | number | **yes** | Greater than 0, in rupees. The app formats it with Indian digit grouping (`-₹5,000` / `+₹5,000`) and sends more notes for bigger amounts. |
| `currencySymbol` | string | no | Default `₹`. |
| `from`, `to` | critter spec | **yes** | Full specs (A). Any `mood` in them is ignored: both start with their normal face and turn happy when the money lands. |

- **When to send it:** send this only once the payment has succeeded. The animation always ends happily, and there is no failure version yet.
- **Replay:** to play it again, the app uses a new widget key, typically the transaction id.

## 9. Backend checklist
- [ ] Validate every outgoing payload against `critter_payload.schema.json` in CI.
- [ ] `form` is computed on the server with the curve in section 6, and stays within the species' max form.
- [ ] Every attachment id is either a bundled slug (section 5) or defined in `items` or the registered item store.
- [ ] Custom item SVG follows the rules in section 3; lint it before storing.
- [ ] Numbers are sent as numbers. Omit optional fields rather than sending `null`.
- [ ] Money transfer payloads are sent only after the payment has succeeded.
