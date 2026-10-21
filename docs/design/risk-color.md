# Risk colour

Oct 21, 2026. How felt air shows risk (how much an hour looks like your flare days) without colour doing two
jobs. The study page with the five directions, the colour-blind toggle and the scorecards is a private
artifact ("Risk Colour Study"); this file keeps what it found and what was decided.

## What was wrong (palette validator, black paper)

- Flare red and baseline green: ΔE 3.0 under deuteranopia (target 8). The forecast's two ends collapse for
  about 1 in 12 men.
- Flare red and Weather pink: ΔE 11.9 with normal vision (floor 15). Risk and "which family" share a hue.
- Green, gold, red isn't ordinal: gold is the lightest (L 0.65, 0.79, 0.66), so it doesn't read as "more" in
  grayscale. Gold also sits next to Allergens yellow.
- Five families can't be told apart by hue alone where any two can touch (radar, sky): the best five-hue set
  bottoms out at ΔE 2.0. Hue can carry three at most. Family identity has to come from icon, name, position or
  texture.

## Directions studied

A one warm ink for risk · B diverging around your usual (blue / orange) · C coverage, not hue ·
D texture for family, ink for risk · E two separate palettes (fails: families ΔE 2).

## Decided (owner, Oct 21)

- **Risk keeps three steps:** looks like your baseline days · a bit like your flare days · looks more like
  your flare days. Plus "not enough moments yet", which is no ink at all.
- **Risk is one warm ink, orange, and nothing else is warm.** Validated ordinal ramp on black: `#3A332C`
  (baseline-like, graphite: no ink), `#C46016` (a bit like), `#FF9D36` (looks more like). One hue (17°
  spread), lightness climbs, every ordinal check passes. Orange is urgent enough; red retires.
- **Families stop competing for hue.** Icons and names everywhere; a riso texture where a mark has to say which
  family drives it (direction D: lines for weather, dots for pollutants, crosses for allergens, hatching for
  exercise, rings for colds). Family inks may stay as particles in the sky, where they never sit next to a
  risk mark.
- **Five-second test, yes.** Below.

Not yet decided: whether the forecast strip carries the driving family's texture or only the risk ink (A vs
A + D), and whether diverging (B) is worth a test for "quieter than your usual".

## Five-second test

- Five people from the TestFlight group; one with red-green colour blindness if we can find them.
- Show tomorrow's forecast strip in Today, A, A + D and B, one at a time, five seconds each, order shuffled per
  person.
- Ask: "Which hour would you skip a run?" then "What does the colour mean?" Note whether they pick the peak
  window (noon to 2 PM in the sample) and whether they read colour as *your* pattern or as air quality.
- Pass: four of five pick the peak window in A or A + D, and nobody reads orange as "the air is bad for
  everyone".

## What changes in the app if A + D holds

- `Verdict` (green / gold / red) becomes the three-step orange ramp; the pill keeps its words.
- The timeline's forecast strip uses the ramp; the driving family's texture rides on top (A + D).
- Insights: the radar's family colours give way to white ink plus texture; the strength bars take the ramp.
- The rail and the sky keep family icons; particles may keep family inks.
- `print-inks-palette` memory and design-system.md get updated once this ships.
