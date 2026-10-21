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
- **You press and hold, like an actuation.** A tap does nothing. Holding pushes the cap down (it shrinks and
  darkens a little, like the canister travelling), a ring around it fills over 0.6 s, and a light haptic
  ticks as it travels. At the bottom of the travel: one firm thud, and the cap springs back. Let go early
  and it springs back with nothing logged, the same as a half-press on a real inhaler.
- **Then the same reveal as the felt button.** Shimmer, scan, the readings landing.
- VoiceOver: the cap is a button named "Press the cap"; its default action actuates straight away.
  Reduce Motion: no shrink, the ring still fills.

## How the first moment is labelled

It's a test press, never a rescue. It stays the **First moment**: a baseline moment (`.okay`,
`isFirstCapture`), tagged "First moment", never written to Apple Health and never counted as a flare. The
card says so in plain words: "That was a test press. It's saved as your first moment, not as a rescue."

## Open questions for Pandji

1. The software cap is orange (Rescue), because the rescue inhaler is the one people reach for. Teal, or a
   choice of both?
2. Teal vs blue: the hardware caps are orange and teal, but `Theme.standard` is blue. The pair screen uses
   the Theme token. Should Standard move to teal everywhere (Print inks has Teal #00838A)?
3. Should the hold length (0.6 s) match the felt button's own press threshold?
