# Asthma Log — iOS

First time running it? Follow these steps on your Mac. The guide assumes you're new to Xcode.

## 1. One-time setup

1. Install **Xcode** (the version that supports iOS 27) from the Mac App Store and open it once.
2. Sign in: Xcode → Settings → Accounts → **+** → Apple ID (the one in your Apple Developer account).
3. Install XcodeGen (it builds the Xcode project from `project.yml`):
   ```sh
   brew install xcodegen
   ```
   No Homebrew? Get it first from https://brew.sh.
4. Create your personal config:
   ```sh
   cd ios/Config
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```
   Open `Secrets.xcconfig` and fill in:
   - `DEVELOPMENT_TEAM`: Xcode → Settings → Accounts → select your team → the 10-character Team ID.
   - `BUNDLE_ID_PREFIX`: something you own, e.g. `com.yourname`.
   - `OPENAQ_API_KEY` / `AIRNOW_API_KEY`: optional free keys (links in the file). Without them you get weather only.

## 2. Turn on WeatherKit for the app (developer portal)

WeatherKit is the one capability Xcode can't switch on by itself.

1. https://developer.apple.com/account → Certificates, IDs & Profiles → **Identifiers**.
2. After your first build (step 3) Xcode will have created an App ID `<your prefix>.asthmalog`. Open it.
3. Tick **WeatherKit** under both *Capabilities* and *App Services* → Save.
4. It can take ~30 minutes before weather calls succeed.

## 3. Build and run on your iPhone

```sh
cd ios
xcodegen
open AsthmaLog.xcodeproj
```

1. Plug in the iPhone (or use the same Wi-Fi after pairing once). On the phone: Settings → Privacy & Security → **Developer Mode** → on.
2. In Xcode's toolbar, choose the **AsthmaLog** scheme and your iPhone as the destination.
3. Press **Run** (⌘R). The first time, the phone may ask you to trust the developer: Settings → General → VPN & Device Management.
4. For the on-device model: Settings → Apple Intelligence & Siri → on.

**Re-run `xcodegen` after every pull.** It regenerates the project when files are added.

## 4. Try it

- **Journal** → *Log a puff*. Allow location (and motion, Health). In a few seconds the log shows temperature, air quality and an indoors/outdoors guess. Tap a log to see each number's source and distance, or to correct indoors/outdoors.
- **Insights** → turn on *Settings → Show demo data in Insights* to see a pattern and look-ahead before you have real logs.
- **Settings** → move the *Insight voice* slider between Clinical and Poetic, then go back to Insights.

## If the build fails

Copy the first red error from Xcode's Issue navigator (⌘5) into a Claude session. Some Apple APIs here are new and were written without an Apple SDK; `AGENTS.md → Status` lists the likeliest suspects. You can also run `claude remote-control` in this repo on the Mac and let Claude build and fix it directly.

## Tests

```sh
ios/scripts/test-core.sh
```

Runs the shared logic tests (lift table, bands, scoring, narration checks), including the comparison against the web prototype.
