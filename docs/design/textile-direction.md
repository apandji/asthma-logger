# Textile direction (possible)

A possible direction for felt air's look, layered on the agreed [visual style](visual-style.md): **stitches and fabric for brand moments and data; stock iOS for everything else.** Not decided; the owner asked to explore it on 2026-10-03.

Mockups: [`textile-mockups.html`](textile-mockups.html) (open in a browser; nine screens, light and dark). Rendered copy: [`../gallery/mockups/textile-mockups.jpg`](../gallery/mockups/textile-mockups.jpg).

Inspiration: a creative-coding text editor by abhinav.m.n where "everything is yarn": typed letters appear as cross-stitch on linen, knit and wool, and threads run between letters. We draw our own stitches; don't reuse that work's assets or code, and credit it if we ship something close.

## Why it fits

- **The name.** Felt is a textile. Fabric is tactile, which matches the team's "embodied self, not quantified self" stance.
- **Cross-stitch is counting.** It's worked square by square on a grid. Our honesty rule is "two plain counts, never a ratio", so "8 of the 10 times" becomes ten stitches with eight in pink thread.
- **A thread through the day.** A running stitch joins a day's moments in order, the "thread" idea from the riso spec made literal.
- **Shape carries meaning**, so nothing depends on colour alone (the riso spec solved this with textures).

## Stitch vocabulary

| Mark | Stitch | Notes |
|---|---|---|
| Used inhaler | Cross-stitch (×), ink thread | One per use. Up to three shown in small spaces. |
| I'm okay moment | French knot (○), ink thread | Smaller and quieter than a cross. |
| Air stood out | Backstitch underline, pink | Same "stood out" rule as visual-style.md → Marks. |
| Weather stood out | Backstitch underline, blue | |
| Pollen stood out | Backstitch underline, yellow | Later, once a pollen source exists. |
| Order of the day | Running stitch, pale thread | Joins moments left to right. |
| Forecast | Dashed outline or dashed thread | Not yet lived. Further out = fainter. |
| Counted, nothing stood out | Pale stitch | Keeps the count visible. |

Inks are the visual-style.md pink and blue. Thread for marks is the "ink" colour (near-black on linen, warm white on knit), never the text colour.

## Fabrics

| Mode | Fabric | Use |
|---|---|---|
| Light | Linen, warm off-white `#EFE8DA` with a faint weave | Hero areas: onboarding, top of Journal, Recap, history sampler |
| Dark | Knit, near-black `#1F1D22` with a faint weave | Same areas in dark mode |

The weave stays very faint (about 5% contrast) so text on it stays readable. With Reduce Transparency, fabric becomes flat paper/night colour. A running-stitch **hem** marks where fabric ends and the standard iOS list begins.

## Where it appears

| Screen | Textile | Stays stock iOS |
|---|---|---|
| Onboarding | Full linen; cross-stitched "felt air" wordmark; one New York sentence; a loose thread | The button and page dots |
| Journal | Linen hero with the week strip as fabric swatches (crosses, knots, underlines); the New York headline; a hem | The day log: tinted Air / Weather cards, Moments rows (with a small stitch glyph), floating log button, tab bar |
| Logging (after one tap) | A large cross being stitched, with needle and thread, on a linen panel | The sheet, "Anything going on?" chips, Done |
| Moment detail | A linen swatch: this moment's cross joined by thread to the previous one | Everything else: What / Where, outdoor conditions with full provenance, notes |
| Recap | Full linen; counts as a stitched sampler: 10 crosses for inhaler times, underlined in pink / blue where a condition was present; 24 knots for usual days | The pill, the floating button, the caveat |
| History (calendar button) | A 5-week sampler: each day a swatch with up to 3 crosses or a knot, plus underlines; today outlined in pink | Navigation and the key |
| Looking ahead | Each day a strip of fabric; windows as dashed stitch outlines in the ink of their condition | The detail card and its counts |

Never stitched: body text, numbers, lists, Settings, permission screens, controls. The stitched wordmark is decorative (accessibility label "felt air").

## Motion and feel

- **On log:** the second leg of the cross stitches in (about 0.4 s), with a light two-tick haptic like a needle passing through. Off with Reduce Motion: the cross simply appears.
- **No looping animation**, no moving fabric.

## Building it (if chosen)

- **Geometry in AsthmaCore:** a `StitchSpec` (kind, position, size, slight random tilt from a stable seed per moment, which underlines) beside the planned `GlyphSpec`, with tests. Same "stood out" rule.
- **Drawing in SwiftUI:** each stitch is two short rounded strokes plus a thin highlight in a `Canvas`. The fabric is a faint tiled image or a small shader. The stitch-in animation is a `trim` on the second stroke.
- **Order:** the Recap sampler first (it carries the honesty rule), then the Journal week strip, then onboarding.

## Risks

- **Gimmick.** One material, used sparingly. If a screen doesn't carry data or brand, it stays plain.
- **Legibility.** Stitched letters only at display size. Weave contrast stays low.
- **Performance.** Draw stitches once per data change, not per frame.
- **Originality.** Our own drawing; credit the inspiration if we ship something close.
