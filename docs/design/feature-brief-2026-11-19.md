# felt air: feature brief (Nov 19, 2026)

For April's Claude. Read `AGENTS.md` and `ios/AGENTS.md` first. This brief says what to define or build next, what is already in the code, and how each feature ties to the two thesis threads.

Presentation is Nov 20. Anything not marked **demo** is a design definition, not a build.

## Ground rules (from AGENTS.md and the owner)

- Not medical advice. Any guideline wording names its source.
- No counts, ratios or countdowns on screen. The puff count is the one exception: it is a dose, the number the inhaler itself says.
- Never say an attack will happen. Never call a moment stressful, anxious or calm on the person's behalf.
- Orange is the only "yours" / risk ink.
- Work in the Menus look. It is the default as of Nov 19.
- Everything stays on the phone. Ask before a new permission, dependency or data source.

## The two thesis threads

**Pandji: hide and reveal.** Invisible systems flatten complexity so an experience feels simple. Where someone else decides how a person engages with technology, making what is concealed legible gives the decision back.
Design test: *does this screen show what the app read, what it could not see, and what is a guess?*

**April: emotional technology and pseudanthropism.** Technology that acts like a person, or claims to read feelings, takes something from the person.
Design test: *who names the feeling, the app or the person? Does the app ever speak as "I" or "me"?*

Each feature below ends with one sentence for each thread. Use them on the slides.

---

## 1. The "added" panel, and when puffs run high

**Exists:** `ios/AsthmaLog/Journal/LoggedPanel.swift`. A panel rises after a log: "Rescue logged", a puff stepper (− / +), "Quick journal", and "Were those test sprays?" when three presses land inside ten seconds. The guideline rules are in `ios/AsthmaCore/Sources/AsthmaCore/Journal/RelieverUse.swift` (again within 4 hours; more than 2 days this week) and show as a card on the older Now deck.

**Define:**
- The over-threshold state inside the panel, in the Menus look. The guideline card does not appear to be wired into the Menus files yet.
- A puff-based rule to sit beside the two existing ones. Proposed, **to be checked by a clinician and against `docs/research/guidance-and-archetypes.md` before any user sees it**:
  - Usual dose: 2 puffs every 4–6 hours as needed (albuterol label).
  - Action-plan yellow zone: 2–4 puffs, repeatable every 20 minutes for up to an hour (NHLBI template).
  - Trigger: more than 4 puffs in one moment, or a third round inside an hour.
  - Copy pattern (same as the existing checks): what the guideline says, "follow your action plan", "if it isn't helping or breathing is hard, call 911", and the source line.
- Tone: the card informs, it does not scold. No red alarm styling; orange only.

**Hide/reveal:** the panel shows the rule and where it comes from, so the person can weigh it instead of obeying it.
**Emotional tech:** the app states a guideline; it does not say it is worried about you.

## 2. Logged while the app is closed

**Exists:** `ios/AsthmaLog/Voice/QuickRecord.swift`, `QuickRecordLive.swift`, `ios/AsthmaLogWidgets/QuickRecordLiveActivity.swift`. A press on the felt button or the watch starts a Lock Screen recorder (Live Activity). If iOS won't allow it, a notification offers "Add a voice note" plus three quick tags (Exercise, Cold air, Pets).

**Define:**
- The Live Activity's states in the Menus look: just logged, listening, tags suggested, saved.
- Whether the puff count and the over-threshold line (feature 1) appear on the Lock Screen. Recommendation: the count yes, the guideline line no; a Lock Screen is public.
- Which quick tags appear. Three fixed ones today; could be the person's own most confirmed tags.

**Hide/reveal:** the Lock Screen says what was recorded and lets the person decline to add more.
**Emotional tech:** it offers once and goes away; no streaks, no "we missed you".

## 3. Words from the voice note (not sentiment)

**Exists:** `ios/AsthmaLog/Intelligence/OnDeviceModel.swift` and `ios/AsthmaCore/Sources/AsthmaCore/Journal/VoiceNoteTags.swift`. Apple's on-device model (keyword rules when it is off) picks tags from a closed list of 22 (`JournalTag.swift`: triggers, symptoms, outcomes). The person confirms; only confirmed tags count. There is no sentiment analysis, on purpose: `CalendarReader` says "a meeting is never called stressful; you tick Stress if it was".

**Define:**
- **Show the evidence.** Each suggested tag points at the words in the transcript that led to it ("…ran for the bus…" → Exercise). Tap a tag to see its words; tap again to reject.
- Suggested vs confirmed must look different (outline vs filled).
- A position on sentiment, stated on a slide: *the app isolates words; the person names the feeling.* If a feeling control is wanted, it is one the person sets (like Health's State of Mind), never one the model fills in.
- "Stress" and "Laughing / crying" are already tags. Decide whether the model may suggest them or only the person may add them. Recommendation: person only.

**Hide/reveal:** the model's reading of your note is shown with its reasons and is yours to overrule.
**Emotional tech:** refusing to label feelings is the feature.

## 4. Calendar view

**Exists:** `ios/AsthmaLog/Journal/MenusMomentsView.swift`: the Moments tab with Day / Month / Year, rescue filled and standard outlined. An older `DaysView.swift` and `docs/design/weave-calendar-prototype.html` hold earlier ideas.

**Define:**
- Three kinds of day that must not look alike: inhaler day, ordinary day the app sampled (baseline), and a day with no data. Today the last two read the same.
- Whether air shows in the month grid at all (a faint tint) or only on tapping a day.
- Tapping a day: its moments, their notes, and what was on (calendar event, place).
- No totals ("12 this month"). Words only.

**Hide/reveal:** ordinary days are the half of the comparison the app usually hides; the calendar makes them visible, and shows where it knows nothing.
**Emotional tech:** a record, not a scorecard. No good or bad days.

## 5. Evening look-back

**Built Nov 19 (first version):** `ios/AsthmaLog/Journal/EveningLookBack.swift`, staged from Demo and development. April's Claude: refine the look and the cues.

**Before that:** only a 6 pm notification ("2 moments today · Add what was going on…") in `QuickRecord.scheduleEvening()`. Memory cues are ready: `CalendarReader.around()` gives the event near a moment; each `LogEvent` has a place name. Photos are not built (opt-in, later).

**Define (new screen):**
- When it appears: opening the app after 6 pm with today's moments missing a note. Dismissible, never blocking, shown once per evening.
- Headline: "You captured 2 moments today." (A count of your own moments today is a plain fact, not a metric; check with Pandji against the no-numbers rule. Alternative: "Two moments today.")
- Each moment as a card with its cues: time, place, what was on your calendar, the air in words. Photos as a greyed "later" slot or left out.
- One mic per moment, or one note for the whole day? Recommendation: per moment, since tags attach to moments.
- "Not sure" and "Skip" are first-class answers.
- For the demo: a hidden Settings switch to show it at any hour.

**Hide/reveal:** the app lays out what it already holds about your day and asks you for the part it cannot see.
**Emotional tech:** it prompts memory with facts, not with a persona asking "how was your day?".

---

## Not on the original list

**6. "What this moment holds" (the reveal feature).** On the added panel or moment details: what was stamped (place, outdoor air, source, how far the monitor is, as of when), what the app could not see (indoor air, anything in the room), and what is a guess (indoor/outdoor, suggested tags). The data is already on every reading (`source`, `asOf`, `spatialScale`, `distanceKm`, `confidence`). This is the clearest single screen for Pandji's thesis and the list has nothing like it.

**7. The app's voice.** `Interview.swift` asks "What can you tell me about University City at 4:52 PM?" and the evening nudge says "so felt air can learn". Decide: does the app ever say "me", or "learn"? Recommendation: no first person; "felt air compares" over "felt air learns". Sweep onboarding, notifications and the interview.

---

## Before the presentation

1. Which features are shown live and which are described as next.
2. The demo person is the navigator (see `docs/demo-runbook.md`).
3. Insights on real data will likely read "Still learning…" (needs 8 inhaler logs and 20 baselines). Pick the fallback scenario.
4. The closed-app demo needs a felt button or watch press. Do Not Disturb hides the fallback notification.
5. `docs/demo-runbook.md` is from Oct 8 and points at an old branch.
6. One sentence per feature for each thesis (above).
