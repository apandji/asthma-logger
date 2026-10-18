#!/usr/bin/env bash
# Deletes felt air from the connected iPhone and installs a fresh Debug build, so onboarding and every
# permission sheet (location, Bluetooth, motion, Health) appear again. ERASES the Journal on the phone.
# For the stage: ios/scripts/fresh-install.sh            (empty Journal, onboarding first)
#                ios/scripts/fresh-install.sh --demo     (the demo week added back)
#                ios/scripts/fresh-install.sh --data hotHazy   (a made-up person: stillLearning, allergenLed,
#                  airQualityLed, weatherSensitive, hotHazy, effortLed, mixed, nothingStandsOut; onboarding skipped)
# An optional device UDID can follow.
set -euo pipefail
cd "$(dirname "$0")/.."
BUNDLE=com.pandjico.asthmalog
DEMO=""
ONBOARD="-showOnboarding"
if [ "${1:-}" = "--demo" ]; then DEMO="-demoWeek"; shift; fi
if [ "${1:-}" = "--data" ]; then DEMO="-dataSet ${2:?name a preset}"; ONBOARD="-skipOnboarding"; shift 2; fi
DEVICE="${1:-$(xcrun devicectl list devices 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')}"
[ -n "$DEVICE" ] || { echo "No connected iPhone. Unlock it and plug it in (or keep it on the same Wi-Fi)."; exit 1; }

xcodegen generate -q
xcodebuild -project AsthmaLog.xcodeproj -scheme AsthmaLog -configuration Debug \
  -destination "platform=iOS,id=$DEVICE" -allowProvisioningUpdates build -quiet
APP="$(xcodebuild -project AsthmaLog.xcodeproj -scheme AsthmaLog -configuration Debug \
  -destination "platform=iOS,id=$DEVICE" -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/ {print $3}')/AsthmaLog.app"

echo "Removing felt air from the phone (permissions and Journal reset)…"
xcrun devicectl device uninstall app --device "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE" -- $DEMO $ONBOARD -resetTips >/dev/null \
  || echo "Installed. Unlock the phone and open felt air."
echo "Fresh install done: onboarding and every permission sheet will show again."
