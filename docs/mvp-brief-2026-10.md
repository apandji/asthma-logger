# MVP brief: the presentation next week

Written Oct 16, 2026 from a conversation with the owner, for the orchestrating agent and the people it hands work to. Read the root `AGENTS.md`, `ios/AGENTS.md` and `docs/design/felt-air-language.md` first. Where this brief and the code disagree, this brief is what we want and the code is where we are.

Three things have to work on the phone, in this order of importance. Everything else waits.

1. **Onboarding**: no data → pair the button → first capture.
2. **The capture**: pressing the button (software or felt) makes a moment, every time, with no doubt that it happened.
3. **Insights**: how far felt air has learned, what it needs, and the start of a profile you could hand a provider.

Each section says what we want, what exists today, what's open, and the rules that bind it.

---

## 1. Onboarding: nothing → paired → first capture

### What we want

The first run is a story with one magical moment in it: the button talks to the phone. The model is the Apple Watch pairing (the particle cloud on the watch, the phone recognising it, the sense that two objects found each other). Ours: you press the felt button, the phone answers on screen at once, and that press becomes your **first capture**: a sky, drawn for the air around you right now. It is labelled *first capture*, not Rescue or Standard, so nothing clinical is asserted by a test press.

Steps, as a flow:

1. **Welcome.** What felt air is, in one screen. Not medical advice.
2. **Where you are.** Location permission (precise), with the reason: the sky is drawn from the air near you.
3. **Your felt button.** The pairing moment. Bluetooth prompt, then "press the button". The phone shows it listening (the grain breathing, a pulse), and when the press arrives, the sky ripples in from the + in the moment's colour and the header reads "Your first capture · Today, 9:41 · Tower Grove South". This is the moment to get right.
4. **Health**, optional: write inhaler use to Health.
5. **Learning.** What happens next: felt air samples calm moments on its own, and needs N rescue moments and M calm days before it can compare (real numbers from the gate).

Skippable at step 3 if you have no button; the + does the first capture instead.

### Devices page

Today the app remembers one peripheral id and nothing else about it. We had two app instances and two buttons in the room today and couldn't tell what was paired to what. We need a **Connected devices** page (Settings › Devices):

- Each paired button as a row: a name you can edit ("Orange cap, kitchen"), its id, caps it has (rescue / standard), last press time, battery if the firmware ever reports it, and a **Forget** action.
- **Add a button** from this page, the same pairing moment as onboarding.
- The Apple Watch as a row too (paired through Watch, we just show it's there and when it last sent a moment).
- A press from an unknown button while the app is open offers to pair it, never logs silently.

Protocol note: `ButtonPacket` carries `cap`, `bootID`, `seq`, `force`, `ageMs`; the phone keys the paired device by the CoreBluetooth peripheral id (`ButtonLink.pairedKey`). For several buttons, store an array of `{peripheralID, name, addedAt, lastSeen}` and route presses by peripheral id. The firmware doesn't need to change for this.

### What exists

`ios/AsthmaLog/Onboarding/OnboardingView.swift` has steps welcome · sync · here · health · learn with photos. `App/ButtonLink.swift` pairs one button and shows a Bluetooth sheet. `docs/smart-button.md` has the protocol. The capture ripple and the "just now" header exist on the Now home (`Journal/NowHomeView.swift`).

### Open

- Does the first capture save as a moment of a new kind (`firstCapture`), or as a calm moment with a flag? It must never count as rescue in the pattern. Suggest: `MomentKind.okay` with `isFirstCapture = true`, shown with its own label and a neutral ring.
- Watch pairing in onboarding or only on the Devices page? Suggest Devices only; keep onboarding to one device.

---

## 2. The capture: a press makes a moment, visibly

### What we want

Pressing the button, physical or the +, always produces a moment and the person always sees it: the toast at the top ("Rescue logged · Undo"), the ripple from the + in the moment's colour, the dot landing on the track under the playhead, the header turning to "Just now". No press is ever silent, and no press is ever lost (presses queue on the button while the phone is away and arrive with `ageMs`).

**Several moments on one timestamp.** Two puffs a minute apart, a rescue then a standard, a double press. Today they stack on the track as overlapping swatches and the header shows only one. We want:

- On the track: a **cluster** swatch when moments are within ~10 minutes: one dot with a small count ("2"), ringed with both colours if the kinds differ, that fans open into its moments when it's under the playhead (or on tap).
- In the header: "Rescue · 2 puffs · Today, 9:41" when the kinds match; "Rescue and Standard · Today, 9:41" when they don't.
- In the details: all of them listed, each with its own undo/delete.
- In the pattern engine: nothing changes; frames are per hour already (`predictive-engine.md §3`).

### What exists

`LogService.log` (phone), `ButtonLink` (felt button, with dedupe by `bootID`+`seq`), the watch path. Toast and ripple on both homes. `NowTimeline` and `TimelineTrack` draw one swatch per moment.

### Open

- Double press on the felt button within 2 s: one moment or two? Suggest one, with `puffs: 2`, since a double press is the usual way to take two puffs. Ask the owner.

---

## 3. Insights: learning progress, what we need, a profile

### What we want

An Insights page (the sheet exists; this is a redesign of what's in it) with three parts:

**a. Progress.** A ring, Apple Watch style, with the sparkle in the middle, that closes as felt air learns. It is honest about what it's waiting for: two counters under it, "3 of 8 rescue moments" and "12 of 20 calm days", from `GateProgress` (`minAttacks`, `minBaselines`), plus a line about time ("about two more weeks at this pace"). The ring fills by the smaller of the two fractions. When it closes, it stays closed and the page changes to b and c.

**b. Patterns.** What we have today: the lift table narrated, raw counts always shown, "8 of 14 rescue days vs 3 of 40 calm days".

**c. Your profile.** The new part. As the pattern table fills in, felt air says what kind of air you react to, in plain words: "Your rescue days line up with pollen more than anything else", "Cold, dry mornings show up on your rescue days", "Ozone afternoons". These are **archetypes**, and the orchestrator should do the literature work before we name them (see Research below). The profile is also what a person hands a provider, together with the table of moments that already exists (`Journal/DoctorSheet.swift`).

**Language.** The owner wants to explore "baseline" and "rescue mode" as the two states. Today the vocabulary doc says *calm moment* on screen and keeps *baseline* for docs. Decide once, in `docs/design/felt-air-language.md`, then use it everywhere. Suggestion to test with users: **Rescue** for the moments, **calm days** for the comparison, and "baseline" only when talking to providers.

**Alerts.** Someone said today that more than X rescue uses in a day is an emergency. We will not diagnose. What we can do, honestly: show the count ("4 rescue moments today") and, above a threshold taken from published guidance, a plain line pointing to care and to the person's own action plan, with the source named. The number and the wording must come from the literature (below), be reviewed by the owner, and never say "attack" or a percentage. Local notification only if the owner approves the permission prompt (`AGENTS.md`: ask before a new permission).

### What exists

`Insights/InsightsView.swift`, `InsightsModel` (rebuild, narrate, loadForecast), `GateProgress`, the ring button (`InsightsRingButton`) that already fills while learning, the Now home's verdict line, `DoctorSheet` CSV.

### Research task (for the orchestrator, before any profile copy is written)

Find and cite, with links, in a short doc `docs/research/archetypes.md`:

1. **Asthma phenotypes and triggers** in the clinical literature that map to environmental signals we can measure: allergic (pollen, mould), pollution-sensitive (PM2.5, ozone, NO₂), weather-sensitive (cold dry air, humidity, temperature swings, thunderstorm asthma), exercise-induced, viral-triggered (which we can't see). Start with the GINA report, Wenzel's phenotype work, and reviews on outdoor air pollution and asthma. Say which phenotypes are evidence-backed and which are folk categories.
2. **Reliever overuse thresholds** used in guidelines (per day, per week, canisters per year) and the wording guidelines use for when to seek care. Quote the sources; we will paraphrase, not invent.
3. **What Ambee gives us** per hour and place (pollen by type and species, air quality by pollutant, weather, fire, soil) from `docs/ambee-trigger-datasets.md`, and which of the phenotypes in (1) each dataset can support. Pollen is the big one: tree / grass / weed by species is exactly the allergic-phenotype signal.
4. A proposed **profile shape**: a small set of named archetypes (3–5), each with the signals that define it, the minimum evidence before felt air may say it (reuse the gate: 8 rescue, 20 calm, lift > 1.25 on that signal), and a plain-words sentence template. A person can match more than one, or none.

Rules for the research: real citations only (title, authors, year, link); mark anything not verified; no medical advice in the app copy; the archetype is "what your rescue days have in common", never "what you have".

---

## Rules that bind all three

- Never say "attack", never a percent risk, never a cause, never "the air you breathed". Outdoor air only.
- Demo data stays labelled and out of the pattern.
- Fail open: a dead button, a missing key or a failed call never blocks a log.
- Ask before: a new dependency, a new data source, a new permission prompt, anything leaving the device.
- Every PR says what was verified: tests, built, tried on the phone. Don't open or merge until the owner has tried it.
- Styling through `Theme/`; vocabulary from `docs/design/felt-air-language.md`; crit switches for open design questions.

## Suggested order of work

1. Devices page and multi-button routing (unblocks demo day with two phones).
2. Onboarding pairing moment with the first capture.
3. Cluster swatches and the "2 puffs" header.
4. Insights progress ring with the real counters.
5. Research doc on archetypes and thresholds.
6. Profile copy, only after 5.
