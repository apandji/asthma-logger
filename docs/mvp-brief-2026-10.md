# MVP brief: the presentation next week

Written Oct 16, 2026 from a conversation with the owner, for the orchestrating agent and the people it hands work to. Read the root `AGENTS.md`, `ios/AGENTS.md` and `docs/design/felt-air-language.md` first. Where this brief and the code disagree, this brief is what we want and the code is where we are.

Three things have to work on the phone, in this order of importance. Everything else waits.

## Decisions (owner, Oct 16)

| Question | Decision |
|---|---|
| Words for the two sides of the comparison | **Baseline** (ordinary days, no rescue use) and **flare days** (days with rescue use). Moments keep their inhaler names: **Rescue** and **Standard**. Never "attack". |
| First capture in onboarding | Saved as a **baseline** moment with a `firstCapture` flag, labelled "Your first capture", neutral ring. It counts toward baseline. |
| Double press / multi-puff merge | **Superseded 2026-10-17 — see Event Window below.** (Oct 16 had said ~2 s → one moment, 2 puffs.) |
| Insights for the presentation | A **labelled demo state** (Design crit) with a closed ring and a profile, beside the owner's real, still-filling ring. Demo stays out of real patterns. |
| Heavy reliever use | **Count + guideline line.** Show today's rescue count; above a cited guideline threshold, one plain line pointing to care and the person's action plan, source named. **No clinical / overuse alert notifications** in the MVP. |
| Archetype research | A **short cited doc**: 3–5 archetypes, 2–3 real citations each, the Ambee signals behind each, about a page each. |
| Presentation | **Live pairing on stage** from a fresh install (needs a reliable reset), a **recorded pairing** as backup, and the **doctor table**. |

## Decisions (owner, Oct 17)

| Question | Decision |
|---|---|
| **Event Window** | **2 minutes.** First press opens a moment window; further presses in that window update the **same** moment’s puff count (and the one Lock Screen “record a note” notification). Header shows e.g. "Rescue · 2 puffs". This replaces the Oct 16 ~2 s-only merge. Priming (rapid presses → confirm → exclude from flare counts) stays a follow-on edge case. |
| **Notification to Record** | **Not clinical.** After a press, a Lock Screen notification lets the person add a **voice note to that moment without leaving the Lock Screen.** Use a **Notification Content Extension** with hold-to-talk-style UI (learn from push-to-talk / talk-to-agent patterns; do **not** use Apple’s PushToTalk framework — that is for server walkie-talkie channels). Later puffs in the Event Window update the same notification. Separate from heavy-reliever *alert* policy above. |
| **Insights usefulness** | Keep the existing Insights destination. Make it useful with a **spider (radar) chart** of relative correlation across four families from the product board: **Biologics**, **Weather dynamics**, **Particulates & gases**, **Physical exertion**. Scores come from gated personal lift / rates and always expose raw counts — never a percent risk or “attack will happen.” |


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

- ~~Kind of the first capture~~ Decided: `MomentKind.okay` (baseline) with `isFirstCapture = true`, its own label, a neutral ring; counts toward baseline, never toward flare days.
- Watch pairing in onboarding or only on the Devices page? Suggest Devices only; keep onboarding to one device.

---

## 2. The capture: a press makes a moment, visibly

### What we want

Pressing the button, physical or the +, always produces a moment and the person always sees it: the toast at the top ("Rescue logged · Undo"), the ripple from the + in the moment's colour, the dot landing on the track under the playhead, the header turning to "Just now". No press is ever silent, and no press is ever lost (presses queue on the button while the phone is away and arrive with `ageMs`).

**Event Window (2 minutes).** First press creates a moment and starts a 2-minute window. Further presses in that window update the same moment’s `puffs` (and refresh the one Lock Screen note notification) instead of stacking silent duplicates. After the window closes, a new press starts a new moment.

- On the track: one swatch for the windowed moment with a small puff count ("2"); if Rescue and Standard both land in the same window, show both colours and list both in details (product rule TBD if mixed caps share one moment or two linked moments).
- In the header: "Rescue · 2 puffs · Today, 9:41" when the kinds match.
- In the pattern engine: frames stay per hour (`predictive-engine.md §3`); puff count does not multiply frames.
- **Priming** (board): several presses in rapid succession may prompt “Were you priming?” — if yes, exclude from flare / symptom counts. Thresholds still open.

### What exists

`LogService.log` (phone), `ButtonLink` (felt button, with dedupe by `bootID`+`seq`), the watch path. Toast and ripple on both homes. `NowTimeline` and `TimelineTrack` draw one swatch per moment. Event Window merge and `puffs` field are **not** shipped yet.

### Open

- ~~Merge window length~~ Decided 2026-10-17: **2 minutes** (see Decisions). Needs `puffs` on `LogEvent` (default 1), merge by the phone while the window is open (by press time / `ageMs`), Health write updated to the puff count, and one updatable Lock Screen notification for the voice note.

---

## 3. Insights: learning progress, what we need, a profile

### What we want

An Insights page (the sheet exists; this is a redesign of what's in it) with three parts:

**a. Progress.** A ring, Apple Watch style, with the sparkle in the middle, that closes as felt air learns. It is honest about what it's waiting for: two counters under it, "3 of 8 flare days" and "12 of 20 baseline days", from `GateProgress` (`minAttacks`, `minBaselines`), plus a line about time ("about two more weeks at this pace"). The ring fills by the smaller of the two fractions. When it closes, it stays closed and the page changes to b and c. For the presentation, a labelled demo person shows the closed ring and a profile (Design crit › Insights state).

**b. Patterns.** What we have today: the lift table narrated, raw counts always shown, "8 of 14 flare days vs 3 of 40 baseline days".

**c. Your profile (spider).** The usefulness upgrade for Insights (2026-10-17): a **spider / radar chart** with four axes — **Biologics**, **Weather dynamics**, **Particulates & gases**, **Physical exertion** — each a relative correlation from gated lift on that family’s bins (raw counts on tap). Plain-words callouts can still name what lined up with flare days ("Ozone afternoons", "Cold, dry mornings"). Archetype research (below) still informs copy; the chart is the visual spine. Hand to a provider with `Journal/DoctorSheet.swift`. Never a percent risk. Biologics stay muted until pollen exists; exertion stays thin until tags/motion/Health reads are approved.

**Language.** Decided: **baseline** and **flare days** on screen (see Decisions). Update `docs/design/felt-air-language.md` and every string that says "calm", "usual days", "okay days" or "I'm okay". The verdict line becomes e.g. "Looks like your baseline" / "A bit like your flare days" / "Matches your flare days". Keep testing it with users, per Kate's note that the rescue / maintenance words need testing too.

**Alerts.** Decided: count + guideline line, no notification. Show today's count ("4 rescue moments today"); above a threshold taken from published guidance, one plain line pointing to care and to the person's own action plan, with the source named. The number and wording come from the research doc, are reviewed by the owner, and never say "attack" or a percentage.

### What exists

`Insights/InsightsView.swift`, `InsightsModel` (rebuild, narrate, loadForecast), `GateProgress`, the ring button (`InsightsRingButton`) that already fills while learning, the Now home's verdict line, `DoctorSheet` CSV.

### Research task (for the orchestrator, before any profile copy is written)

Find and cite, with links, in a short doc `docs/research/archetypes.md`:

1. **Asthma phenotypes and triggers** in the clinical literature that map to environmental signals we can measure: allergic (pollen, mould), pollution-sensitive (PM2.5, ozone, NO₂), weather-sensitive (cold dry air, humidity, temperature swings, thunderstorm asthma), exercise-induced, viral-triggered (which we can't see). Start with the GINA report, Wenzel's phenotype work, and reviews on outdoor air pollution and asthma. Say which phenotypes are evidence-backed and which are folk categories.
2. **Reliever overuse thresholds** used in guidelines (per day, per week, canisters per year) and the wording guidelines use for when to seek care. Quote the sources; we will paraphrase, not invent.
3. **What Ambee gives us** per hour and place (pollen by type and species, air quality by pollutant, weather, fire, soil) from `docs/ambee-trigger-datasets.md`, and which of the phenotypes in (1) each dataset can support. Pollen is the big one: tree / grass / weed by species is exactly the allergic-phenotype signal.
4. A proposed **profile shape**: a small set of named archetypes (3–5), each with the signals that define it, the minimum evidence before felt air may say it (reuse the gate: 8 flare days, 20 baseline, lift > 1.25 on that signal), and a plain-words sentence template. A person can match more than one, or none.

Keep it short: about a page per archetype, 2–3 real citations each.

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

1. **Event Window (2 min)** + `puffs` field + header ("2 puffs"), then Lock Screen **Notification Content Extension** for voice note (not clinical alerts).
2. Onboarding pairing moment with the first capture, and a **reliable reset** for a fresh install on stage (Settings › Design crit, and `ios/scripts/fresh-install.sh`).
3. Devices page and multi-button routing.
4. Insights progress ring with the real counters, then **spider chart** (four families) from gated lift — demo crit state for the presentation.
5. Research doc on archetypes and thresholds (feeds spider callouts / profile copy).
6. Physical exertion signal (tag/motion first) so the spider’s fourth axis isn’t empty; Health reads only after ask.
7. Record the pairing moment as a backup video for the presentation (`docs/demo-runbook.md`).
8. Widget / Action Button log triggers (after Event Window is solid).
