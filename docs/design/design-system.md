# felt air design system

What the app is built from, as of Oct 16, 2026. This is the source of truth for new screens: use these
pieces, in these words, before inventing any. Code lives in `ios/AsthmaLog/Theme/` (tokens) and the views
named below. The older [visual-style.md](visual-style.md) and [riso-visual-language.md](riso-visual-language.md)
are where these ideas came from; where they disagree, this file wins.

## One idea

The app is **printed on paper**. The page is black paper tinted by the weather; the air is riso ink
particles on it; words are set in one Recursive sentence and SF for everything else. Colour has **one job**:
it says *which* air. Everything else (which inhaler, how much, good or bad, past or future) is said by
words, size, shape, motion or ink weight.

## Tokens (`Theme.swift`)

### Paper and ink

| Token | Value | Use |
|---|---|---|
| `Theme.paper(.black)` | #000000 | The page. (Linen is a retired experiment; keep the switch off.) |
| page gradient | weather hue → black | The home's page: `WeatherColor.light(temperature, at: hour)` mixed 22% toward black at the top, black at the bottom. A red-verdict day warms the bottom to `Verdict.red` mixed 72% toward black. |
| `Theme.forecastPaper` | #1C1A17 (warm graphite) | The future's page, crossfaded over 0.9 s when the playhead crosses now. |
| `Color.primary` / `Theme.secondaryText` | white / #C2C2CC | Text and controls. Never coloured. |
| grain | `SkyGrain(responds: false).opacity(0.5)` | A still halftone over every page. |

### Air inks (`WeatherColor`)

| Layer | Ink | Symbol |
|---|---|---|
| PM2.5 | slate #6B7A99 | `smoke.fill` |
| PM10 | sand #DBB880 | `wind` |
| NO₂ | rust #BD613D | `car.fill` |
| Ozone | icy cyan #A8EBFF | `sun.haze.fill` |
| Tree pollen | green #5CCC75 | `tree.fill` |
| Grass pollen | gold #FACC38 | `leaf.fill` |
| Weed pollen | violet #B86BF2 | `allergens` |
| Weather | none (primary) | `cloud.sun.fill`, `thermometer.low` after a sharp drop |

`WeatherColor.ink(for:)` and `SkyExplorer.icon(_:)` are the single sources. These inks appear **only** as
particles, in the label's icon and amount dots, and in the Insights bloom.

### Verdict colours (`Verdict`)

| | Colour | Words |
|---|---|---|
| green | #5CCC78 | "Looks like your baseline days" |
| yellow | #FACC40 | "A bit like your flare days" |
| red | #FF5C52 | "Matches your flare days" |

Used **only** on the verdict pill's dot and fill, the Insights "See the evidence" pill, and the warm page
bottom on red days. Never on particles, tags or the rail.

### Inhaler

Inhaler kind is a **word**: `MomentTag` ("Rescue" in primary ink, "Standard" in secondary), 84 pt wide so
it never resizes. The only colour it ever gets is the pastel of a fresh log's scan ring:
`Theme.rescueSoft` #FFC9A3, `Theme.standardSoft` #B4DCF7.

### Weather hue (`WeatherColor.temperature`, `.light(at:)`)

Blue (cold) → teal → green (mild) → gold (warm) → red (hot), under the light of the hour: indigo night,
rose dawn and dusk. It is the **page**, not a data mark.

## Type

| Role | Font | Where |
|---|---|---|
| The sentence | `Theme.serifTitle`: **Recursive** 28 pt, weight 400, kerning −0.4 (`Theme/Recursive.swift`, OFL, bundled) | One per screen: "It's 54° and humid, and the air is clear." Its Casual axis follows Settings › Insight voice: clinical linear → poetic casual. Falls back to New York if the font is missing. |
| Larger sentence | `Theme.serifTitleLarge`: 32 pt | Only on pages with nothing else above the fold |
| Place line | `.subheadline.weight(.medium)`, secondary | Above the sentence: icon + place |
| Verdict pill | `.subheadline.weight(.semibold)` | The pill under the sentence |
| Counts | `.title3.weight(.semibold).monospacedDigit()` (Insights ring); `Theme.figures` is Recursive Mono for numbers that change in place | |
| Caption | `Theme.caption` (.caption), secondary | Notes, footers |
| Kicker (retired) | | The tracked small-caps kicker is gone; place lines are sentence case. |

One voice for the sentence, SF for the rest. The sentence is never bold, never scaled to fit (long lines wrap to
two, then truncate). Slant is Recursive's `slnt` axis, used only where a tense needs it.

## Motion (`Theme.snap / .smooth / .lift`)

Three springs, used everywhere:

| | Spring | For |
|---|---|---|
| `Theme.snap` | snappy 0.24 s, slight bounce | small things settling: pills, chips, dots |
| `Theme.smooth` | smooth 0.45 s | content changing: headers, skies, pages |
| `Theme.lift` | spring 0.55 s, bounce 0.22 | things arriving: toasts, tiles |

Rules:
- **Instant while scrubbing, one crossfade on landing.** While the timeline moves, text and skies swap
  with no animation; when it settles, one 0.22 s crossfade in place. No rolling, scaling or blurring text.
- **Press feedback** on everything tappable that isn't a system control: `PressStyle` (scale 0.96, dim).
- **Reduce Motion** turns off breathing, drift, ripples, lightning and press scaling; the design must
  still read from colour, shape and words.

## The sky (`NowSky`, `ParticleField`, `GroupRail`)

The main picture. Weather-only colour field, the **map pinned** on top (never moves with a finger), a
**pin** at the centre, and the air as **particles**: each layer is its own ink, sprinkled evenly over the
whole place. Count and size say how much; nothing says *where*.

Reading it: **the rail** on the right edge (left in Settings › Rail for left hands). Folded, five stops in the
language of Personal Insights: **Weather · Particles & gases · Biologics · Voice · Body** (`Icons` is the one source
for every symbol). Hold it and it opens once for the whole hold, each group with its items as dots underneath (PM2.5,
PM10, ozone, NO₂; tree, grass, weed pollen), so nothing shifts under the thumb. Slide to read; every panel sits beside
the thumb at its row and names itself:

- **An item or Weather:** the full reading (the layer's ink on its icon, the value large, three **amount dots**, the
  level word, one plain line, the 48 h look-back as sparklines). Its dots light up across the sky.
- **A group header:** the list of everything it tracks, each with amount dots and level, or "No reading".
- **Voice:** your words and tags. Keep the thumb down and **slide into the panel to record** (a firm haptic, the dot
  ring); lift to stop; slide back out to cancel. Then a light review: the words (editable), suggested tags, **Save** or
  Redo. On Now with nothing logged, Save makes a **Note**.
- **Body:** activity (motion sensor) and Apple Health (sleep, heart, breathing) in words, with **Connect Apple Health**.

Let go on Voice or Body and the panel stays (rail open, row lit); tap the sky to close. Let go anywhere else and it folds.
Voice wears a small dot when the moment is a rescue with nothing said. The finger **dent** shader bends only the sky
drawing, never what sits on top.

Three tenses:

| | Motion | Focus | Colour | Ripple |
|---|---|---|---|---|
| Past | still | sharp | 82% saturation | closes inward onto the pin |
| Now | particles breathe, pin pulses | sharp | full | rings outward from the pin |
| Future | hollow particles drift, more the further out | softens with distance | quieter page | washes in wide and soft |

A **fresh log** is a scan: the map alone, then a ring from the pin in the inhaler's pastel, and the
particles fill in just behind it.

**Air events** take the page over: slate for a storm (lightning, pollen fragments), ochre for smoke (a warm
veil, dense PM2.5), ice for a temperature drop (cool band at the top). The read states the fact, never a
cause; the event's advice comes as a card (docs/design/header-ia.md).

## Header (`VerdictHeader`)

See docs/design/header-ia.md. The **context line** (moment tag, place, and the verdict pill beside them), **the
read** (one sentence about the air and your days, never a weather readout, no numbers), then on a moment its date
and time; under the header, the **cards** (advice, the capture card) stacked and swipeable.

## Timeline (`NowTimeline`)

A full-width track under the sky, fading out under the glass controls at each end. One ink at three
strengths: past moments are ticks (rescue taller than standard) in the strength of that day's air;
baseline checks are short faint ticks; the forecast is a strip of slots that waver, in the verdict's
strength or faint while learning. A **Note** is a short, quiet tick. A rescue with nothing said wears a small
hollow ring above its tick until it's noted. The playhead's pill reads **Now**, **+4h**, **−6h** or the day; off
now it carries a return arrow and tapping it jumps back.

## Controls

| | Size | Style |
|---|---|---|
| + (log) | 56 pt | glass circle; a system **menu** (press and slide to Rescue / Standard) |
| Settings | 44 pt | glass circle, bottom-left |
| Pills (verdict, place field) | | capsule, 16% tint fill, no border |
| Rows (Insights) | | full-width glass, 22 pt corners, icon · name · value · chevron |
| Primary button (onboarding) | | white capsule, black text |

All glass is `.glassEffect(.regular.interactive())`. Touch targets are never under 44 pt.

## Insights

**Personal Insights** (docs/design/personal-insights.md): the title in SF, the archetype as the page's one Recursive
line, "Learned · may shift with the seasons", the radar, the category cards, When | Where, then Your profile history
and Your moments (with Export). Before it has learned: the **learning ring** of riso dots and "Still learning…". No
numbers anywhere. The page's
background is the **bloom**: slow Apple-Card blobs in the inks of what shows up most on your flare days,
under a dark wash and the grain.

## Words

Vocabulary: [felt-air-language.md](felt-air-language.md). On screen: **Rescue**, **Standard**,
**baseline**, **flare days**, **moment**, **first capture**. Never "attack", a percent, a cause,
"comfortable" (we don't know how it felt), or "the air you breathed". Air levels: clear · a little hazy ·
hazy. Sentences state facts in two clauses at most.

## Onboarding (`OnboardingView`)

The same header, sky and glass card: welcome → where you are (the location prompt, the sky draws) →
**press your felt button** (the phone listens; the press draws the scan and the **first capture**, a
baseline moment with its own tag) → two optional permissions → the learning ring. No photos.

## Adding something new

Ask, in order: does it use the sentence, a place line and a pill? Is colour only on the air? Does it move
with one of the three springs and stay still while scrubbing? Does it read with Reduce Motion on? If a new
choice is open, add a Design crit switch (`Crit.swift`) with the current proposal as default, not a fork.
