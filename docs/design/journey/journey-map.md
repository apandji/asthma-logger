# felt air: the journey

Oct 18, 2026. A draft for Friday, built on Pandji's "Moments that matter" stickies and checked against what's in
the repo. Every quote is from the code or the docs, with the file named. **Built** means it's on the phone today,
**proposed** means it's an idea from this map or from `ideas.md`, and **open** means it needs a decision.

**Who.** An adult with asthma who carries a rescue inhaler, often with a daily controller as well. They're in the
TestFlight group, so they're curious and fine with a rough edge, but they won't open a medical app every day.

**Job to be done.** *"When I reach for my inhaler, I want it noted without thinking about it, so that over time I can
see what my bad days share and walk into my next appointment with more than 'it's been okay, I guess'."*

Two promises run under every stage (root `AGENTS.md`): felt air never says a flare will happen or what caused one,
and nothing ever blocks a log.

---

## The stages at a glance

| # | Stage | Source | When |
|---|---|---|---|
| 1 | The felt button arrives | Pandji | Day 0 |
| 2 | First capture (onboarding) | Pandji | Day 0 |
| 3 | The quiet days | **proposed** | Weeks 1–6, in between flares |
| 4 | The flare itself | **proposed** | Any day |
| 5 | A heads-up from the forecast | Pandji | When the sky turns |
| 6 | Insights getting better ("levels?") | Pandji | Weeks 2–12 |
| 7 | Your profile, learned | Pandji (reframed) | After the gate |
| 8 | The seasons shift it | **proposed** | Months 3+ |
| 9 | For your next visit | **proposed** | Before an appointment |
| – | When things go wrong | **proposed**, runs under every stage | Any time |

I added **3** and **4** because the build already spends most of its effort there (the + well, the rail, the Lock
Screen card, baselines filled in afterwards, the morning look-ahead), and Pandji's list skips from onboarding
straight to forecasts. I added **8** and **9** because the profile is designed to move with the seasons (profile
history) and because the clinical research says the payoff is a person reading the diary with you
(`journaling-clinical.md`). **When things go wrong** is a lane and not a stage, since fail open is a principle and
the failures can happen in any stage.

---

## The emotional curve

```
 calm  ─┐                  ★7 learned
        │   ★2 first        ╱‾‾‾‾╲          ★5 calm heads-up     ★9 visit
        │   capture  3 quiet╱      ╲8 shift  ╱‾‾╲               ╱‾‾
        │  ╱‾‾‾‾‾‾╲___ ___╱  6 slow  ╲____╱    ╲_____________╱
        │ 1 unbox     ╲ ╱      wait
        │ (curious)    ╲╱
 tense ─┘               4 FLARE (the low)
```

| Stage | Feeling | High or low | What sets it |
|---|---|---|---|
| 1 Button arrives | Curious, a bit sceptical | rising | Something to hold. The light answers the press |
| 2 First capture | Seen, "oh, that's my air" | **high** | The sky appears for where you're standing |
| 3 Quiet days | Indifferent, it can drift | flat | Nothing to do, which is the point. Risk: forgetting the app |
| 4 Flare | Anxious, short of breath, one hand | **low** | It has to take one press. Anything more has to wait |
| 5 Heads-up | Prepared, or alarmed | high **if calm** | Facts about the sky, never "you will" |
| 6 Getting better | Impatient | dip | Learning moves at the pace of your flares |
| 7 Learned | Recognised, "that's me" | **high** | A name and a line in words, never a score |
| 8 Season shift | Unsettled ("did it get it wrong?") | dip | Unless felt air said ahead of time that it would happen |
| 9 Next visit | Equipped | high | Something a clinician can read in a minute |

---

## 1. The felt button arrives (Pandji)

- **Doing / thinking / feeling.** Opens a small box with a two-cap button inside. *"What is this, and do I have to
  carry it?"* Curious, maybe a bit wary of yet another gadget.
- **Touchpoints.** felt button (orange cap for Rescue, teal for Standard, the LED). A card in the box (**proposed**).
- **What felt air shows.** The LED, documented in `docs/smart-button.md`: a quick dim flash means "the button felt the
  press", one slow breath means "the phone acked it: the log is saved with the air", a soft pulse every 4 s means a
  press is waiting for the phone, and a slow blue blink means "not paired".
- **Status.** The firmware, the BLE protocol, the 32-press queue and pairing in Settings are **built**. Onboarding
  listens for the first press (`OnboardingView` `.button` step: "Press your felt button."). The box and its card are
  **proposed**. The power is USB or a power bank for now, and there's no battery level yet.
- **Rests on.** Fail open. Without a button you still get the full app: "I don't have a button" is an equal choice
  in onboarding, and the app asks for Bluetooth only at that point.
- **Risk.** Hardware that feels like surveillance ("it's always listening"), or a box that looks like a medical
  device. The card should say what the button does and what it doesn't.
- **Watch in a session.** Can they tell the caps apart without reading anything? Does the slow "breath" read as
  "saved"? (No A/B test yet. **Candidate:** a card in the box vs none.)

## 2. First capture: location, time and the air (Pandji)

- **Doing / thinking / feeling.** They grant location and watch the sky draw in for where they're standing.
  *"So it knows the air right here."* This is the first high.
- **Touchpoints.** Onboarding steps: welcome, then here, then the button, then the inhalers, then the permissions,
  then learn.
- **What felt air says** (`OnboardingView.swift`). On welcome: "Your inhaler, and the air around it." and then
  "Outdoor air only. Not medical advice." On the here step: "Checking the air near you…" and then "The air where you
  are." On the first press, a **First capture** tag with the air sentence and "That press is your first capture: the
  air, here, right now." On the inhalers step: "Name your inhalers." (Rescue · orange cap, Daily · teal cap). On
  permissions: "What felt air uses, and where it goes." The cards (`DataCards.swift`) list *Uses / For / Goes* for
  each source and end with "Everything is optional. Logging works without any of it." On learn: "It gets better with
  time."
- **Status.** All of it is **built**, and the data cards are new on this branch. The first capture is stored as a
  *baseline* (`baseline_source: first_capture`), not as inhaler use: "This first press pairs the button, it isn't
  counted as inhaler use."
- **Rests on.** Honest numbers: outdoor, labelled, and with its source attached. Ask before anything leaves the
  device: each card tells you whether it stays on this iPhone or leaves it.
- **Risk.** Privacy. The location card says the position goes to "Apple Weather, OpenAQ, AirNow and **Ambee**", but
  Ambee isn't a source yet (its contract is being renegotiated). That's accurate later and inaccurate today
  (**open**). Six permission cards in a row could also feel like a toll booth.
- **Watch.** How long people spend on the permissions step. Which cards they skip. Whether "First capture" reads as
  "I logged a puff" when they haven't.

## 3. The quiet days (proposed stage)

- **Doing / thinking / feeling.** Most days nothing happens: no puff and no reason to open the app. *"Is it doing
  anything?"* Indifferent, which is healthy. The risk here is drift, not worry.
- **Touchpoints.** The morning notification at 8, the Lock Screen standby card, Now (the sky, the verdict pill, the
  timeline), Insights' breathing ring.
- **What felt air does and says.** In the background, `BaselineBackfill` fills in about three ordinary hours a day
  (morning, afternoon and evening, clear of inhaler use), placed where you were and stamped with that hour's air. You
  never see a baseline tick. The idea shows up only in the verdict: "Looks like your baseline days". The morning
  notification (`MorningBrief.swift`) reads "Today: a bit like your flare days" plus the look-ahead line once felt air
  has learned, and "Today's air" before that. The six mornings after carry a plain line: "See what the day looks like
  next to your flare days." The Lock Screen standby card reads "Here if you need it. / The mic logs a rescue and
  listens."
- **Status.** All **built**. Opening the 8 am notification also renews the Lock Screen card (iOS only *starts* Live
  Activities from the foreground) and fills in baselines.
- **Rests on.** Compare against usual days (predictive-engine §4). Baselines are automatic only, with no "I'm okay"
  button (a decision from Oct 17). NICE NG245 advises against routine daily symptom monitoring, so we don't prompt
  daily.
- **Risk.** Before felt air has learned, "next to your flare days" promises a comparison that doesn't exist yet
  (**open**: maybe "See today's air."). A daily notification can feel like nagging. A standing Lock Screen card is
  still an open question for the provider sheet.
- **Watch.** Do they keep the morning notification on after a week? Does the standby card feel welcome or
  intrusive? (Ask. No test id yet.)

## 4. The flare itself (proposed stage)

- **Doing / thinking / feeling.** Chest tight, reaching for the inhaler, one hand free at most, maybe in public.
  *"Not now."* Anxious, sometimes frightened. **This is the low point.** In that moment the only thing that matters
  is the inhaler. felt air has to cost one press, and everything else can wait.
- **Touchpoints, from least effort to most.** The felt button (orange cap). The watch (Rescue). The Lock Screen card
  ("Rescue voice note" from Control Center or the Action button). The phone's + (press and pull into the glass well:
  Rescue is nearest the thumb). Then afterwards: the capture card on Now, the rail's Voice stop, or a notification.
- **What felt air says.** "Rescue logged. What's going on?" (`TheRead.justLogged`). The Lock Screen alert says
  "What's going on? Tap the mic to say." A second press within 2 minutes adds a puff. Undo sits on the card for
  10 s. The capture card (`CaptureExpanded.swift`) asks "What happened?" and its sections are "How did your
  breathing feel?" / "What were you doing?" / "What was around you?" / "Anything else?" (urgent visit, oral
  steroids). A rescue with nothing said is a hollow dot, and it fills in once a note is added. On the moment
  afterwards there's one fact and no cause: "It was 16° colder than three hours before."
- **Status.** The button, the watch, the + well, the Lock Screen card, the rail recorder with live words, and the
  chat-vs-journal capture are all **built** (the capture is behind A1). Symptom and outcome tags are **built** and
  kept out of the lift table. "Hold the + for 2 puffs" and "shake to undo" are **proposed** (`ideas.md`).
- **Rests on.** EMA: capture at the moment beats recall (Shiffman 2008). NICE NG245: focused questions beat "how
  have you been?". Journal tags are *confirmed* tags only. Fail open: the log saves before any air arrives.
- **Risk.** Interrupting the inhaler. A prompt that arrives *during* the flare and not after. A chat that feels like
  "talking to a thing" when you can't breathe. Wrong-kind logs (Standard instead of Rescue). Lit words that put words
  in your mouth.
- **Watch.** **A5** (pull / menu / buttons) and **A6** (rescue first): time to log and wrong-kind logs in a one-handed
  role-play. **A1** (chat / journal / sheet): time to a saved note, how many of the four control domains get answered.
  **A2** (ticked / suggested): "did it put words in your mouth?" **A3** (rotating vs fixed opener). **A7** (sounds in
  public).

## 5. A heads-up from the forecast (Pandji)

- **Doing / thinking / feeling.** A storm is coming in on a high-pollen afternoon. *"Should I change my plans?"* If
  it's said calmly, they feel prepared. If it's said loudly, they feel alarmed.
- **What triggers it** (`NowHomeView.liveEvent`). Apple Weather's current condition contains "thunder" **and** some
  pollen kind is at a high level. The same pattern produces the other built events: a sharp temperature drop
  (`TempDrop.sharpDropF`, ≥ 10 °F in 3 h; `air-advice.md` still says 15 °F, so the doc is out of date) and mold weather (rain, humidity over 60%, 65 °F or
  warmer). Wildfire smoke exists only in the demo, because it needs Ambee's fire API.
- **How it's worded** (`AirAdvice.swift`, `TheRead.swift`). Facts about the sky only. In the header: "A thunderstorm
  while pollen is high." On the card: "Pollen is high and a thunderstorm is on the way." Staying put: "Keep your
  windows shut until the storm has passed." Going out: "If you've been outside, shower and change clothes when you
  get in, to rinse off pollen." Behind the "i": "A suggestion, not medical advice. If a flare is severe, get medical
  help now." On a flare during the storm: "A thunderstorm came through while pollen was high." Never "you will", and
  never "likely to trigger". The sky gets a soft lightning flash, which stays still with Reduce Motion on.
- **Where it appears today.** On Now only: the header sentence, an advice card in the stack (staying put at home,
  going out anywhere else), and the sky.
- **Status.** The Now event is **built**. Three gaps found while writing this map:
  1. **The pollen half is demo data.** `liveEvent` reads pollen from `DemoPollen` (display-only Midwest seasons) until
     Ambee arrives. On a real phone today, a thunderstorm in "demo high pollen" season fires the heads-up even though
     no pollen was actually measured. **Open:** either hide the storm event until real pollen exists, or say "a
     thunderstorm" without the pollen.
  2. **It doesn't look ahead.** `aheadEvent` only detects a temperature drop and mold, so the storm never reaches the
     forecast hours or the 8 am notification. The `storm_front` detector is **planned** (`air-outlook.md`).
     **Proposed:** an ahead storm event, with "Thursday afternoon: a thunderstorm while pollen is high." in the
     morning notification.
  3. **The citation isn't in the repo.** The brief mentions thunderstorm asthma, but no doc cites it. **Proposed:** add
     Thien F, et al. *The Melbourne epidemic thunderstorm asthma event 2016.* Lancet Planet Health 2018;2(6):e255–63 to
     `air-advice.md` as the rationale for the event.
- **Before felt air has learned,** a forecast hazard is said as general weather. Core has the line "The forecast shows
  … That's a general heads-up, not your pattern yet." (`OutlookCopy.coldStart`), but it isn't wired to any screen.
  **Proposed:** use it for the ahead storm.
- **Rests on.** Never say an attack will happen. One frame for past and future: the same detector runs on a logged
  moment (where it fills a bin) and on a forecast hour (where it drives the heads-up). The advice is a provocation
  for providers (`air-advice.md`).
- **Risk.** Alarm. "On the way" is a weather forecast, which is fine, but a red pill next to it could read as a
  forecast for your body. The advice copy isn't cited yet and has to be cited or removed before user testing.
- **Watch.** Read the card aloud and ask: "What is felt air telling you?" If the answer is "I'm going to have an
  attack", the wording failed. **A4** (mark vs words): does the sparkle read as a cause?

## 6. Insights getting better over time: are there levels? (Pandji)

- **Doing / thinking / feeling.** Logging and waiting. *"When does it tell me something?"* Impatient. The catch:
  **learning moves at the pace of your flares.** Baselines fill in at about three a day, so 20 of them take about a
  week. Eight rescue moments, though, take as long as eight flares do. A person who flares twice a month waits
  about four months, and that's good news about their asthma that feels like the app is broken.
- **What exists.** The gate (`LiftGate.default`): **8 rescue moments, 20 baselines**, then per pattern **4 rescue
  moments in that level, lift > 1.25**. `GateProgress.isMet` is the switch. Before it, Insights shows the
  `LearningRing` (it fills to the lesser of the two progresses, with no number) and "Still learning…" with "Keep
  logging when you use your inhaler. felt air fills in your ordinary moments on its own, and your profile appears
  here once it has learned." After it: "Learned · may shift with the seasons". The ring button by the + breathes
  while learning and bounces once on learned. The sound `learned.wav` plays.
- **The constraint.** No counts and no scores on screen (owner, Oct 17). "Level 3 of 5" would be a number, and it
  would be gamification.

**Three options:**

| | Model | What the person sees | For | Against |
|---|---|---|---|---|
| **A** | **Two states (today).** Still learning → Learned · may shift with the seasons | The ring, then the profile | Simple, already built, honest | One long flat wait. Nothing new arrives between day 1 and the gate |
| **B ★** | **What felt air can say (unlocks, not levels).** Four stages, each one a *new kind of sentence*, not a rank: **Your air** (day 1: the read, events, general heads-ups) → **A first pattern** (the first gated row: the sparkle ✦ appears on Now, and the verdict pill starts comparing) → **Your profile** (enough categories for an archetype) → **Through a season** (a second profile snapshot, or one season held) | No meter after the ring. A one-time card when each new thing becomes possible: "felt air has noticed something about your flare days." Profile history carries the dates | It matches how the code already gates (row gate, archetype, `ProfileSnapshot`), it gives the slow-flare person something before the overall gate, and it's in words | Four moments to design and write. It must never say "level" on screen. The first pattern can come from a single strong row, so the copy has to stay modest |
| **C** | **The radar fills in.** Each category earns its word on its own (Often / Maybe / Not much / Not tracked yet) | A radar that's sparse at first and grows | Shows breadth and where the gaps are (pollen) | Reads as a score sheet. Partial radars look like "low asthma in weather". Hard to read at a glance |

**Recommendation: B**, with A's labels kept for the profile itself. A level is a change in what felt air is allowed to
say, and the code already defines those changes. Add one line for the slow case (**proposed**): "Fewer flares means
this takes longer. That's good news too." Take the "learned" date from `ideas.md` ("Learned since September"),
which says how settled the profile is without a number.

- **Risk.** The ring is still a quantity in disguise. Keep it as an ambient thing, not a progress bar to chase.
  "Nothing stands out yet" is a real result of being learned, and it must not feel like failure.
- **Watch.** Ask what they think the ring means. Ask whether "Nothing stands out yet" feels like a broken app.
  **Candidate test:** archetype name vs no name (`ab-tests.md`).

## 7. Your profile, learned (Pandji: "full profile identified … we're still learning")

- **Reframe.** Avoid **"full"** and **"identified"**. A profile is never complete, and "identified" sounds like a
  diagnosis. Patterns are associations, the season changes them, and pollen isn't measured yet. The built words
  already say it better: **"Learned · may shift with the seasons"** on top of an archetype that's provisional by
  design (`Archetype.swift`: "provisional by design ('So far…')").
- **What it means.** The overall gate is met *and* at least one category has a gated pattern. It's a dated snapshot
  (`ProfileSnapshot`), and it's re-checked as logs and seasons arrive.
- **What it looks like** (built, `InsightsView`, `personal-insights.md`). "Personal Insights". The archetype name and
  its line, e.g. **Hot, hazy days**: "Your flare days tend to be hot, with ozone or fine particles up." The radar.
  "What shows up on your flare days", a card per category in words (Often / Sometimes / Maybe), listing what isn't
  measured yet in grey. **When** ("Mostly in the afternoon.") and **Where** ("Mostly at home."). Your profile history.
  Your moments, with an export.
- **The "still learning" half (proposed).** A short "What felt air can't see" line under the profile: pollen (until
  Ambee, so "Not tracked yet"), colds and viruses, missed controller doses, anything you didn't say. This matters
  most for **Allergen-led**: today it can only come from confirmed voice tags (pets, mold), never from measured
  pollen.
- **Rests on.** Code finds the pattern and the template says it. "Often shows up on your flare days" is the only claim
  felt air makes. It never says "triggers" (`personal-insights.md`).
- **Risk.** Identity lock-in ("I'm Effort-led", read as exercise-induced asthma, which `provider-review.md` flags).
  Quantified self. Or reading the name as a diagnosis.
- **Watch.** "In your own words, what is this telling you?" Listen for "cause" and "diagnosis". **A4**. The candidate
  test on the archetype name.

## 8. The seasons shift it (proposed stage)

- **Doing / thinking / feeling.** Autumn arrives and the profile changes from Hot, hazy days to Allergen-led.
  *"Was it wrong before?"* Unsettled, unless felt air told them this could happen.
- **Touchpoints.** Insights › Your profile history ("Your profile can shift with the seasons. felt air keeps a
  snapshot each time it changes, and once a month." It's **built**, with a demo summer → pollen autumn). The season
  card ("Autumn. What shows up on your flare days may shift; felt air keeps watching.") is **proposed** in `ideas.md`,
  and it needs a rewrite to drop the semicolon.
- **Rests on.** The hypothesis in `personal-insights.md` that profiles move with the seasons. The look-back finding
  (Su 2022: lags of 0–3 days).
- **Risk.** A change with no explanation reads as the app being unreliable. Too many changes read as noise.
- **Watch.** Show the demo history and ask whether two profiles make felt air more trustworthy or less.

## 9. For your next visit (proposed stage)

- **Doing / thinking / feeling.** An appointment is coming up. *"What do I even say?"* The diary should make that
  conversation better.
- **What it would be** (`journaling-clinical.md` §4). One screen, in words: the rescue moments since the last visit
  with their symptoms, triggers and air; what shows up on flare days; the outcomes (night waking, activity limited,
  urgent visits, oral steroids) as a list; and the line "felt air records; it doesn't score control. Your action plan
  is the plan." It would be shared as PDF or text. "My action plan" would live in Settings, opened from the capture
  card's "i".
- **Status.** The export table is **built** (Insights › Your moments). The summary and the action plan are
  **proposed**.
- **Rests on.** The four control domains in NAEPP EPR-3 Fig 3-5c and GINA 2024 Box 2-2. NICE NG245: the benefit came
  from a person acting on the diary. No Rules of 2 and no ACT-like score on screen.
- **Risk.** Turning into a control score by the back door. Counts creeping in. A clinician who doesn't have a minute.
- **Watch.** Hand it to the doctor at Friday's critique and ask what the first line should be. **Candidate test:**
  the summary vs the moments list.

## When things go wrong (a lane under every stage)

| Case | What happens (built unless marked) | The words |
|---|---|---|
| No air reading | The log saves anyway, and the air is marked failed or partial | "Couldn't read the air here just now. Logging still works." |
| No location | You can still log | "You can still log without it." |
| Button out of range | It queues up to 32 presses and resends every 3 s once connected. The LED pulses | A press that arrives more than 15 min late is saved **without** air, since "now" would be the wrong air |
| Phone away from the watch | Same 15-minute rule as the button | — |
| No button to hand | The +, the watch, or Control Center's "Rescue voice note" | — |
| Lock Screen card lapsed (8 h limit) | It falls back to a notification. Covering the gap needs push-to-start, which needs a server (**open**) | — |
| Wrong kind, or a stray press | Undo for 10 s. A merged press takes one puff off (**open**: show "2 puffs"?) | — |
| Apple Intelligence off | Keyword tag rules only, silently | — |
| Health declined | Body says it has nothing to read | "Nothing to read yet" |

---

## Moments that matter most for Friday (the demo)

1. **First capture.** The sky draws in for where you're standing: "the air, here, right now." (Stage 2.)
2. **One press during a flare.** The felt button's orange cap, the slow LED breath, then "Rescue logged. What's
   going on?" on the Lock Screen. Then the chat capture with lit words, afterwards and never during. (Stage 4,
   A1.)
3. **A calm heads-up.** The Air event demo set to the thunderstorm: lightning in the sky, "A thunderstorm while
   pollen is high.", staying put vs going out. Say out loud what it doesn't say. (Stage 5.)
4. **Still learning → Learned.** The ring breathing, then the Hot, hazy days data set landing on "Learned · may shift
   with the seasons" with its sound. (Stages 6–7.)
5. **The profile moves.** Profile history: summer Hot, hazy days → autumn Allergen-led. (Stage 8.)
6. *(If there's time)* the "For your next visit" sketch, for the doctor. (Stage 9.)

## Open questions for Pandji

1. **"Full profile identified":** are you happy for stage 5 to read "Learned · may shift with the seasons" plus a
   "What felt air can't see" line, and drop "full" and "identified"?
2. **Levels:** option B (what felt air can say: your air → a first pattern → your profile → through a season), with no
   meter after the ring and a one-time card for each? And do we want the "fewer flares means this takes longer" line?
3. **The thunderstorm and pollen:** its pollen half is demo pollen until Ambee. Hide it on real phones, drop "pollen"
   from it, or keep it for Friday only?
4. **The storm in the look-ahead:** should it reach the 8 am notification and the forecast hours (a new ahead
   detector), and can we use the "general heads-up, not your pattern yet" line before felt air has learned?
5. **The quiet days:** is the morning notification on by default the right call, and should the copy before learned
   be "See today's air." instead of a comparison that doesn't exist yet? And does the location data card name Ambee
   before it's a source?
