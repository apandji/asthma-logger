# Gallery

Drafts, mockups and screenshots of **felt air**, kept for documentation. One row per image.

The repo is **public**. Anything personal or third-party lives in `private/`, which is in `.gitignore` and exists only on the owner's Mac. This index lists those files by name so we know they exist, but they are never committed.

| Folder | Committed? | What goes here |
|--------|-----------|----------------|
| `mockups/` | yes | Renders of the HTML design mockups in `docs/design/` |
| `simulator/` | yes | Screenshots of the current build in the iOS Simulator, demo data only |
| `private/device/` | **no** (local only) | Screenshots from the owner's iPhone. They contain real location. |
| `private/drafts/` | **no** (local only) | The owner's unreleased Figma design drafts |
| `private/inspiration/` | **no** (local only) | Third-party reference images |
| `tools/` | yes | `snap-html.swift`, the script that renders the mockups |

## How to regenerate

### Mockups (HTML → PNG)

Quick Look (`qlmanage -t`) doesn't run JavaScript, so most of each mockup came out blank. Use the WKWebView script instead. Strip the Google Fonts links first so nothing is fetched from the network (the render then uses system fallback fonts), and make sure the file declares UTF-8:

```sh
SP=$TMPDIR/gallery && mkdir -p $SP
grep -v 'fonts.googleapis.com\|fonts.gstatic.com' docs/design/visual-style-mockups.html > $SP/vsm.html
{ echo '<meta charset="utf-8">'; grep -v 'fonts.googleapis.com\|fonts.gstatic.com' docs/design/riso-sketch.html; } > $SP/riso.html

# args: input.html output.png width-in-points light|dark   (output is 2x)
swift docs/gallery/tools/snap-html.swift $SP/vsm.html  $SP/vsm.png 1440 light
swift docs/gallery/tools/snap-html.swift $SP/riso.html $SP/riso.png 430 light
sips -s format jpeg -s formatOptions 80 $SP/riso.png --out docs/gallery/mockups/riso-sketch.jpg   # ~0.9 MB instead of ~3 MB

# visual-style-mockups only fills the left ~760 pt at 1440 wide; crop the empty right side
sips -c 4232 1540 --cropOffset 0 0 $SP/vsm.png --out docs/gallery/mockups/visual-style-mockups.png
```

### Simulator (demo data)

```sh
U=FDCFAE85-C1E8-4452-AEAB-298C0F1C3760   # "iPhone Air", iOS 27 (not a Watch simulator)
cd ios && xcodebuild -scheme AsthmaLog -destination "id=$U" -configuration Debug \
  -derivedDataPath $TMPDIR/dd-docs build
xcrun simctl install $U $TMPDIR/dd-docs/Build/Products/Debug-iphonesimulator/AsthmaLog.app
xcrun simctl spawn $U defaults write com.pandjico.asthmalog useDemoData -bool YES
xcrun simctl privacy $U grant location com.pandjico.asthmalog   # did not stop the prompt; tap "Allow While Using App" once

xcrun simctl ui $U appearance light      # or dark
xcrun simctl terminate $U com.pandjico.asthmalog; xcrun simctl launch $U com.pandjico.asthmalog
sleep 10                                 # first frames can be blank; retake if so
xcrun simctl io $U screenshot docs/gallery/simulator/2026-10-01-journal-demo-light.png
# tap the Insights tab (right-hand tab), then:
xcrun simctl io $U screenshot docs/gallery/simulator/2026-10-01-insights-demo-light.png

xcrun simctl spawn $U defaults write com.pandjico.asthmalog useDemoData -bool NO   # when done
```

`useDemoData` only feeds **Insights**. The Journal shows its empty state even with demo data on.

## mockups/

| File | What it shows | Date | Source | Light / dark |
|------|---------------|------|--------|--------------|
| `visual-style-mockups.png` | Journal (week strip + day log) and Recap (highlight sentence, inhaler vs usual bars, "Today" card) as phone frames. Demo numbers. | 2026-10-01 | Render of `docs/design/visual-style-mockups.html` (WKWebView, 2x, system fonts) | Both, side by side |
| `textile-mockups.jpg` | Textile direction: onboarding, Journal, logging, moment, Recap, history, look-ahead (light) and Journal + Recap on knit (dark). Demo data. | 2026-10-03 | Render of `docs/design/textile-mockups.html` (WKWebView, 1240 pt wide, 2x, JPEG 82) | Light and dark |
| `riso-sketch.jpg` | Riso sketch: "Today" clock-face of puffs and okay moments, moment detail with condition changes and tag chips, "Earlier" grid of past days, Settings sheet with insight-voice slider. Made-up demo diary. | 2026-10-01 | Render of `docs/design/riso-sketch.html` (WKWebView, 430 pt wide, 2x, fallback fonts instead of Google Fonts) | Light ("System" preview) |
| `riso-sketch-browser-partial.jpg` | Partial capture of the riso sketch from an earlier session (cropped strip). | 2026-10-01 | Built-in browser screenshot of `docs/design/riso-sketch.html` | Light |

## simulator/

All on the "iPhone Air" simulator (iOS 27), current build of branch `claude/visual-style`. No personal data.

| File | What it shows | Date | Source | Light / dark |
|------|---------------|------|--------|--------------|
| `2026-10-01-journal-demo-light.png` | Journal empty state ("No logs yet"), Used inhaler button, Journal / Insights tab bar. Demo data on, but it only affects Insights. | 2026-10-01 | `simctl io screenshot` | Light |
| `2026-10-01-journal-demo-dark.png` | Same as above. | 2026-10-01 | `simctl io screenshot` | Dark |
| `2026-10-01-insights-demo-light.png` | Insights with demo data: "Demo data" chip, plain-voice pattern headline (8 of 10 inhaler times ozone was high, 0 of 24 usual), caveat, Template tag, empty Looking ahead card, top of the Evidence table. | 2026-10-01 | `simctl io screenshot` | Light |
| `2026-10-01-insights-demo-dark.png` | Same as above. | 2026-10-01 | `simctl io screenshot` | Dark |
| `2026-10-01-journal-empty-light.png` | Journal empty state, no demo data. Earlier session. | 2026-10-01 | iOS Simulator tool screenshot | Light |
| `2026-10-01-journal-empty-dark.png` | Journal empty state, no demo data. Earlier session. | 2026-10-01 | iOS Simulator tool screenshot | Dark |
| `2026-10-01-insights-empty-dark-location-prompt.png` | Insights with no data, with the system location permission prompt on top. Earlier session. | 2026-10-01 | iOS Simulator tool screenshot | Dark |

## private/ (local only, gitignored)

| File | What it shows | Date | Source | Light / dark |
|------|---------------|------|--------|--------------|
| `device/2026-10-01-log-conditions-weatherkit-airnow-errors.png` | Log detail with an Apple Weather auth error and the retired AirNow endpoint error | 2026-10-01 | Owner's iPhone | — |
| `device/2026-10-01-log-conditions-all-sources.webp` | Log detail after the fixes: WeatherKit, OpenAQ and AirNow all returning values | 2026-10-01 | Owner's iPhone | — |
| `device/2026-10-01-insights-demo-old-wording.webp` | Insights with demo data and the old "attacks ~99x" headline | 2026-10-01 | Owner's iPhone | — |
| `device/2026-10-01-ios27-settings-no-apple-intelligence.webp` | iOS 27 Settings showing "Siri" and no Apple Intelligence row | 2026-10-01 | Owner's iPhone | — |
| `drafts/felt-air-your-moments.png` | "felt air" wordmark, greeting, "your moments" day-dot grid | 2026-10-01 | Owner's Figma drafts | — |
| `drafts/felt-wordmark-moire.webp` | "felt" wordmark over moiré line fields, misregistered yellow | 2026-10-01 | Owner's Figma drafts | — |
| `drafts/onboarding-and-recap.png` | Onboarding with overlapping dots; Recap with a highlighted sentence | 2026-10-01 | Owner's Figma drafts | — |
| `inspiration/web-tiles-duotone-editorial.webp` | Third-party websites: duotone tile grids, editorial serif | 2026-10-01 | Third-party web | — |
| `inspiration/halftone-swatches-and-dot-poster.webp` | Halftone tint scale and a blurred dot poster | 2026-10-01 | Third-party | — |
