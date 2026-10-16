# Asthma Log — iOS

First time running it? Follow these steps on your Mac. The guide assumes you're new to Xcode, and works for anyone on the team setting it up on their own iPhone.

Each person builds under **their own paid Apple Developer membership** (we don't share a team: Individual memberships can't, and we have no company for an Organization account). Setting this up with a Claude agent? Hand it [docs/teammate-setup.md](../docs/teammate-setup.md).

## 0. Get the code

1. Install **Git** if you don't have it: open Terminal and run `git --version`. If macOS offers to install the Command Line Tools, say yes.
2. Clone the repo and switch to the branch you're working on:
   ```sh
   git clone https://github.com/apandji/asthma-logger.git
   cd asthma-logger
   git checkout main
   ```
3. Later, to get the newest changes: `git pull`, then re-run `xcodegen` (step 3).

To push your own changes, ask the owner to add you as a collaborator on GitHub (repo → Settings → Collaborators).

## 1. One-time setup

1. Install **Xcode 27** (it supports iOS 27) from the Mac App Store and open it once. When it asks which platforms to install, include **iOS** (and **watchOS** if you'll try the watch app). You can add them later in Xcode → Settings → Components.
2. Sign in: Xcode → Settings → Accounts → **+** → Apple ID.
3. Have your own **paid Apple Developer membership** (https://developer.apple.com/programs/enroll). WeatherKit and HealthKit need one, so a free Apple ID won't build the app. Check it's active under https://developer.apple.com/account → Membership details.
4. Install XcodeGen (it builds the Xcode project from `project.yml`):
   ```sh
   brew install xcodegen
   ```
   No Homebrew? Get it first from https://brew.sh.
5. Create your personal config:
   ```sh
   cd ios/Config
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```
   Open `Secrets.xcconfig` and fill in:
   - `DEVELOPMENT_TEAM`: your 10-character Team ID (developer.apple.com/account → Membership details).
   - `BUNDLE_ID_PREFIX`: something unique to you, e.g. `com.yourname`. Not anyone else's prefix: each person's felt air is a separate app with its own Journal.
   - `OPENAQ_API_KEY` / `AIRNOW_API_KEY`: optional free keys (links in the file). Without them you get weather only. Never put keys in the repo or a GitHub comment.

   `Secrets.xcconfig` is gitignored, so it stays on your Mac.

## 2. Turn on WeatherKit for the app (developer portal)

WeatherKit is the one capability Xcode can't switch on by itself. Everyone does this once, on their own account. (HealthKit is turned on automatically by the first build.)

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

1. Plug in the iPhone with a cable (after the first time, the same Wi-Fi works). Unlock it and tap **Trust** if asked. The iPhone needs iOS 27.
2. Turn on Developer Mode on the phone: Settings → Privacy & Security → **Developer Mode** → on, and restart when asked. (The option only appears after the phone has been connected to Xcode once.)
3. In Xcode's toolbar, choose the **AsthmaLog** scheme and your iPhone as the destination.
4. Press **Run** (⌘R). If Xcode shows a signing error, open the AsthmaLog target → *Signing & Capabilities* and check that the team is the one from `Secrets.xcconfig`. Don't change settings there permanently: they're regenerated from `project.yml`. The first time, the phone may ask you to trust the developer: Settings → General → VPN & Device Management.
5. For the on-device model: Settings → Apple Intelligence & Siri → on.

**Re-run `xcodegen` after every pull.** It regenerates the project when files are added.

Apple Watch (optional): pair the watch with the iPhone, turn on Developer Mode on the watch too (Settings → Privacy & Security), and the watch app installs along with the iPhone app.

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
