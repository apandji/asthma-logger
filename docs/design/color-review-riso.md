# Colour review: printing felt air in RISO inks

Oct 18, 2026. A review of every colour on screen against the risograph idea (riso-visual-language.md):
**a few spot inks, overprinted on paper, colour only for the air.** With a proposal, already switchable on
the phone: Settings › Demo and development › Demo › **Inks: RISO inks / Current** (RISO is the default now).
Hex values are the RISO ink colours as print studios publish them for screen; check them against a printed
swatch book before anything goes to print.

## What's on screen today, and where it drifts

| Role | Today | Problem against riso |
|---|---|---|
| Sky base (temperature) | 7 hand-mixed stops, blue → sage → gold → red | Screen colours, not inks. The sage and the gold are muddy mixes no drum would print. |
| Hour light | Indigo night, rose dusk mixed in | Fine as an overprint idea, but it's mixed in software, so night skies all turn the same lavender-grey. |
| Pollutant layers | Slate, sand, rust, icy cyan | Ice cyan (ozone) is the only clean colour; slate and sand vanish on linen. |
| Pollen layers | Green, gold, violet | Close to Green / Sunflower / Violet; good. |
| Verdict | Green / yellow / coral red | Three more greens and yellows that compete with the pollen green and grass gold. |
| Moments | Rescue orange, Standard blue | Good: they map to Orange and Blue. |
| Symptom words | Dusty rose | Too close to Bright Red; reads as a warning. |
| Chrome | Glass and system grey | Right: no colour in chrome. |

Three overall findings:
1. **Too many near-duplicates.** There are about five greens and four yellows, so green means "tree pollen", "mild", "good air" and
   "baseline" at once. Riso forces a small set; we should too.
2. **Light mode was never designed.** The linen paper switch faded to black and lost the header. It's fixed now
   (Settings › Display › Appearance), but the layer inks were picked for black, and on paper slate and sand
   disappear. Riso inks were made for paper, so they hold up.
3. **No overprint.** Real riso gets its third and fourth colours from two inks crossing (blue over yellow
   reads green). We alpha-blend. On linen the particles should *multiply*; that's the next step.

## The proposal: eleven inks

| Ink | Hex | Used for |
|---|---|---|
| Medium Blue | #3255A4 | Cold (30°F) |
| Aqua | #5EC8E5 | Cool (45°F), ozone |
| Teal | #00838A | Fresh (55°F) |
| Kelly Green | #67B346 | Mild (63°F) |
| Sunflower | #FFB511 | Warm (70°F), grass pollen |
| Orange | #FF6C2F | Hot-ish (78°F), the Rescue moment |
| Bright Red | #F15060 | Hot (88°F), "Matches your flare days" |
| Green | #00A95C | Tree pollen, "Looks like your baseline" |
| Yellow | #FFE800 | "A bit like your flare days" |
| Violet | #9D7AD2 | Weed pollen |
| Slate · Flat Gold · Brick | #5E695E · #BB8B41 · #A75154 | Fine particles · coarse dust · NO₂ |

Rules that come with it:
- **Verdict inks are the only full-strength yellow and red.** Temperature tops out at Bright Red only at 88°F+,
  where a hot day *should* feel like a warning.
- **Pollen keeps its own three** (Green, Sunflower, Violet), the same family as the rail's Allergens.
- **Moments stay Orange and Blue** (the felt button caps).
- **Chrome stays ink-less**: glass, black or linen, and system grey.

## Next, if the RISO inks hold up

- Overprint on linen: draw the particles with a multiply blend so Aqua over Sunflower reads green, like a
  two-drum print.
- A slight misregistration on the layers (1–2 pt offset per ink) on linen only.
- Retire the duplicate greens: the Theme's ink3 "quiet" green and the weave inks, unused on the Now home.
- Pick a symptom ink that isn't red-adjacent (Purple #765BA7 or Federal Blue #3D5588), so "what you felt"
  never reads as an alarm.

Try it: Settings › Display › Appearance › Light, then Demo › Inks › RISO inks vs Current, on the
"Allergen-led" or "Hot, hazy days" data set.
