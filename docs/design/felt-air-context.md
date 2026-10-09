# felt air: design context

What the design team is exploring, what the onboarding looks like today, and the critique of it. Read this before design or onboarding work. Last updated 2026-10-02 from the Figma file and FigJam board below.

The app's visual spec is [visual-style.md](visual-style.md). Product rules (honest numbers, no prediction, fail open) are in the root [AGENTS.md](../../AGENTS.md).

## Who and where

- **Designers:** Pandji (also the repo owner) and April.
- **Design file:** [Felt Air MASTER FIGMA](https://www.figma.com/design/iaM1eEGmXjvLK4y9Hktmgi/Felt-Air-MASTER-FIGMA?node-id=973-160). One page, "FOUNDATIONS".
  - Onboarding journey map: node `999:1399` ("Onboarding Flow" section).
  - Onboarding screens: node `1019:1654` ("Section 1"), 8 frames: welcome `999:1418`, register `999:1445`, permissions `996:854` and `996:957`, setup inhaler `999:1599` and `996:988`, camera scan `1003:1640` and `999:1612`.
- **FigJam board:** [FELT AIR MASTER FIGJAM](https://www.figma.com/board/hhS2YdEnQE3pDxCAipUVlE/FELT-AIR-MASTER-FIGJAM?node-id=1011-11).
  - "Questions & thoughts" stickies: page `1011:11`.
  - Claude's onboarding critique board: section `1017:98` (critique cards `1017:104`, refined journey map `1018:98` with table `1018:101`, open questions `1018:258`).
- Figma links need a Figma login with access; the files are not public.

## What's in the design file

- **Precedents:** Propeller Health (smart-inhaler sensor and app), pillowtalk and Stardust (calm, characterful apps; noted "simple interface has character, but not overdone").
- **Colour explorations:** several palettes of muted greens, sky blue, warm off-white, pink and lime.
- **Welcome-screen variants:** the same three-bullet welcome in many colourways, light and dark.
- **Photographic onboarding explorations:** full-bleed photos of trees, grass and sky, a hand holding the inhaler, a breathing silhouette on grey paper, the "felt air" wordmark, one sentence per screen. A narrative sequence: "did you know there was a connection?" → "these are some examples" → "we layer them together to help you become more aware" → "so that you can enjoy the outdoors with more confidence" → "pair your inhaler (option to skip)".
- **Pairing screens:** "pairing…" with a spinner.
- **Hardware:** the felt SmartButton (two colour-coded caps: teal for maintenance, orange for rescue) and a "felt air" cloud lamp, an ambient home device that changes colour when an event happens (target: December).
- **Data views:** dark charts, heatmaps and barcode strips.
- **iOS kit:** an iOS 27 starter kit and local components set in Basier; a Diatype type test.

## Product stance (from the FigJam board)

- **A "felt sensing network":** the body as a sensor (vitals, journals), weather services as centralised sensors, AirBeam as a decentralised sensor, the cloud lamp as an ambient way to make sense of it.
- **Embodied self over quantified self.** The team wants to move away from scores and "readiness" (the Whoop trend).
- **Don't blame the user** (April): "We are building for people with chronic illnesses, which are often outside of their control. We should not 'blame' our users for their 'performance', but instead empower them and help them stay informed."
- **Journaling is optional.** Voice capture should be frictionless, with intelligence turning speech into tags.
- **Screenless is rising** (Whoop, new AI hardware). The cloud lamp and notifications should keep felt air present without opening the app.
- **Provider-led entry:** a refill card with a QR code; an advisor's view is that "provider buy-in is 60% of it". A clinician advisor should be involved in the messy middle of the design process.
- **Stay scrappy:** use the Apple Watch as a mock button soon; get on TestFlight for a small beta.
- **Bands, not units:** generalise temperature, humidity, air quality and pollen into low / medium / high for visualisation. The app's core already works this way.

### Open threads on the board
- Continuous monitoring (audio while sleeping, heart rate, vitals) vs bystander privacy (April's concern about silent recording).
- Maintenance vs rescue inhalers: how many people have, how dosage is set.
- Asthma action plans (zones, peak-flow diary): whether to carry over their language.
- Sleep data as a possible early signal.
- Form factors (compact, extended, "tent mode").
- What to call the persona (another team uses "motivated bystander").

## Onboarding as designed (2026-10-02)

Journey: **Receive** (refill card with QR, or email/SMS link) → **Account** (Sign in with Apple; "kept private, on-device") → **Permissions** (location "requires sharing with Ambee for hyperlocal weather", with "select places you do not want to send"; Health read activity/sleep/vitals and write inhaler usage; microphone) → **Setup** (sync inhaler: type, medication, dosage; or "I do not have") → **First log** → monitoring with weather notifications → **First insight** ("You used your inhaler often when it is…, based on 52 recorded moments").

Screens: welcome (three "did you know" bullets, "Start Pairing"), register, data permissions (Enable Location, Enable Health, a mocked permission alert), setup inhaler (two SmartButtons from the prescriber), add medication (camera scan of the label).

## Critique (Claude, 2026-10-02)

The board has a stronger point of view than the onboarding. Seven changes, by impact:

1. **Time to value.** The aha is weeks away (patterns need at least 8 inhaler uses and 20 I'm okay moments). Give day one a small aha: the first log shows today's outdoor air plus "learning: 1 of 8". Ask each permission when it's first needed.
2. **Lead with the stance.** No scores or blame. "Did you know the weather shapes your breathing" claims cause and effect. Use the photographic explorations for onboarding; keep the working app Apple-native.
3. **Two doors.** Referred (QR knows clinic and inhaler) and self-download (no device). Design what the provider gets and the consent moment. Name the persona first.
4. **No account in v1.** The app is local-first; App Review expects login-free use without account features. Add Sign in with Apple with provider sharing.
5. **Permissions must be true.** Location is optional (logs save without it); not "hyperlocal"; the first iOS prompt has no "Always"; one true privacy sentence; Health asks only for what's used. Keep "places you don't want to send".
6. **The device is optional.** "I do not have" must be a complete path. Prescriber integration doesn't exist yet. Maintenance tracking is a valuable second product; scope it on purpose. Test the Apple Watch button before a camera scanner.
7. **No passive listening.** It records bystanders (some US states require all-party consent). Voice stays opt-in, one moment at a time.

### Refined journey

| Step | Person | felt air | Asks for |
|---|---|---|---|
| 1. Find | Refill card (QR knows clinic and inhaler), or downloads alone | Opens on the right door | Nothing |
| 2. Welcome | Reads one sentence over a photo | Says what it is; not medical advice | Nothing |
| 3. How you'll log | Apple Watch, felt button, or tap in the app | No device is a complete path | Bluetooth or Watch, if chosen |
| 4. Location | Hears why, sees the real prompt, marks private places | While Using only | Location (While Using) |
| 5. First log | Logs now | Today's outdoor air + "learning: 1 of 8" | Health write, optional |
| 6. First week | Logs when they use the inhaler | Adds I'm okay moments; shows progress | Nothing |
| 7. Week-1 nudge | Asked whether felt air can notice their places | Always upgrade with one clear reason | Location (Always) |
| 8. First pattern | Reads it | Counts, never a ratio or score | Notifications |
| 9. Living with it | Calm notification or the cloud lamp | Notifies only when today looks like their pattern, with a cap | Nothing |
| Later | Health reads, voice notes, provider sharing, maintenance inhaler | Asks in the moment | Health reads, microphone, provider consent |

### Open questions (on the board for Pandji and April)
1. What do we call the persona? A newly diagnosed adult, or a parent logging for a child?
2. Provider-led or direct-to-consumer first?
3. What does the provider get, and when does consent happen?
4. Maintenance-inhaler tracking: v1 or later?
5. When to ask for Always location: week 1, or at cloud-lamp setup?
6. Notification budget per week?
7. Action-plan language ("your plan") without the clinical zones?
8. What makes the Apple Watch mock-button test a success?

## How this connects to the app today

- Name: **felt air**. Logging is one "Used inhaler" action; I'm okay moments are automatic (app-open sampler now; background sampling needs the Always permission, which is open question 5).
- Data sources today are Apple Weather, OpenAQ and AirNow. Ambee is not integrated (contract pending), so onboarding copy shouldn't name it.
- The app reads nothing from Health; it writes Inhaler Usage.
- Insights shows "Still learning your pattern" with progress until 8 inhaler uses and 20 I'm okay moments.
