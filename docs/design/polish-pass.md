# Polish pass: where felt air can feel finished

Oct 18, 2026. A read of the built app, screen by screen, against the question a design juror asks: *does every
touch answer back, and does the whole thing move with one hand?* Each item says what happens now (from the code),
what it could be, and the cost. Ranked by what a stranger would notice first.

What's already strong, so the list below is calibrated: three named springs (`Theme.snap / smooth / lift`), a
single sentence voice, the rail's level-tinted haptics that quicken toward high, the playhead's settle, the grain
that ripples when a sky arrives, Insights' bloom drawn from *your* factors. The bones are right. What's missing is
mostly the last 10%: the places where the app still uses a stock part, a cut, or silence.

## 1. The log: the one gesture that has to be unforgettable

**Now.** The + is a system `Menu` (`CaptureControl`). Press, slide onto Rescue, lift. A `.success` haptic, then a
"Rescue logged · Undo" strip drops in from the top, and the header switches to "Rescue logged. What's going on?".
Functional, accessible, and it feels like iOS, not felt air. The docs describe something else: press and *pull
up*, zones with their own haptics, letting go low cancels. That design never shipped.

**Could be.** The log is the heartbeat; it should be the one place the app shows its whole character at once.
- **Pull, not menu.** A custom press-and-pull on the +: the button stretches upward with the finger (a drop of
  glass), a soft tick entering Rescue, a firmer one entering Standard, release logs, release low snaps it back.
  Haptics: `.soft` → `.rigid` → `.success`. Reduce Motion: no stretch, same ticks.
- **The sky answers.** On release, the rescue ink (orange) or standard (blue) pulses out from the + across the
  grain, once, like a stone in water. The grain already has a ripple mode (`SkyGrain` wave on sky arrival); reuse
  it with the moment's ink instead of white.
- **The tick lands.** The new moment's tick should *drop onto* the timeline (scale 1.4 → 1 with `Theme.lift`) and
  the playhead glide to it, instead of appearing.
- **Lose the toast.** The header already says "Rescue logged." Put Undo in the capture card's corner for 8 s
  (a small "Undo" text button that fades) and drop the strip. One fewer thing arriving from a new direction.

Cost: M. It's one view (`CaptureControl`) plus the ripple hook and a timeline transition. The biggest single win
in the app.

## 2. Scrubbing time: continuous, not stepped

**Now.** Dragging the timeline swaps the whole sky per moment with `.transition(.opacity)` keyed on `focusKey`.
Between two moments on the same hour the sky crossfades; across the forecast it fades hour to hour.

**Could be.** The sky is *one hue plus layers*; both interpolate. While the finger is down, blend the temperature
hue and each layer's strength continuously with the playhead's time (the forecast already carries hourly values;
the past can lerp between neighbouring moments and baselines). Snap the *text* per moment (it already does), let
the *colour* flow. The sky becomes a thing you drag through, which is the whole metaphor. Cost: M (the colour
math is in `WeatherColor`/`AirLayers`; add a `weave(at:)` that blends two weaves by `t`).

Small ones in the same place:
- The "Now / +4h" pill uses `.numericText()` (good). Give the *date labels* under the track the same treatment
  when they shift.
- When the playhead is on a moment, dim the forecast strip a touch; on the forecast, dim the past ticks. Focus
  follows the finger.

## 3. The rail: let the icons feel the finger

**Now.** Hold the rail and the probe glows the band, the label sits top-left, the haptic pulses by level. The
icons themselves stay put; the selected one gets a slightly bigger mark (`d + 3`).

**Could be.** A Dock-style lens: the icon under the thumb grows (1.0 → 1.35) and the two neighbours ease away
by a few points, tracking the finger continuously (`Theme.snap`). It makes the rail read as a physical scale you
slide along. Group headers already open into lists; animate that opening as the list *unfolding from* the header
icon (matched geometry on the icon) rather than appearing. Cost: S–M.

## 4. The sentence and its sparkle

**Now.** The sentence crossfades in place (`.contentTransition(.opacity)` in `VerdictHeader`); `ScaleHeader` uses
`.blurReplace`. The sparkle mark is static text.

**Could be.**
- One transition everywhere: `blurReplace` is the better one; use it in `VerdictHeader` too.
- **Glint.** When a sentence with a mark lands, the sparkle plays one `.bounce` (SF Symbols' own), 300 ms after
  the text. Not on scrub, only when the view settles (`skySettled`). It tells you something was *noticed*.
- The one-time tip and the tap-for-key popover exist. Add a hairline underline (dotted, secondary) under the
  sparkle only, so the tappable thing is discoverable without a tip.

Cost: S.

## 5. The verdict pill

**Now.** A dot, the words, a chevron. Tint animates on change.

**Could be.** When it reads "Matches your flare days", the dot breathes slowly (scale 1 → 1.25, 2.4 s, repeat;
off with Reduce Motion). Still for the other two. The one state that asks for attention gets the only motion on
the line. Cost: S.

## 6. Insights: turn the page, don't fade it

**Now.** A sheet, fades in over 0.3 s; the bloom colours come from your factors (good); the learning ring draws
itself in over 1.4 s (good).

**Could be.**
- Enter from the sparkle: the pill's ring grows into the sheet's learning ring (matched geometry on the ring),
  so the thing you tapped becomes the thing you see. The sheet background should start as *this sky's* colours
  and settle into the factor bloom, so it reads as the same page turned.
- The archetype name should be the last thing to arrive, by ~150 ms, so the eye lands on it after the ring.
- The "Learned · may shift with the seasons" line is a button; make the chevron read as one (it's at 0.6
  opacity next to grey text).

Cost: M for the hero, S for the rest.

## 7. First run

**Now.** Onboarding opens on three concentric rings on a dark gradient, one sentence, a card with Get started.
The rings don't move and aren't referenced again.

**Could be.** The rings are the grain waiting to be born. On "Get started", the rings dissolve into the grain
and the first real sky fades up underneath as the location fix lands (the "here" step). The user watches their
own air arrive for the first time, which is the app's promise in one beat. Until the fix lands, the sentence
shimmers ("Checking the air near you…" with a slow left-to-right sheen, like Apple's loading text). Cost: M.

## 8. Chrome that still looks borrowed

Small things a juror notices in the first minute:
- **TipKit's blue.** "Use buttons instead" is system blue on a neutral page. Tint tips with `.tint(Theme.ink)`
  (or the moment's ink).
- **Settings' green switches.** `.tint(.green)` is a workaround for white-on-white. Pick an ink (the standard
  blue, or a warm grey) so Settings belongs to the same app.
- **Menu glyphs.** `lungs.fill` / `lungs` for Rescue / Standard in the + menu: the app never uses lungs anywhere
  else. If the pull gesture replaces the menu this goes away; if not, use the two inhaler inks as dots.
- **The "Now" pill text** flips between "Now" and "+4h" with a size change. Reserve width for the widest case.
- **Popover key** uses system `.headline`; set it in the sentence face at 17 so it matches the sentence it
  explains.

Cost: S each.

## 9. Sound, lightly

**Now.** Haptics only, no sound.

**Could be.** Two sounds, both off when the ringer is silent and both under 120 ms: a soft tick on a log, a
breath on "learned". Apple's own apps do this (Journal, Fitness). It's the difference between an app you use and
one you *hear* answer. Make it a Settings toggle, on by default. Cost: S, but a taste decision: try it, decide.

## 10. Reduce Motion and Dynamic Type

- Reduce Motion is honoured in `PressStyle`, the ring, the grain and the sentence transition. Not yet in the
  storm flash, the card stack's paging, or the sky crossfade (which should become an instant cut). Audit: grep
  `withAnimation` and `.animation(` for sites without a `reduceMotion` guard.
- The sentence is fixed at 30 pt. At accessibility sizes it should step down to 26 and allow three lines, not
  truncate. The rail's 44 pt column should grow to 56 at the largest sizes.

## Suggested order

1. The log (pull, ripple, tick drop, no toast). One PR, the signature.
2. Continuous sky while scrubbing.
3. Sparkle glint + verdict breath + chrome tints (one small PR of finish).
4. Insights hero from the sparkle.
5. First run: the sky being born.
6. Sound, as an experiment.
7. Rail lens; Reduce Motion / Dynamic Type audit.

Each is demoable on its own and none changes the IA. After 1–3 the app will feel like one object; 4–5 are what
people remember.
