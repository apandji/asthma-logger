# Visual style: Apple-native, with ink for data

The app is called **felt air**.

The design spec for the iOS app's look. Mockups: [`visual-style-mockups.html`](visual-style-mockups.html) (open in a browser; Journal and Recap in light and dark). This refines the [riso visual language](riso-visual-language.md): it keeps the riso inks and the overprint idea for data, and drops the paper texture, grain, misregistration and custom type.

> **Possible direction:** [textile-direction.md](textile-direction.md) adds stitches and fabric for brand moments and data on top of this spec. Not decided.

## The idea

The app should feel like it shipped with the iPhone. Layout, type, controls and colours are stock iOS, following Apple Health most closely: the Journal borrows Cycle Tracking's week strip and tinted log, and the check-in borrows State of Mind. Two things are ours:

1. **One New York sentence per screen.** The headline that says what matters is set in Apple's serif. Everything else is SF.
2. **Ink for data.** Conditions print as soft, see-through discs in a few inks that overlap where conditions happened together. Ink is only for data, never for text or chrome (apart from the one primary button and the active tab).

Light and dark both follow the system setting.

## Type

| Role | Font | SwiftUI | Notes |
|---|---|---|---|
| Headline sentence (one per screen) | New York, medium | `.font(.system(.title, design: .serif, weight: .medium))` | Never bold. Condition words are tinted in their ink. |
| Eyebrow | SF, 13 pt semibold, uppercase, secondary | `.font(.footnote.weight(.semibold)).textCase(.uppercase)` | Often the start of the headline: "Of the 10 times you used your inhaler" → "ozone was high 8 times". |
| Card titles, row titles | SF semibold | `.headline` / `.subheadline.weight(.semibold)` | |
| Body, detail | SF regular, secondary | `.subheadline`, `.footnote` | |
| Numbers in comparisons | SF semibold | `.monospacedDigit()` | |

All text uses Dynamic Type styles, no fixed sizes. Only system fonts; nothing to bundle.

## Colour tokens

All in `ios/AsthmaLog/Theme/`. Surfaces and text are system colours so they track iOS; inks are ours.

| Token | Light | Dark | Use |
|---|---|---|---|
| background | `systemGroupedBackground` (#F2F2F7) | (#000000) | Screen |
| card | `secondarySystemGroupedBackground` (#FFFFFF) | (#1C1C1E) | Cards, pills |
| text / secondary / tertiary | `label` / `secondaryLabel` / `tertiaryLabel` | | Text only |
| track | `systemFill`-like (#E9E9EE) | (#2C2C2E) | Empty days, bar tracks |
| **air** (pink) | #E8336D | #FF4F86 | Air ink, primary button, active tab |
| **weather** (blue) | #1F6FD1 | #4C9BFF | Weather ink |
| **pollen** (yellow) | #C99400 | #E6B428 | Reserved. Not drawn until a pollen source exists. |
| ink fill | air 28% · weather 26% | air 38% · weather 36% | Disc opacity |
| overprint | `.blendMode(.multiply)` | `.blendMode(.screen)` | Where discs overlap |

Text on a tinted word uses the ink at full strength. Ink colours are never the only signal: every inked thing also has a word (legend, label or chip).

## Marks

One mark per moment. Pure geometry lives in `AsthmaCore` (a `GlyphSpec`: core kind, which inks, disc radii and offsets), with tests. SwiftUI only draws it.

- **Core**, always on top, never blended: a solid dot = used inhaler; an open ring = I'm okay.
- **Discs**, at most three, one per ink family:

| Ink | Family | Drawn from |
|---|---|---|
| Pink | Air | Highest of ozone, PM2.5, smoke signs |
| Blue | Weather | Heat, humidity, cold, heat alert |
| Yellow | Pollen | Later, once a source exists |

- **Only ink what stood out.** Before the sample gate (no personal pattern yet), "stood out" means a high level (the cold-start hazards: high ozone / PM2.5 / pollen, heat alert, freezing, smoke). After the gate, it means a level that is a gated driver in the person's rate table. Ordinary moments print as a bare dot or ring. This keeps most marks quiet and makes overlap meaningful.
- **Size:** moderate = 0.75× radius, high (or a driver's level) = 1×.
- **Overlap:** discs sit slightly offset (air up-left, weather down-right) so two inks always show an overlap zone. Three discs (with pollen) stay readable; there is never a fourth.
- **Never inked:** time of day, season, place, indoor/outdoor, journal tags. Time is position; the rest is text on the moment.
- **Forecast marks** (anything that hasn't happened yet) use a dashed outline and lighter fill, like predicted days in Cycle Tracking. Further out = lighter.
- **Small dots** stand in for discs where space is tight (the week strip): one dot per family that stood out, same inks, same rules.
- Every mark taps through to its moment and sources (honesty contract).

## Screens

### Journal

Modeled on Health's Cycle Tracking: a week of day capsules on top, the selected day's log below.

1. **Nav bar**: settings button (left), "Journal" (centre), calendar button (right) that opens the history (Last 5 weeks grid, below).
2. **Day title**: "Today, October 1" (or the selected day), with a small pointer above that day's letter in the strip.
3. **Week strip**: one tall capsule (track colour) per day, scrolling sideways, today centred.
   - Inside each capsule: a filled circle (text colour) with the number of inhaler uses, larger on the selected day; an open ring if the day only has I'm okay moments; empty if nothing was logged.
   - Under it, **small ink dots** for the families that stood out that day (pink air, blue weather; yellow pollen later), like Cycle Tracking's "other data" dots. The strip uses dots, not discs, so it stays clean.
   - Future days: empty capsules, with **dashed** ink dots where the forecast looks more like the times you used your inhaler. Further out = lighter.
4. **Headline** (New York) about the air right now, from the current hour's band:
   - elevated: "The air right now looks like the times you used your inhaler."
   - usual / quiet: "The air right now looks like your usual days."
   - before the gate: "We don't know your pattern yet."
   For a past day, the headline summarises that day instead ("2 inhaler uses. Ozone was high both times.").
5. **Log** for the selected day: a "Log" title with the count of moments on the right, then category headers with a coloured dot, each over a card tinted in its ink (about 10% light, 18% dark), Cycle Tracking style:
   - **● Air**: rows like "Ozone · High" (value in ink, semibold).
   - **● Weather**: "Humidity · Humid 84%", "Temperature · 84°F".
   - **● Notes**: "Anything going on? +", which opens the check-in sheet. Confirmed tags show here as the value.
   - **● Moments**: one row per moment with its mark glyph (34 pt), "Used inhaler" / "I'm okay", the time and a chevron to its sources. I'm okay rows are labelled "added automatically".
   Rows show conditions that stood out first; everything else is under the moment.
6. **History** (calendar button): the Last 5 weeks grid, 7 columns of day circles with the inhaler count, discs behind days where something stood out, today ringed in the air ink, and a one-line key. Tapping a day jumps the strip to it.
7. **Logging**: one action, "Used inhaler", in the floating bar above the tab bar (`tabViewBottomAccessory`), one tap from anywhere. There is no I'm okay button: I'm okay moments are captured in the background (see below). The action shrinks away once uses come from a smart inhaler.

### Recap (replaces Insights)

1. "Recap" pill at the top; page dots on the right if there's more than one page.
2. **Overlapping discs** for the top gated drivers (max two), in their inks.
3. **Eyebrow + headline**: "Of the 10 times you used your inhaler" / "ozone was high 8 times, and it was humid 6." The tinted words are the key for the discs.
4. **Comparison cards**, one per top driver: a label in its ink with an SF Symbol, then two capsule bars with counts: "Times you used your inhaler 8 of 10" (ink) and "Usual days 0 of 24" (grey). Counts only, no ratio.
5. **Today** card (SF Symbol, "Today", one bold line, one secondary line) from the look-ahead.
6. Caveat: "Outdoor air only, not a diagnosis."
7. Later pages: look-ahead hour strips; "How we know" (the full evidence table).

The voice slider (clinical → plain → poetic) stays in Settings and only changes the model's headline.

## I'm okay moments

Not a button. felt air captures them in the background: place, time and outdoor air at moments when you didn't use your inhaler. They are the comparison set for every pattern (predictive-engine.md §4).

- **Now:** one on app open, if there's been none in 20 hours and no inhaler use in the last 2.
- **Next:** a few a day at random times, from background tasks and visits at home. This needs the Always location permission; ask the owner before adding the prompt.

## Check-in sheet (proposed, from State of Mind)

Tapping "Used inhaler" logs immediately (logging must stay one tap and work offline), then offers a light sheet:

- the mark, large, with its discs;
- "Anything going on? (optional)" with the closed `JournalTag` list as chips. Chips the user taps are confirmed tags and become bins; nothing is suggested without the user tapping;
- Done.

Later the voice note (roadmap 3) feeds the same chips as dashed suggestions.

## Copy

Follows the Say / Do not say table in [predictive-engine.md §2](../predictive-engine.md): "times you used your inhaler", two plain counts, no ratio, no "attack", "looks more like", never a prediction. Highlighted words are always condition words, in their ink.

## Accessibility

- Colour is never alone: each ink has a word next to it (key, label, chip).
- Dynamic Type everywhere; cards reflow, grids keep 7 columns and shrink their circles.
- VoiceOver: a day circle reads "Wednesday, 2 inhaler uses, air stood out"; a mark reads its title, time and conditions.
- Respect Reduce Motion and Reduce Transparency (discs become solid at the same lightness when transparency is reduced).

## Decided

- Name: **felt air**.
- Logging: one "Used inhaler" action in the floating tab bar accessory. No I'm okay button.
- Breathing slider: not in the build.

## What's not decided

- **Joint conditions** ("humid *and* high ozone"): needs counting pairs in the rate table; until then copy names each condition with its own count.
- **Automatic "I'm okay" samples** at home need the Always location permission; ask the owner first.

## Building it

Order, each a small PR that ends on the phone:

1. Theme tokens (light + dark, follow system), New York headline style, name "felt air", rename "usual moment" → "I'm okay", logging in the tab bar accessory, no I'm okay button. *(done)*
2. `GlyphSpec` + "stood out" rule in `AsthmaCore` with tests; a `MarkView` that draws it.
3. Recap screen.
4. Journal: week strip, headline, day log with tinted cards, logging actions.
5. History grid behind the calendar button.
6. Check-in sheet with tag chips.
