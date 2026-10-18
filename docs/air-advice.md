# Air warnings and advice (a provocation)

From the FigJam board "On Copy" (Oct 17, 2026). Copy lives in `ios/AsthmaCore/Sources/AsthmaCore/Conditions/AirAdvice.swift`
and is tested (`AirAdviceTests`): no causes, no odds, no "attack", no semicolons.

## The advice is a provocation

Owner decision, Oct 17: **include the advice** ("close your windows", "an N95 mask filters fine particles"), and use it as a
provocation when we bring felt air to providers: we want to hear what they would actually tell a patient, and what they'd
never want an app to say. It is not cited guidance and isn't signed off by a clinician. Every surface that shows it says
"A suggestion, not medical advice. If a flare is severe, get medical help now."

Before any testing with users: replace each line with a cited source or a provider's wording, or take it out.

## What shows where

| Where | What | Rule |
|---|---|---|
| **Now**, during an air event | The event in the header (chip + sentence), then a card: advice for **staying put** or **going out** | Home → staying put. Work, a new place or an unknown one → going out (as on the board). Tap to see the other. |
| **Now**, no event | The same card for the pollutant or pollen at the highest *high* level | Nothing shows when nothing is high. |
| **A flare moment** in the timeline | One fact first: "It was 16° colder than three hours before." | **Facts only.** The board's "likely triggered this flare-up" lines were dropped (owner: "stay with the facts and drop anything causal"). |

## Events and how they're detected

| Event | Real detection | Demo (Settings › Design crit › Air event) |
|---|---|---|
| Wildfire smoke | None yet: needs Ambee's fire API | yes |
| Thunderstorm + high pollen | Apple Weather says thunderstorm and pollen is high | yes |
| Temperature drop | ≥ 15° F colder than three hours ago (`TempDrop`) | yes |
| Mold weather | Rain + humidity > 60% + ≥ 65° F (current weather stands in for "recent rainfall" until hourly precipitation is in the look-back) | yes |

Only real readings produce the after-flare fact on a moment.

## Demo labels

Owner, Oct 17: we're not testing with users yet, so the "Demo" tags are off screen (event chip, pollen counts, Insights
header, doctor summary). Demo data still never enters frames, the lift table or Insights. Put the labels back before
user testing.
