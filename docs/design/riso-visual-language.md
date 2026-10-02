# Riso visual language

The design spec for the simpler, riso-printed interface. The interactive sketch is `riso-sketch.html` in this folder: open it in a browser, or see the published copy at https://claude.ai/artifact/DgYHmNmWjqhRXD7WjDn8v3 (private to the owner). Inspiration: Giorgia Lupi's data humanism, especially *Bruises*. Every data point is a hand-made mark, there's always a key, and the human context sits beside the numbers.

## The idea

Riso printing works the way our data does:

| Riso | Encodes |
|---|---|
| One ink per layer | One signal family per ink |
| Overprint (inks overlap and darken) | Conditions happening together, which is what lift measures |
| Misregistration (layers out of alignment) | Uncertainty: a far or modeled reading prints off-register |
| Grain / halftone | Texture per ink, so identity never depends on colour alone |
| Paper | Light theme ground; the dark theme is "night stock" |

## Inks (validated with the dataviz palette checker)

| Ink | Signal | Texture | Paper (light) | Night (dark) |
|---|---|---|---|---|
| Pink | Air: max(ozone band, PM2.5 band) | Halftone dots | `#F0447A` | `#E0457A` |
| Blue | Weather: hot → 3, humid/dry → 2, else 1 | Horizontal lines | `#1F5FB8` | `#3A7FD0` |
| Yellow | Pollen (after Ambee) | 45° hatch | `#C99400` | `#B38E28` |

Surfaces: paper `#EEECE6` / `#E3E0D8`; night `#141418` / `#1E1E25`. Key ink (text, cores): `#1B1A1F` / `#EDEAE3`.
Overprint blend: **multiply** on paper, **screen** on night. Each ink shape = flat fill at 55% + its texture at 100%.
Yellow is below 3:1 contrast on paper, so it always appears with its hatch and a text label.

## The mark (one log)

- **Core:** solid dot = puff; open ring = usual moment. Key ink, always on top, never blended.
- **Air disc (pink):** radius 5.5 / 9 / 13 pt for low / moderate / high.
- **Weather ellipse (blue):** rx 6 / 9.5 / 13 pt (× 1.15 wide, × 0.72 tall).
- **Misregistration:** air layer offset = min(4.5, 0.6 + stationKm / 4.5) pt along a per-log angle; weather (modeled) offset 0.8 pt the other way. Regional (> 16 km) visibly drifts.
- **Indoor frame:** a thin rounded square (32 pt) in soft ink when indoors (guessed or confirmed).
- Glyph geometry belongs in `AsthmaCore` as a pure `GlyphSpec` (layers, radii, offsets) with tests; SwiftUI only draws it.

## Capture model

- **Puffs come from the inhaler** (a smart-inhaler sensor). A small floating **puff** button is only the manual fallback.
- **"I'm okay" moments are sampled automatically**, about five a day at random times: place, time, outdoor air. These are the usual moments puffs are compared with. Nothing is asked of the user.

## Screens

**Journal: today's portrait + the moment's context**
- Header: "Today" (or the weekday when browsing history), eyebrow "Thu, Oct 2 · 2 puffs · 5 okay", gear.
- **Day portrait** (main visual, Lupi-style radial): angle = time of day (midnight at top, clockwise); **ring = place** (inner home, middle work, outer out); a thin key-ink **thread** joins the day's moments in order (your path). Okay moments print first as rings; puffs print on top as solid dots at 1.25× scale. Today shows a "now" hand and a dotted arc for hours not yet lived. A one-line legend sits under it; the full key is a "How to read a day" disclosure.
- **Moment card** (the screen's main job): tap a mark to select it; the default is today's latest puff. It shows:
  - time · "Puff · from your inhaler" or "I'm okay · sampled automatically";
  - the place name, probably indoors/outdoors · motion, and a one-tap correction;
  - **Since** the previous okay moment today: ozone, temp and humidity as "a → b" with up/down;
  - for puffs, a **note box**: a voice-note transcript (or a "Record a note" button), plus closed-list tag chips. Suggested tags are dashed with a "?" and count only once confirmed;
  - "Sources for this moment" (the honesty lines), collapsed.
- **Earlier**: past days as postcard-sized mini portraits (3 columns, newest first) with "2 puffs". Tapping one loads it into the main portrait and scrolls to top.
- **FAB**: 60 pt, bottom-right above the tab bar, printed pink over offset blue, label "puff".

**Insights**
- One headline in the chosen voice (Settings slider), the caveat, and a small source line.
- Driver chips from **gated** rows only (top 4). Selecting one re-inks the unit fields.
- Unit fields: one mark per puff (4 columns) and per okay moment (10 columns); marks without the selected condition fade to 22%. Counts above each field ("8 of 10 puffs with ozone high").
- Looking ahead: 3 day strips on the same hour axis; elevated windows printed in the inks of their drivers (ozone → pink dots, heat → blue lines), overprinting where both apply. Later days print slightly off-register (less certain).
- "How we know" disclosure with the evidence table (counts, lift, Pattern / Not enough yet).

**Settings sheet:** insight voice slider (clinical → plain → poetic), model toggle, Health, usual moments, demo data. The theme follows the system.

## Rules that still apply

- Marks only encode values the rate table or observation actually has: no invented numbers, and pollen stays absent until a source exists.
- Text uses text ink, never an ink colour. Ink is for marks.
- Every mark is tappable down to its sources (honesty contract).
- Respect Reduce Motion; grain is static.
