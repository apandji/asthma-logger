# Onboarding: pair your inhaler

Oct 21, 2026. Owner's brief: "The magic moment of 'fetching' data I think we would want on a 'pair my
inhaler' screen. If someone doesn't have [a felt button] then we would display a software button. We want
to design this in an inhaler-native way."

## Step order

| | Step | What happens |
|---|---|---|
| 1 | Welcome | Unchanged |
| 2 | Where you are | The location prompt. The map draws in at your place, **with no air on it yet**. The sentence says where you are, not what's in the air. |
| 3 | **Pair your inhaler** | The cap waits in the middle of the sky. A press on the felt button (or the on-screen cap) is the moment the air is fetched: the readings shimmer, the scan rings out in the cap's colour, and the three readings land one by one with a tick. |
| 4 | Name your inhalers | Unchanged |
| 5 | What felt air uses | Unchanged |
| 6 | It gets better with time | Unchanged |

Location stays before pairing because the fetch needs a place. Step 2 no longer reads the air at all, so the
first time you see the air is the first time you press.

## The pair screen

**With a felt button (default).** The sky is the map of where you are, dimmed. In the middle, the cap seen
from above: an empty ring, breathing slow rings out (the old `Listening`), as if the phone is waiting for a
press. The card says "Pair your inhaler", the Bluetooth status line, and the hint that orange is Rescue and
teal is Standard. A press on either cap fills the ring with that cap's colour, then the fetch starts.

**Without a button.** "I don't have a felt button" swaps the waiting ring for a **software cap**: the same
cap from above, filled in orange, sitting in the inhaler's boot (a rounded shape behind it, the plastic
holder you press the canister into).

What "inhaler-native" means here:

- **It's a cap, not a +.** Round, seen from above, in the cap's colour. The boot behind it says "inhaler"
  without a drawing of one.
- **It presses the way the felt button does** (Pandji, Oct 21: "the more it feels like one thing the
  better"). The firmware (`hardware/felt-button/felt-button.ino`) has no hold: a press counts on the way
  down once the contact is steady for 30 ms (`DEBOUNCE_MS`), the LED flashes for 150 ms (`PRESS_MS`), and
  repeats within 600 ms are ignored (`LOCKOUT_MS`). So the cap counts on touch-down after 30 ms, sinks
  (shrinks and darkens a little) with a ring filling over 150 ms, one firm thud, and springs back. A touch
  that lifts inside 30 ms is ignored, like a bounce.
- **The press icon.** Beside the line that asks for a press (on the software cap and while waiting for the
  felt button) sits a line icon: a short button in slight perspective with SF `arrow.down` above it. The
  arrow comes down, the top sinks to the rim, both spring back, a pause, again. Still with Reduce Motion.
  No SF Symbol fits, so it's drawn (`Onboarding/PressIcon.swift`).
- **Then the same reveal as the felt button.** Shimmer, scan, the readings landing.
- VoiceOver: the cap is a button named "Press the cap"; its default action actuates straight away.
  Reduce Motion: no sink, the ring still fills.

## How the first moment is labelled

It's a test press, never a rescue. It stays the **First moment**: a baseline moment (`.okay`,
`isFirstCapture`), tagged "First moment", never written to Apple Health and never counted as a flare. The
card says so in plain words: "That was a test press. It's saved as your first moment, not as a rescue."

## Decided (Pandji, Oct 21)

1. The software cap stays orange (Rescue).
2. Standard stays blue (`Theme.standard`), not teal.
3. The press matches the felt button's: no hold, counts on the way down (see above).

## Open question

- "Where you are" no longer shows any air. Too quiet, or the right setup for the press? Left as is for now.
