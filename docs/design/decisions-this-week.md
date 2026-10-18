# Decisions this week (Oct 16–18, 2026)

A running log of the design decisions behind felt air's iOS app, written from the repo's own trail (commits on
`claude/the-log`, PRs #40–#76, the design docs) so it can become the story for Friday's presentation. Each beat
says the problem as the owner saw it, what was tried, what was chosen, and the principle it serves. Where a
commit or doc records why something felt wrong, it's quoted; otherwise the entry says what was built.

The rules every decision answers to are in the root `AGENTS.md`: code finds the pattern and the model only says
it; honest numbers; compare against usual days; one frame for past and future; never predict a flare; fail open. Dates are when the decision landed in the repo.

---

## 1. Words first: baseline and flare days (Oct 16–17)

**The problem.** The app compares the days you used the rescue inhaler with ordinary days. The first words for
that were "I'm okay", "calm", "usual days". They sounded like a judgement of the person, and the clinical word for
a bad episode was never allowed on screen.

**What was chosen (owner, Oct 16, `docs/mvp-brief-2026-10.md`).** **Baseline** (ordinary days, no rescue use) and
**flare days** (days with rescue use). Moments keep their inhaler names, **Rescue** (orange) and **Standard**
(blue). PR #42 and #52 swept the vocabulary through the narrator, the look-ahead, Settings and the shared
fixtures. The verdict line became "Looks like your baseline" / "A bit like your flare days" / "Matches your
flare days".

**Then (Oct 17, PR #69, #70):** a **Note** is something you said with no inhaler logged. It keeps the air, never
counts toward patterns, and is never written to Health. And a missing reading never sounds like clean air:
"Couldn't read the air here just now. Logging still works." replaced "Nothing in the air stands out".

**Principle.** Honest numbers, and never a sentence that implies the air was fine when it wasn't read.

## 2. Facts, never causes (Oct 17)

**The problem.** The FigJam copy board had lines like "likely triggered this flare-up". They read well and they
are exactly what a diary must not say.

**What was chosen (owner, Oct 17, `docs/mvp-brief-2026-10.md`, `docs/air-advice.md`).** "Stay with the facts and
drop anything causal." A flare moment leads with one fact ("It was 16° colder than three hours before."), then
what showed up on flare days. The advice cards ("close your windows", "an N95 mask filters fine particles") were
**kept as a provocation** for provider conversations, every one marked "A suggestion, not medical advice", none
shipping beyond the test group without a cited source. `docs/provider-review.md` quotes every word that touches
care, with a question for each. The tests (`TheReadTests`, `AirAdviceTests`) check for no causes, no odds, and
none of the forbidden words.

**Principle.** Never predict a flare; the model (and the template) only says what the code found.

## 3. The one gesture: logging (Oct 16 → Oct 18)

**The problem.** The log is the app's heartbeat. On Oct 16 the + went through three shapes in a day: two
buttons on tap, then a system menu ("press, slide onto Rescue or Standard, lift"), with the custom pull track
removed. The polish pass (Oct 18, `docs/design/polish-pass.md`) read the result against the question "does every
touch answer back?": "Functional, accessible, and it feels like iOS, not felt air. The docs describe something
else: press and pull up… That design never shipped."

**What was chosen (Oct 18, `62f282b`, PR #76).** Press the + and it grows into a **Liquid Glass well**: Rescue
nearest the thumb, Standard above, a lens that follows the finger. Lift in a zone logs; lift low cancels; a tap
latches it open for a second tap. The new tick **drops onto the timeline**; the ink ripple starts from the +'s
side. **The toast is gone**: the header already says "Rescue logged. What's going on?", and Undo sits on the
capture card for ten seconds. VoiceOver keeps the system menu.

**The morning follow-up (owner's first look, Oct 18, `e233a69`).** The 88 pt well with text inside moved the
button in x. Now the well is the +'s own width, two ink dots mark the stops, the + itself rides up as the lens
and takes the stop's ink, and the name appears beside it "like a reading beside the rail". Nothing moves in x.

**Puffs (owner, Oct 16–17, PR #72, `docs/data-model.md`).** A second press within **two minutes**, from any
device (felt button, watch, the phone's +), adds a puff to the same use; Undo takes one puff off. Apple Health
gets one Inhaler Usage sample per use, valued in puffs. Puffs show only in a moment's details, never on Home.

**Principle.** One tap logs; nothing may block it (fail open); the sky answers the hand.

## 4. One column on the hand's side (Oct 17–18)

**The problem.** The rail (hold to read the air) lived on the right, Settings sat on the timeline at the bottom,
Insights was a sparkle button top right. Three controls in three corners, and a left-handed option that only
mirrored one of them.

**What was tried.** Oct 17 went through four rail layouts in a day: a name tag that followed the thumb with the
reading fixed top-left (`452602b`); readings back beside the thumb at their row, with group headers listing what
they track (`34b1a21`); "Self" as a last stop that dimmed the sky (PR #67), then as two glass cards without the dim
(PR #68), then split into **Voice** and **Body** as ordinary stops (PR #69). The design-system rule that survived:
every panel sits beside the thumb at its row and names itself, left of the thumb, so the thumb never covers it.

**What was chosen (Oct 18, PR #75, `88f65bf`).** Insights and Settings become **one upright glass pill at the head
of the rail**. The pill, the rail's stops and the + share one line (`NowHomeView.column`) and all follow
Settings › Rail, left or right. The header runs the full width again.

**Then it had to behave like the rail (Oct 18, `d09ff4b`, `9b1f651`).** Hold Insights or Settings and its name
appears beside it. Touch the pill and the one under the thumb grows and names itself; slide between them; lift to
open; slide off to let go of nothing. Settings took a slider glyph so it no longer reads as a second ring. The rail
got a glass well and a lens (the stop under the thumb grows, neighbours ease away), hysteresis before the reading
switches stops, and, from testing, it now **grows around the pressed stop** instead of sliding out from under the
thumb (`152e9d0`, `ideas.md`: "the selection jumped to whatever landed under the finger").

**The column stays put (`d09ff4b`, `b0831ce`).** The stops, the pill and the + are laid out from the bottom of the
sky over a fixed reference height, so they don't move as the sentence changes length; the header is its natural
height and the sky takes the slack.

**Principle.** One hand, one side; hold-to-read everywhere; the same gesture grammar for every control.

## 5. Time is one thing you drag through (Oct 16 → Oct 18)

**The problem.** Dragging the timeline swapped the whole sky per moment with a crossfade. The polish pass: "The
sky is one hue plus layers; both interpolate… Snap the text per moment, let the colour flow. The sky becomes a
thing you drag through, which is the whole metaphor."

**What was chosen.**
- **One sky that flows (Oct 18, `ffddd15`).** One `NowSky` for every time; while you drag, the mesh eases from
  reading to reading and the temperature hue is interpolated between the readings either side of the playhead. The
  sentence blurs between readings. Landed, the sky takes the moment's identity again so arriving somewhere new still
  crossfades.
- **Three tenses (Oct 16, `19870a5`, `5bb0437`, `a872d31`).** The past is still and a touch faded, now breathes
  with a live pin, the future is a sketch (hollow particles, paler map, no pin). A ripple per tense: the past closes
  in onto the pin, now rings out, the future washes in wide and soft.
- **The forecast by the hour, in verdict colour (Oct 18, `e233a69`, `2a10bd9`).** Forecast hours are green /
  yellow / red like the pill, "still breathing while uncertain"; one bar per hour; the playhead snaps to whole hours;
  "6 AM" / "6 PM" beneath the strip. The Now chip and playhead wear the verdict's colour; ahead, the chip has a dashed
  edge like the forecast's sketch "so it never reads as a record".
- **The chip is the way back (Oct 18, `e38771b`).** One control returns to Now, like Calendar's Today: away from
  now the chip carries a return arrow and reads "Today, 12:21" / "Tomorrow, 3:00 PM" / "Mon, 9:00 AM". The separate
  "↩ Now" button (built that morning) and the hidden step-back are gone. The chip reads the timeline's own state every
  frame, so it never lags (`9b1f651`).
- **Moments as dots (`2a10bd9`).** Rescue bigger, standard smaller, a note smallest, on the axis so they don't read
  as hour marks. A rescue with nothing said yet is hollow and fills once noted. Baselines are **hidden from the
  journal** (owner, Oct 17): still filled in, still in the maths and the export, never a tick.

**Principle.** One frame for past and future: the same bins, the same rate table, so the forecast is the same
picture as the record, only sketched.

## 6. Words, not numbers (Oct 17–18)

**The problem.** Insights at first showed counts: "9 of your 14 rescue moments", "Learning: 25 moments to go",
strength words with numbers beside them. The owner pushed back on the "quantified self": you're not a number
(`543d227`, `docs/design/personal-insights.md`).

**What was chosen (owner, Oct 17, PR #64).** **No counts or ratios anywhere on screen.** Patterns read in words
("Humid air often shows up on your flare days."), categories Often / Maybe / Not much, When and Where "Mostly in
the afternoon.", the profile "Still learning…" or "Learned · may shift with the seasons". The only numbers people
see are readings with units, when they hold the sky on Now, "an intention to learn". Counts stay in the data, the
tests and the exported table (`AGENTS.md` contract updated; PR #65: "complex, data-driven backend, simple
frontend").

**Then the sentence got shorter (Oct 17–18).**
- **The sparkle (PR #74, `046d5ab`).** "It sometimes shows up on your flare days" became a mark after the fact: ✦✦
  for often, ✦ for sometimes. VoiceOver and the morning notification get the words back. The tip explains the marks
  as a key, not a sentence about them (`4753851`).
- **The verdict in one place (PR #75).** On Ahead the sentence said "looks like your baseline days" while the pill
  said "a bit like your flare days". Now the sentence only says what's in the forecast, with the sparkle when it
  shows up on your flare days; the pill alone compares.
- **The key names the factor (`b797e12`, `2a10bd9`).** Tap the sparkle: "✦✦ High weed pollen shows up often on
  your flare days", the same words as Insights; the popover's arrow points at the sparkle itself.
- **Headers that flow, never scale (`d9ac741` → `d09ff4b`).** Long sentences first stepped down 26 → 23 → 20 pt to
  hold three lines. The owner's note the same morning: no scaling, one size, never cut. The header carries at most two
  sentences; the rest drops to a quiet grey line beneath.
- **The read is about the air (Oct 17, `docs/design/header-ia.md`).** Time of day, season, place and indoors/out are
  about you, not the air; they left the read for Insights.

**Principle.** Compare against usual days, and say it in words a person would use about themselves.

## 7. The voice loop (Oct 17–18)

**The problem.** The APIs can't see the dog, the gym, the cold bus. The context has to come from the person, right
after the press, without a form.

**What was built, in order (owner's build order, Oct 17).**
- **Quick Record (PR #56, #57).** After a felt button or watch press, a notification asks "What's going on?" with
  quick tags and "Add a voice note". Then a Lock Screen Live Activity does the same without unlocking; because iOS
  only starts one from the foreground, a standby card waits ("Here if you need it.") and a background press lights it
  up (`bc9542e`).
- **Hold to record on the rail (PR #69).** Hold the rail, slide to Voice, slide sideways into its panel and it
  records (a firm haptic); lift to stop; slide back out to cancel. Then a light review: your words (editable),
  suggested tags, Save or Redo. Nothing is written until Save.
- **Live words (Oct 18, `1440f10`).** Recording moved to `AVAudioEngine`, feeding on-device speech recognition with
  partial results, so the words appear as you say them, the newest brighter.
- **One recorder across surfaces (PR #72).** The rail, the Lock Screen and Quick Record each add a `VoiceNote` with
  its own audio; a note during a rescue (last 30 minutes) goes into that moment, otherwise it becomes a Note.
- **Past tense for the past (PR #74).** "The temperature had fallen 20° in three hours, after a fast drop the day
  before." A drop is said once; when the pattern is the drop, its sparkle joins the fact.

**Principle.** Journal tags are confirmed tags only; a frame without a reviewed note is missing, not "no".

## 8. The data under it (Oct 17)

**Baselines, filled in afterwards (PR #63).** Inhaler logs alone can't show a pattern. The app-open sample was
retired; a day later, about three hours per day (morning, afternoon, evening), clear of inhaler use, are placed where
you were (visits, on the phone only) or at home, with that hour's air from history. The 8 am morning look-ahead renews
the Lock Screen card.

**The data model split (owner, Oct 17, PR #71, #72).** `LogEvent` gains inhaler uses (puffs, inhaler, device) and
voice notes. Rescue / controller belongs to the inhaler, not the moment; a moment's kind is derived from its uses.
Inhalers are named in onboarding.

**Everything the engine runs on, exportable (PR #65).** Every moment with full provenance (source, scale, station,
distance, confidence, as-of), the 48-hour look-back, the bins used, and the pattern table. Honest numbers live here.

**Made-up people for demos (PR #62).** Eight archetypes, six weeks each, run through the real pipeline; your own
data is kept as "My data" before anything replaces it. Demo data never enters real patterns; the "Demo" labels are
off screen until user testing (owner, Oct 17).

## 9. What we dropped, and why

| Dropped | When | Why (as recorded) |
|---|---|---|
| The clinical → plain → poetic voice slider, and model narration of the Insights sentence | Oct 17, PR #73 | "felt air speaks in one plain voice, from the template narrator." Foundation Models stays for one quiet job, tag suggestions you confirm. Siri and Apple Intelligence ideas parked in `docs/apple-intelligence-later.md` |
| The "Rescue logged · Undo" toast | Oct 18, `62f282b` | "The header already says it's logged"; Undo moved to the capture card. "One fewer thing arriving from a new direction" |
| The separate "↩ Now" button and the hidden step-back | Oct 18, `e38771b` | One way back: the chip |
| "See all" inside Insights category cards | Oct 18, `d9ac741` | The card lists the whole family, including what isn't measured yet, in grey |
| The event chip in the header | Oct 17, `6fdd383` | The read and the cards already name the event; the verdict took its place beside the place |
| Counts in the learning pill and bubble | Oct 17, PR #64, #74 | No numbers on screen; the button breathes while learning and bounces once when learned |
| "Self" as a dimmed overlay, then as a header | Oct 17, PR #67 → #69 | Voice and Body became ordinary stops; the rail reads the same at every row |
| Header text scaling to fit | Oct 18, `d09ff4b` | Owner's note: one size, never cut; the header flows instead |
| The event-only "likely triggered" lines from the board | Oct 17 | Facts only |
| Baseline ticks on the timeline, "I'm okay" | Oct 16–17 | Baselines are the comparison, not a thing you see; the idea shows only in the verdict |

## 10. Still open

From `docs/design/ideas.md` and the Oct 18 review's questions for the owner:

- **The well's zones are words.** Should Rescue / Standard be the two inhaler inks as dots, so the + never shows text?
- **Undo merges, it doesn't delete.** A second press adds a puff; Undo takes one off. Should the card say
  "2 puffs · Undo" so the arithmetic is visible? (A number on screen, so it needs a decision.)
- **Hold the + for a 2-puff log**, since most rescues are two puffs.
- **Sounds:** a tick on a log, a breath on learned. Keep, compose properly, or drop.
- **The two list counts left on Insights** ("Your moments · 14", "Your profile history · 1 so far"): keep, or titles
  alone.
- **"Learned" as a date** ("since September"), and a one-time card when the season turns.
- **A standing Lock Screen card at all**: a question for the provider sheet.
- **Words to check with a doctor:** Rescue / Standard, "flare", every advice line (`docs/design/header-ia.md`).
- **Pollen** reads "not included yet" until the Ambee contract lands; tree and grass pollen show "Not tracked yet".
- **Not verified on the phone yet** (review, Oct 18): real live transcription, the sounds, whether Insights zooms
  from the sparkle on device, Reduce Motion, Dynamic Type.
