# iOS app — agent guide

Read the root [AGENTS.md](../AGENTS.md) first for the product, the principles, and the shared contracts. This file covers how the iOS app is built.

## Your knowledge may be out of date

The app targets **iOS 27** and the **Foundation Models** framework, both newer than most training data. Before using an Apple API you aren't sure about, check the current docs (developer.apple.com, or Xcode's documentation window via Remote Control). If you can't verify an API, say so in the PR. Don't invent signatures.

## Targets

- iOS **27.0+** iPhone app, plus a **watchOS 27** companion for logging (`AsthmaLogWatch`). Test device: iPhone 15 Pro (supports Apple Intelligence).
- Swift 6 language mode, strict concurrency.
- SwiftUI, Observation (`@Observable`), SwiftData. No UIKit unless a framework forces it.
- No third-party packages without asking (root AGENTS.md → "Ask before").

## Layout

```
ios/
├── README.md            first-run guide for the owner (Xcode, signing, keys)
├── project.yml          XcodeGen spec: the source of truth for the Xcode project
├── Config/              Base.xcconfig (committed), Secrets.xcconfig (gitignored: team, bundle prefix, API keys)
├── scripts/test-core.sh runs AsthmaCore tests (local Swift, or Docker in cloud sessions)
├── AsthmaCore/          Swift package, Foundation only. Builds and tests on Linux.
│   ├── Sources/AsthmaCore/
│   │   ├── Frames/      FeatureFrame, Banding (raw value → band), FrameBuilder, DemoData
│   │   ├── Conditions/  EnvObservation + provenance, honest copy, OpenAQ/AirNow decoding and station choice
│   │   ├── Lift/        bins, lift table, gate
│   │   ├── Forecast/    RateTable (smoothed log-LR), RiskBander, Outlook (windows, cold start)
│   │   ├── Narrator/    style bands, template, prompt builder, NarrationGuard (output checks)
│   │   ├── Journal/     MomentKind (rescue / standard / okay), DemoWeek, JournalTag (closed list), TagExtraction, VoiceNoteTags (keyword rules, model validation, TagReview)
│   │   └── Places/      visit clustering → home/work/frequent; indoor/outdoor guesser
│   └── Tests/AsthmaCoreTests/   golden tests against ../../fixtures + unit tests
├── Shared/              code compiled into both the app and the watch app (WatchLog)
├── AsthmaLogWatch/      watchOS app: Rescue / Standard buttons → WatchConnectivity → phone
└── AsthmaLog/           the app: SwiftUI + Apple frameworks
    ├── App/             entry point, tabs (Journal, Insights), Prefs keys, WatchBridge (receives watch logs)
    ├── Onboarding/      first-run screens (photos from gitignored ios/PrivateMedia/, woven fallback)
    ├── Journal/         JournalView (week strip, ambient field), EventDetailView, MomentTrendChart, LogService (log → locate → stamp)
    ├── Insights/        InsightsView, InsightsModel
    ├── Settings/        SettingsView (insight voice slider lives here), settings toolbar
    ├── Providers/       WeatherKit, OpenAQ, AirNow, ConditionsService (parallel, fail-open), attribution
    ├── Location/        CoreLocation (async liveUpdates, no delegate), CoreMotion
    ├── Health/          HealthKit writes
    ├── Intelligence/    Foundation Models: narration + tag suggestions
    ├── Persistence/     SwiftData LogEvent
    └── Theme/           every color, font and spacing token; Card, Chip
```

**The split matters.** Anything that can be plain Swift goes in `AsthmaCore` so cloud agents can test it. `AsthmaLog` stays a thin layer that calls Apple frameworks and draws views. If you find logic in a view, move it.

## Project file: XcodeGen

We commit `project.yml`, not `.xcodeproj`. The generated project, `Info.plist` and entitlements are gitignored. That way:

- Agents in the cloud can add files, capabilities and Info.plist keys by editing YAML.
- No `project.pbxproj` merge conflicts.

Usage strings, entitlements and the API-key plumbing (`$(OPENAQ_API_KEY)` → Info.plist → `Secrets`) all live in `project.yml`. Change them there, never in Xcode's UI, or `xcodegen` will wipe the change.

The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: app code is main-actor unless marked `nonisolated`. Types that must cross isolation (e.g. `@Generable` structs) are marked `nonisolated`. Keep `Decodable` API types in `AsthmaCore`.

Don't name an `AsthmaCore` type after an Apple module (`Observation`, `SwiftData`, `WeatherKit`…). Macros like `@Observable` and `@Model` expand to module-qualified names such as `Observation.Observable`, and a same-named type shadows the module in every file that imports `AsthmaCore`. That is why the outdoor-reading type is `EnvObservation`.

## Build and test

| Where | Command | Notes |
|-------|---------|-------|
| Cloud or Mac | `ios/scripts/test-core.sh` | Must pass before every PR |
| Cloud | `swiftc -parse` on changed app files | Syntax only; the app needs Apple SDKs to type-check |
| Mac (Remote Control) | `cd ios && xcodegen && xcodebuild -scheme AsthmaLog -destination 'generic/platform=iOS Simulator' build` | Real compile of the app |
| Phone | Xcode → pick the iPhone → Run | See README for signing and capabilities |

Golden tests: `AsthmaCore` loads `fixtures/*.json` and must reproduce the web prototype's lift table, template headline and bands exactly.

## Status

| Built | Not yet |
|-------|---------|
| Log a puff / usual moment, offline-first | |
| Precise fix, motion, indoor/outdoor guess + correction | Place learning (visits → home/work) — `Places.cluster` is ready in core |
| WeatherKit, OpenAQ, AirNow, fail-open with provenance | Pollen (Ambee) |
| HealthKit inhaler usage write + delete | Photos |
| Insights: lift, template + Foundation Models narration with output checks | Full visual style pass ([docs/design/visual-style.md](../docs/design/visual-style.md)) |
| Look-ahead: 72 h WeatherKit + AirNow categories, personal windows or cold-start hazards | Air-event warnings as notifications |
| Settings: voice slider, model toggle, Health, auto baseline moments, demo data | |
| Apple Watch logging (Rescue / Standard → phone) | Watch complications |
| Quick Record: after a moment, the Lock Screen asks what was going on (Live Activity in `AsthmaLogWidgets/`, buttons are App Intents in `QuickRecordActivity/` that run in the app, `Voice/QuickRecordLive.swift`); a standby card waits on the Lock Screen (started whenever the app is open, since iOS only *starts* Live Activities from the foreground) and a background press *updates* it with an alert; its mic logs a rescue and listens. Notification fallback when there's no card. Lock Screen / Control Center / Action button control "Rescue voice note" | Covering the gap when the card has lapsed (8-hour Live Activity limit, app not opened since): push-to-start needs a server |
| First-run onboarding; Journal week strip with woven tiles and ambient field | |

**On device** (iPhone 15 Pro, iOS 27, Xcode 27.0, 2026-10-01): builds clean with no warnings; logging a puff works and writes Inhaler Usage to Apple Health; Insights renders the template narration and the look-ahead (demo data); precise location (±13 m) stamps the log; WeatherKit, OpenAQ and AirNow all return outdoor conditions, with the Apple Weather attribution shown. Compile fix needed: `Observation` → `EnvObservation` (see "Project file" above). AirNow moved to its 2026 services (`observation/current/ziplatLong`, `forecast/current`) after the old `latLong` ones were retired. **Not yet confirmed:** Foundation Models narration (Apple Intelligence was not on), and Insights from real logs rather than demo data.

## Frameworks and how we use them

### Location (CoreLocation)
- Ask for **When In Use** first and **Always** only when the user turns on place learning. Request precise accuracy.
- Each log stamps lat/lon, `horizontalAccuracy`, and floor if present.
- **Places**: collect visits (`CLVisit` / CLMonitor), cluster them in `AsthmaCore/Places`, and suggest *home*, *work*, *frequent* for the user to confirm and name. The confirmed **home** place drives the Insights forecast. Trips update the rate table but never move the forecast.
- Coordinates stay on the device. Providers get the pin only when fetching conditions.

### Indoor / outdoor inference
No iOS API says "indoors", so this is a guess with a confidence level: `likelyIndoor | likelyOutdoor | unknown`.
- Signals: GPS accuracy and its drop-off, being at a known place mid-visit, motion activity (walking/cycling vs stationary), floor level, time of day.
- Show the guess on the log and let the user correct it in one tap. Corrections are labels; keep them.
- Never present the guess as fact.

### Conditions (Providers)
- One protocol, e.g. `ConditionsProvider`, returning **Observations** with full provenance (see root AGENTS.md → Honest numbers). Providers run in parallel and fail open.
- **WeatherKit**: current + hourly forecast (temp, humidity, dew point, wind, UV, pressure). Needs the WeatherKit capability and App ID service. **The Apple Weather attribution (mark + legal link) is required in the UI.**
- **OpenAQ**: nearest PM2.5 and ozone station with name + distance. Port the rules from `web/src/lib/openaq.ts`.
- **AirNow**: fallback observation + daily AQ forecast for the look-ahead.
- **Pollen**: none for now; the bin is `unknown`. Ambee later.
- Keys: `ios/Config/Secrets.xcconfig` (gitignored; `Secrets.example.xcconfig` is committed). For the TestFlight proof of concept, keys ship in the app; that's an accepted risk. Move them behind a proxy before any public release.

### HealthKit
- Write each puff as `HKQuantityType(.inhalerUsage)` (unit: count). Store the sample UUID on the log so edits and deletes stay in sync.
- No reads in the proof of concept.
- Needs the HealthKit capability plus `NSHealthUpdateUsageDescription`.

### Journaling: voice, photos, language
- **Voice note**: record → transcribe on device (Speech framework, on-device recognition only) → Foundation Models extracts tags with guided generation (`@Generable`).
- **Tags are a closed list** in `AsthmaCore`, e.g. exercise, cold air, smoke, pets, cleaning products, cold/flu, stress, strong scents. The model picks from the list and never makes up values. The user confirms tags as chips; only confirmed tags become bins. Wire the model as a `TagProposer` and run `VoiceNoteTagger.suggest`: it validates the answer, applies keyword rules and negation, and fails open. Keep a `TagReview` per note and stamp it with `FeatureFrame.apply(_:)`; a moment without a reviewed note is missing for tag bins, not "no" ([docs/on-device-insights.md](../docs/on-device-insights.md#voice-note-tags-ios)).
- **Photos** (opt-in, per day, limited library access is fine): read time and location metadata, plus on-device Vision scene labels (outdoors, park, fire/smoke, animals, gym), to suggest tags and fill in where the user was. Nothing leaves the device.
- Keep the audio and transcript; the transcript is what the user can edit.

### Foundation Models (on-device language)
- Always check `SystemLanguageModel.default.availability` first. Not available → template narrator, silently.
- Two jobs only: **narrate** the gated lift table (port `web/src/lib/insights/summarize.ts` + `style.ts`), and **extract tags** from journal text. It never computes stats.
- Use guided generation for structured output, not JSON-in-text parsing.
- Validate output in `AsthmaCore`: every number in the headline must appear in the input table, and banned phrases ("will have an attack", percentages, causal claims, the word "attack", ratios like "3×") are rejected → template fallback.
- Keep prompts small: the gated rows and rules, not the diary.

## Persistence (SwiftData)

Mirror the target model in [docs/data-architecture.md §3](../docs/data-architecture.md): `Event` (kind: attack | baseline | feedback), `Observation`, `Alert`, `Place`, `JournalEntry` (audio, transcript, confirmed tags), plus a derived `FeatureFrame` cache that can always be rebuilt. Add a JSON export in a debug menu so the data can be checked and turned into fixtures.

## UI

- **No tab bar.** The Journal is one surface; everything else is a gesture (as of Oct 16, 2026):
  - **Gesture models (Design crit › Gestures):** A · one axis (swipe the sky sideways for other moments, up for details, no pinch); **B · zoom through time (default)**: hold the gauge (four dots on the right) and slide to move through Month ⇄ Days (`DaysView`) ⇄ Moment ⇄ Details, a haptic tick per scale; a copy of the current moment's sky flies from the old scale's anchor to the new one, drawn on top so it never affects layout (`AnchorFrames`, `Flight`); plus sideways swipes on the sky. No pinch; C · quiet (timeline and tap only). All keep hold-to-read, tap for details, the timeline and the +. On the sky, holding still first means read; moving straight away means swipe.
  - **One sky and a timeline:** the moment you're on is a contained sky on a black page (fades to black at the top and edges), with its map muted inside it. Below it, a history track (ticks every 6 hours, days labelled, moments as orange / blue dots) scrolls under a fixed centre marker: drag it to move through time, it snaps to the nearest moment, tap a dot to jump. Only one sky is drawn, so it stays smooth. The header follows the moment. A newly logged moment (+, felt button, watch) slides into view. Older styles (floating circle, card) are crit options.
  - **+ (bottom right):** press and pull up. A short pull logs **Rescue**, all the way up logs **Standard**, letting go low cancels. Haptics per zone, Undo toast.
  - **Insights:** a ring button by the + fills while learning; when there's a pattern a speech bubble offers it. Opens as a sheet (swipe down to close).
  - **Tap or pinch the sky open:** one continuous zoom on the same screen. The color field fades, the map grows out of the sky into a sharp hero (shared `matchedGeometryEffect`), and the details rise beneath it (weather, air, the hours around it, voice note, sources). Pull down, pinch closed or the chevron to go back. **Pinch in:** the moments shrink into dots on a month calendar with the full list (`MomentsOverview`, shared `matchedGeometryEffect` ids).
  - **Turn sideways:** the Data view (`AirChartsView(wide:)`, hourly temperature / humidity / PM2.5 with inhaler moments marked).
  - **Touch and hold the sky:** paging pauses; move your finger to name each color (name, reading set large with its unit, amount bars and level, one plain line). A steady haptic pulse quickens and strengthens as the reading nears high. The sky is the legend; there's no separate key.
  - **Glass controls, bottom edge:** calendar (Month) and Settings bottom-left, the + bottom-right, over every scale; the header runs the full width. (The old ••• menu is gone.) First-use hints are TipKit tips, one at a time, as a short tutorial: everything the current tip isn't about dims (`SpotlightDim`, targets marked with `.spotlightTarget`). Settings › Design crit › Replay tutorial brings it back on the next launch.
- Logging should always work offline and never wait on the network.
- **Color field = a layered sky.** Base: temperature is the hue (blue cold → green mild → gold warm → red hot) under the light of the hour (indigo night, rose dawn and dusk); humidity is the softness (dry crisp, humid pale). On top, one color per pollutant and pollen type, faint when low and fuller when high: PM2.5 slate, PM10 sand, NO₂ rust, ozone icy cyan, tree green, grass gold, weed violet (`AirLayers`). Still, no idle motion. `WeatherColor` holds the palette; `FieldLegend` explains it with this moment's levels.
- **Vocabulary:** use the names in [docs/design/felt-air-language.md](../docs/design/felt-air-language.md) (moment, sky, base, layers, swatch, scales, gauge, anchor, timeline, playhead, hold to read, pull to log) in code, docs and UI.
- **Copy:** short, concrete, plain. No flourishes ("Breathe…"), no paired abstractions, no semicolons in UI text. Say what happens ("This press only pairs the button, it isn't logged").
- **Look: Apple chrome, felt air character.** System pieces for chrome (TipKit tips, a ••• menu, glass buttons); the character lives in the color field and the moment (map in a feathered circle). Avoid decorative effects that don't carry data.
- **Design crit switches** (Settings › Design crit, Debug only; `App/Crit.swift`): home (Journal / **Now**), gestures, header, sky reading (**blob** under the finger / **strata**), sky surface (plain / riso grain / grain that answers touch), color field, color strength (steps / smooth within level), demo pollen, moment style, card label, Good / OK / Not good style, Insights entry and state, + pull order. Add new open design questions here as switches instead of forking views, and keep the default as the current proposal.
- **Reading the sky (as of Oct 16, 2026).** The map under the sky is **pinned**: it never moves with the finger. The sky carries a **riso grain** (halftone dots on a grid turned 12°, each a little different), still under the whole page and awake on the sky: dots swell under touch and a wave ripples through them when a sky appears (a ring in blob mode, a top-to-bottom sweep in strata). **Strata** (default): the sky is a core sample, weather on top, then one full-width horizontal band per layer, **worst on top**; only the finger's height matters. Zero pollen is still a band ("0 · Good") so every sky has the same stack. The highlight, the swelling dots and the label's bars are tinted by **level** (good green, OK yellow, not good red, the same colors as the Now home's verdict line), never by the layer's own ink, so green never means "tree pollen".

## Crit feedback, Oct 16, 2026 (open)

Raised in the design crit. Not solved yet; next work on the sky should start here.

1. **Reading the sky still feels spatial.** Even with the map pinned and strata bands, pressing on the sky to get blobs and layers reads as "the air at this x/y on the map". What we have is one regional reading per layer, for the air *above* the place, not at a spot in it. Ideas to try, as crit switches: the map as a small disc or a "where" chip instead of a full-bleed layer under the sky; the layers as a stack beside or above the map rather than over it (a column, a core sample, a vertical scale on the edge), so touch picks a *layer*, not a *place*; the response field-wide with no highlight at the finger at all; or the readings as a list that the sky merely colors. Whatever wins, the rule is: nothing in the gesture or the highlight may imply a position on the map.
2. **Bring in denser data.** The sky says little per pixel. Where can the line graphs (`AirChartsView`, `HourlyHistory`: hourly temperature, humidity, PM2.5 with moments marked), the amount bars and raw readings live on the main surface without breaking the sky? Ideas: the timeline track carries the hourly lines faintly (it already carries the forecast as a color strip); the strata bands show a sparkline of that layer's day; the details view opens to the chart rather than the table; the Data view (sideways) gets a way in from the Now home.

Record new crit feedback here, dated, and move items out when they're resolved (say where).
- **Demo pollen** (`Providers/DemoPollen.swift`) is display-only: realistic Midwest seasons, labelled "Demo" wherever shown, never in frames, Insights or patterns.
- **Air and pollen read Good / OK / Not good** (`Tier`), each on its own scale (EPA for pollutants, Ambee for pollen). Bars show the amount: one bar a little, three a lot. Temperature and humidity get plain words (Mild, Humid), never a judgement. The AQI is an index, so it's a summary line, not a row. Raw values and units are shown, never compared.
- Debug: Settings › Reset onboarding and button. `ios/scripts/fresh-install.sh` reinstalls on the phone so every permission sheet shows again (erases the Journal; adds the demo week back).
- **The design system is [docs/design/design-system.md](../docs/design/design-system.md).** Tokens, type, the three springs, the sky, the header, the timeline, the controls, the words. Read it before building any screen; it supersedes visual-style.md where they differ.
- **All styling goes through `Theme/`.** No hard-coded colors or fonts in views. Colors are `Color(light:dark:)` tokens; riso inks are for data marks only.
- **Demo moments** (Settings → Demo moments) are marked by `LogEvent.isDemoMoment`, never by `note`. They show in the Journal but never feed Insights, baseline sampling, or a trend line next to real readings.
- Copy follows the "Say / Do not say" table in [docs/predictive-engine.md §2](../docs/predictive-engine.md).

## Apple-side setup checklist (owner, in Xcode / developer portal)

For a teammate building under their own membership (own Team ID and bundle prefix, WeatherKit by hand), follow [docs/teammate-setup.md](../docs/teammate-setup.md): it is the source of truth for setup. This list is what the owner checks when a change touches signing.

Agents: when a change needs one of these, call it out in the PR.

- [ ] Signing team selected for the AsthmaLog target
- [ ] Capabilities: WeatherKit, HealthKit, Background Modes (location updates), as needed
- [ ] WeatherKit enabled for the App ID in the developer portal
- [ ] Info.plist usage strings: location (when in use / always), HealthKit update, microphone, speech recognition, photos
- [ ] Apple Intelligence turned on on the test phone
- [ ] App Store Connect record + TestFlight group
