# Set up felt air on your own Apple Developer account

A handoff for a teammate's Claude agent. Read it top to bottom, then read the root `AGENTS.md` and `ios/AGENTS.md` before changing code.

## The situation

- Each designer on felt air has their **own paid Apple Developer membership (Individual)**. There is no shared team: Individual memberships can't share signing, and we have no company to make an Organization account.
- So each of you builds the app under **your own Team ID and your own bundle ID**. The code is shared through GitHub (`apandji/asthma-logger`). Signing is not.
- Your felt air is a separate app from the owner's. If the owner installed a build on this iPhone from their Mac, both icons can sit side by side (different bundle IDs). Each keeps its own Journal.
- Nothing about signing is committed. Personal values live in `ios/Config/Secrets.xcconfig`, which is gitignored. **Do not edit `project.yml` signing settings or commit a Team ID.**

## What the app needs from Apple

From `ios/project.yml`:

| Need | Where it comes from | Portal step? |
|---|---|---|
| **WeatherKit** | entitlement `com.apple.developer.weatherkit` | **Yes, by hand** (below). Xcode can't turn it on. |
| **HealthKit** (writes Inhaler Usage) | entitlement `com.apple.developer.healthkit` | No. Automatic signing adds it to the App ID. |
| Location, Motion, Microphone, Speech, Bluetooth | usage strings in Info.plist | No. Just permission prompts on the phone. |
| Felt button in the background | `UIBackgroundModes: bluetooth-central` | No. |
| Apple Watch app | second target, `<prefix>.asthmalog.watchkitapp` | No. Automatic signing creates it. |

App IDs that get created: `<prefix>.asthmalog` (iPhone) and `<prefix>.asthmalog.watchkitapp` (watch).

## Who does what

The agent can run commands and edit files. **The person has to do every Apple account step**: signing in, clicking in the developer portal, tapping Trust on the phone. Don't try to automate those, and never handle the Apple ID password. Give exact click paths and wait for a "done".

## Steps

### 1. Check the membership is active (person)

https://developer.apple.com/account → **Membership details**. Status should be active. New enrollments can take a day or two. Note the **Team ID** (10 characters).

### 2. Tools (agent checks, person installs if missing)

```bash
xcodebuild -version        # needs Xcode 27 or newer
xcodegen --version         # brew install xcodegen
git --version
```

Xcode → Settings → **Components** must have the **iOS 27** platform (and watchOS for the watch). In Xcode → Settings → **Accounts**, the person adds their Apple ID. Their own team (their name, "Individual") should appear.

### 3. Code

```bash
git clone https://github.com/apandji/asthma-logger.git
cd asthma-logger
git checkout main && git pull
```

To push, the person must have accepted the GitHub collaborator invite (https://github.com/apandji/asthma-logger/invitations).

### 4. Personal config

```bash
cd ios/Config
cp Secrets.example.xcconfig Secrets.xcconfig
```

Fill in:

- `DEVELOPMENT_TEAM` = **their** Team ID from step 1.
- `BUNDLE_ID_PREFIX` = something unique to them, e.g. `com.<theirname>`. It must not be `com.pandjico` (the owner's). If Xcode later says the bundle ID is taken, pick another prefix.
- `OPENAQ_API_KEY` / `AIRNOW_API_KEY`: optional. Without them the app has weather but no air quality. Free keys: https://explore.openaq.org/register and https://docs.airnowapi.org/account/request/. Never paste keys into a commit, PR, issue or chat log that gets shared.

### 5. First build, which creates the App IDs

Plug the iPhone in with a data cable, unlock it, tap **Trust**, and turn on **Settings → Privacy & Security → Developer Mode** (it restarts). Then:

```bash
cd ios
xcodegen
xcrun devicectl list devices          # the phone should show as "connected" with its name
xcodebuild -project AsthmaLog.xcodeproj -scheme AsthmaLog -configuration Debug \
  -destination 'id=<PHONE_UDID>' -derivedDataPath ~/feltair-build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

Or open `ios/AsthmaLog.xcodeproj` in Xcode, pick the **AsthmaLog** scheme and the iPhone, and press Run.

This registers the phone, creates both App IDs with HealthKit on, and makes the profiles. If the build fails **only** on WeatherKit, do step 6 and build again.

### 6. Turn on WeatherKit (person, once)

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles** → **Identifiers**.
2. Open `<prefix>.asthmalog`.
3. Tick **WeatherKit** on the **Capabilities** tab **and** on the **App Services** tab. Save.
4. Build again. Weather calls can fail for up to about **30 minutes** after this. That's Apple's side, not a bug.

### 7. Install and open

```bash
xcrun devicectl device install app --device <PHONE_UDID> \
  ~/feltair-build/Build/Products/Debug-iphoneos/AsthmaLog.app
xcrun devicectl device process launch --device <PHONE_UDID> <prefix>.asthmalog
```

(Pressing Run in Xcode does both.) If the phone says **Untrusted Developer**: Settings → General → VPN & Device Management → the developer profile → Trust.

On first launch, allow Location (it stamps weather and air on each log). Health, Motion and Bluetooth are asked when those features are first used.

### 8. Match the owner's look

Most new screens sit behind **design crit switches** (Settings → Design crit, Debug builds only). A fresh install starts on the defaults, which may not be what the owner is reviewing (for example, Home: Journal vs Now, Paper: Black vs Linen). Set them to match the owner's phone before comparing.

## Day-to-day

```bash
git checkout main && git pull
cd ios && xcodegen            # after EVERY pull or branch switch
git checkout -b april/<feature>
# work, commit
git push -u origin april/<feature>
```

Then open a PR into `main`. Keep branches small: another agent is actively editing the Now and Journal views (`NowHomeView.swift`, `JournalView.swift`), so big overlapping edits there will conflict.

## Never commit

- `ios/Config/Secrets.xcconfig` (Team ID, prefix, keys)
- `ios/AsthmaLog.xcodeproj`, `ios/AsthmaLog/Info.plist`, `ios/AsthmaLog/AsthmaLog.entitlements` (all generated by XcodeGen, and gitignored)
- Screenshots from a real phone (they show real locations), private photos, or names of people outside the team. **The repo is public.** Private images go in `docs/gallery/private/` (gitignored).

## Known gotchas

| Symptom | Cause / fix |
|---|---|
| `Cannot find 'X' in scope` after a pull | The project is stale. Run `xcodegen` in `ios/`. |
| Phone missing from Xcode, or listed as "Unknown" / offline | Pairing didn't finish. Use a data cable straight into the Mac, unlock, Trust, and wait for "Preparing" in Window → Devices and Simulators. If stuck: on the phone, Settings → General → Transfer or Reset → Reset → **Reset Location & Privacy**, then replug. |
| `Failed to register bundle identifier` | The prefix is taken. Choose another `BUNDLE_ID_PREFIX`. |
| Signing error mentioning WeatherKit | Step 6 isn't done yet. |
| Weather empty right after step 6 | Wait about 30 minutes. |
| Air quality missing | No OpenAQ / AirNow keys. That's expected. |
| App looks different from the owner's | The crit switches differ (step 8). |
| `ios/scripts/fresh-install.sh` | **Don't run it as-is.** It hardcodes the owner's bundle ID (`com.pandjico.asthmalog`) for the uninstall and launch steps. Pass the right one, or fix the script to read `PRODUCT_BUNDLE_IDENTIFIER` from the build settings (a good small first PR). |

## When it works

Logging a moment (pull up on +) shows temperature within a few seconds. Air quality shows too if keys are set. Settings → felt button can pair a felt button, though each button connects to one phone at a time, so it's easiest if each person has their own.
