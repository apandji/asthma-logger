# iOS app — agent guide

Read the root [AGENTS.md](../AGENTS.md) first for the product, the principles, and the shared contracts. This file covers how the iOS app is built.

## Your knowledge may be out of date

The app targets **iOS 27** and the **Foundation Models** framework, both newer than most training data. Before using an Apple API you aren't sure about, check the current docs (developer.apple.com, or Xcode's documentation window via Remote Control). If you can't verify an API, say so in the PR. Don't invent signatures.

## Targets

- iOS **27.0+**, iPhone only. Test device: iPhone 15 Pro (supports Apple Intelligence).
- Swift 6 language mode, strict concurrency.
- SwiftUI, Observation (`@Observable`), SwiftData. No UIKit unless a framework forces it.
- No third-party packages without asking (root AGENTS.md → "Ask before").

## Layout

```
ios/
├── project.yml          XcodeGen spec — the source of truth for the Xcode project
├── AsthmaCore/          Swift package, Foundation only. Builds and tests on Linux.
│   ├── Sources/AsthmaCore/
│   │   ├── Frames/      FeatureFrame, bins, binSpecVersion
│   │   ├── Lift/        lift table, gate, smoothed log-LR scoring
│   │   ├── Narrator/    template narrator, prompt builder, output validation
│   │   └── Places/      visit clustering → home / work / frequent (pure math)
│   └── Tests/AsthmaCoreTests/   includes golden tests against ../../fixtures
└── AsthmaLog/           the app: SwiftUI + Apple frameworks
    ├── App/             entry point, tab bar (Journal, Insights)
    ├── Journal/
    ├── Insights/
    ├── Providers/       WeatherKit, OpenAQ, AirNow (Ambee later) behind one protocol
    ├── Location/        CoreLocation, visits, indoor/outdoor inference
    ├── Health/          HealthKit writes
    ├── Intelligence/    Foundation Models narrator + tag extraction, Speech, Vision
    ├── Persistence/     SwiftData models
    └── Theme/           every color, font and spacing token lives here
```

**The split matters.** Anything that can be plain Swift goes in `AsthmaCore` so cloud agents can test it. `AsthmaLog` stays a thin layer that calls Apple frameworks and draws views. If you find logic in a view, move it.

## Project file: XcodeGen

We commit `project.yml`, not `.xcodeproj` (it's gitignored). That way:

- Agents in the cloud can add files, targets, capabilities and Info.plist keys by editing YAML.
- No `project.pbxproj` merge conflicts.

Owner's one-time setup on the Mac: `brew install xcodegen`. After every pull: `cd ios && xcodegen`, then open `AsthmaLog.xcodeproj`.

## Build and test

| Where | Command | Notes |
|-------|---------|-------|
| Cloud or Mac | `cd ios/AsthmaCore && swift test` | Must pass before every PR |
| Mac (Remote Control) | `cd ios && xcodegen && xcodebuild -scheme AsthmaLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | Use whichever simulator is installed |
| Phone | Xcode → select iPhone → Run | Needs signing team + capabilities (below) |

Golden tests: `AsthmaCore` loads `fixtures/*.json` and must reproduce the web prototype's lift table for the shared v1 bins exactly.

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
- **Tags are a closed list** in `AsthmaCore`, e.g. exercise, cold air, smoke, pets, cleaning products, cold/flu, stress, strong scents. The model picks from the list and never makes up values. The user confirms tags as chips; only confirmed tags become bins.
- **Photos** (opt-in, per day, limited library access is fine): read time and location metadata, plus on-device Vision scene labels (outdoors, park, fire/smoke, animals, gym), to suggest tags and fill in where the user was. Nothing leaves the device.
- Keep the audio and transcript; the transcript is what the user can edit.

### Foundation Models (on-device language)
- Always check `SystemLanguageModel.default.availability` first. Not available → template narrator, silently.
- Two jobs only: **narrate** the gated lift table (port `web/src/lib/insights/summarize.ts` + `style.ts`), and **extract tags** from journal text. It never computes stats.
- Use guided generation for structured output, not JSON-in-text parsing.
- Validate output in `AsthmaCore`: every number in the headline must appear in the input table, and banned phrases ("will have an attack", percentages, causal claims) are rejected → template fallback.
- Keep prompts small: the gated rows and rules, not the diary.

## Persistence (SwiftData)

Mirror the target model in [docs/data-architecture.md §3](../docs/data-architecture.md): `Event` (kind: attack | baseline | feedback), `Observation`, `Alert`, `Place`, `JournalEntry` (audio, transcript, confirmed tags), plus a derived `FeatureFrame` cache that can always be rebuilt. Add a JSON export in a debug menu so the data can be checked and turned into fixtures.

## UI

- Two tabs: **Journal** and **Insights**. Logging a puff is one tap from Journal and should work offline.
- Dark, stock iOS for now: `.preferredColorScheme(.dark)`, SF Symbols, system materials, Dynamic Type.
- **All styling goes through `Theme/`.** No hard-coded colors or fonts in views. The risograph pass later should only touch `Theme/` and a few views.
- Copy follows the "Say / Do not say" table in [docs/predictive-engine.md §2](../docs/predictive-engine.md).

## Apple-side setup checklist (owner, in Xcode / developer portal)

Agents: when a change needs one of these, call it out in the PR.

- [ ] Signing team selected for the AsthmaLog target
- [ ] Capabilities: WeatherKit, HealthKit, Background Modes (location updates), as needed
- [ ] WeatherKit enabled for the App ID in the developer portal
- [ ] Info.plist usage strings: location (when in use / always), HealthKit update, microphone, speech recognition, photos
- [ ] Apple Intelligence turned on on the test phone
- [ ] App Store Connect record + TestFlight group
