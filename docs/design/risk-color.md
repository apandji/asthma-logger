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

## Extremes, as a highlight (owner, Oct 21)

Orange also marks extremes, but only as a **highlight**: a translucent highlighter swipe laid *behind* the
stretch of a sparkline, or the word, that is one of yours. The line and the text stay white ink.

- **Tier one, for everyone:** past a bin edge (hot ≥ 90°F, cold ≤ 32°F, humid > 65%, dry < 35%, a drop of
  10°F or more in 3 h) the line goes heavier, against a dashed edge line. Extreme, not yet yours. No orange.
- **Tier two, yours:** past an edge whose level is one of your gated patterns, the same stretch is highlighted.
  A swing gets a bracket, highlighted when sharp drops are yours.
- Before the profile has learned, only tier one shows. The edges are the bins, so a sparkline and Insights never
  disagree about what counts as extreme.
- Pressure has no edge until the `pressure_change` bin exists (WeatherKit pressure history isn't read yet); its
  swing shows dashed and unscored until then.

So orange has one meaning across the app: *this looks like your flare days*. On the forecast it fills an hour,
on a reading or a sparkline it highlights the part that's yours.

## Cold for you (Oct 21, in crit)

On screen it's never "edge" (owner): the card is "Cold, for you" (or "Heat, for you"), the dots mark "from here", and the footnote says "For most people, cold starts at freezing." `PersonalEdge` stays the code name.


`PersonalEdge` (AsthmaCore) finds where *your* flare moments cluster on a reading, e.g. below about 40°F where
the general cold edge is 32°F. It tries cut points every 5°, scores them like the forecast (smoothed log
likelihood ratio, k = 2), and keeps one only if it clears a stricter gate than a fixed bin: 8 flare moments past
it, 20 baselines, raw lift above 1.5, and the same cut (±5°) winning on 60% of 200 random half-splits. Within 5°
of the general edge it says the general one. Data set: Settings › Data sets › "Cold, below about 40°F".

Three ways to say it, under the Weather card (Settings › Design crit › Cold for you):

1. **Sentence with the number:** "Your flare days often came when it was ~~below about 40°F~~" (highlighted).
   The first number outside a reading, so it bends the no-numbers rule.
2. **Words only:** "…on days colder than almost all your usual ones" (highlighted). The share of your baselines
   past the edge picks the words.
3. **The dots it came from:** a tally on a colder → warmer line, flares stacking up, usual days down, the side
   past your edge highlighted. No numbers.

Next, if it holds: your edge on the sparkline (the highlight starts there, not at the general edge), humidity the
same way, and the edge as a level in the rate table so the forecast uses it.

Not yet decided: whether the forecast strip carries the driving family's texture or only the risk ink (A vs
A + D), and whether diverging (B) is worth a test for "quieter than your usual".

## The default (owner, Oct 21)

**A + D is the default.** Families say *which* with icons, names and texture, never hue: the rail's icons and
dots, moment details' family headers and charts, the Insights cards and radar are white ink. Where something is
*yours* (a pattern), it takes the risk ink as a highlight: the rail's pattern dot, the card's star and dot, the
radar's pattern corners, the Insights page wash (warm graphite into orange). The sky's particles and event
washes (smoke, a cold snap) keep the family inks. Today's pink, aqua and yellow survive only as the Today option.

## The sky's dots and washes (owner, Oct 21)

- **Dots are a halftone screen, not a scatter.** An even hex grid turned 12° over the map, like a riso screen.
  Layers take turns cell by cell, so none gathers anywhere; how much is in the air is the dot's size. Nothing in
  the dots says *where*.
- **Colour follows "yours".** Plain ink (white on black paper) for how much is in the air; orange for a layer
  that's one of your patterns right now, full for "often", paler for "sometimes". The reading's label and its
  amount dots follow the same rule.
- **Washes the same way.** Holding Weather: a faint white wash by how far from mild, orange when this weather is
  yours. Events (smoke, a sharp drop, a storm) darken the page to graphite for everyone, warmer with orange only
  when that event is one of yours.
- **Before felt air has learned, nothing is yours,** so there's no orange in the sky: ink sized by how much is in
  the air, against the general edges (tier one). Orange arrives with the first gated pattern, the same moment
  the Insights ring completes. Nothing leans orange before it's earned.

## On the phone (Oct 21)

Settings › Demo and development › What we're testing › C1 "How should risk be coloured?":

- **Today:** green, gold, red.
- **A · One warm ink:** graphite → orange → bright orange. Air levels (good / OK / not good) go white.
- **A + D · Warm ink + texture:** A, and each forecast hour's marks take the driving family's shape: bars
  weather, dots pollutants, crosses allergens, slashes exercise, rings colds.
- **C · Coverage, no hue:** a grey ramp to paper white, and one, two or four marks an hour by how much it looks
  like your flare days. Air levels go white.
- **E · Two palettes:** families move to cool hues (blue weather, teal pollutants, green allergens, violet
  exercise, indigo colds), risk is a warm status scale (grey, amber, red).

Quickest: Demo and development › Loadouts › Risk colour, one row per option. Each loads "Still learning", forces
the ring to learned (a staged rough afternoon) and lands on tomorrow at 2 PM.

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
