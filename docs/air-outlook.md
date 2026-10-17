# Air outlook

What the air is doing, what it just did, and whether it will clear. This sits on top of the predictive engine ([predictive-engine.md](predictive-engine.md)): the engine asks "does this hour look like your inhaler days?"; the outlook supplies the hours and the events it reads.

**We don't model the atmosphere.** Apple Weather, AirNow and (later) Ambee already run forecast models that account for wind, rain and chemistry. The outlook is plain, testable code on top of theirs, in `ios/AsthmaCore`.

## Layers

| Layer | Job | Where |
|---|---|---|
| 1. Hours in | Hourly weather, air and pollen: the past 72 h and the next 2–5 days | `AsthmaLog/Providers` |
| 2. Bands | Raw number → band, same edges for past and future | `Frames/Banding.swift` |
| 3. Event detectors | Hours → events: "it fell 12°F in 3 hours" | `Frames/TempDrop.swift`, more to come |
| 4. Personal scoring | Rate table, gate, windows | `Forecast/` |
| 5. Words | Weather row, clearing line, look-ahead copy | `Forecast/OutlookCopy.swift`, `Narrator/` |

## Event detectors

Each detector is one function from hourly values to an event, with tests. The same function runs on a logged moment (and fills a bin) and on a forecast hour (and drives a heads-up), so past and future stay one frame.

| Detector | Rule | Bin | Status |
|---|---|---|---|
| **Temperature drop** | Warmest reading in the 3 h before, minus the reading at the hour, ≥ 10°F | `temp_drop` (v4) | Built |
| Clearing line | Air forecast: how long a layer stays above Good. Wind and rain give the plain reason | None (display only) | Next |
| Recent smoke | Smoke-like air 1–3 days before, clear today. Needs a stricter smoke edge | `smoke_recent` | Planned |
| Storm front | Temperature drop + humidity jump + storm condition or alert. With Ambee: + high grass or weed pollen → thunderstorm heads-up | `storm_front` | Planned |
| Severe weather | NWS tornado / severe thunderstorm warning at the place | None (display only, too rare to gate) | Planned |
| SO₂ elevated | SO₂ above 35 ppb (Ambee). Shown on the sky only then | None | With Ambee |

Missing hours make an event **unknown**, not "no". A frame without hourly history adds nothing to the `temp_drop` row.

## What the user sees

- **Weather row** (top of the sky's strata scale): the icon changes when an event is active (`thermometer.low` for a temperature drop) and hold-to-read adds one line about what came before: "Dropped 12°F in the 3 hours before."
- **Insights**: a `temp_drop` row appears only when it passes the usual gate, with raw counts.
- **Look-ahead**: before the gate, a forecast drop is a general heads-up ("The forecast shows a sharp temperature drop. That's a general heads-up, not your pattern yet.").

The words describe the weather. Whether it matters for you is Insights' job. No causal claims ("cold air constricts your airways"), no "you will".

## Not in the outlook

- Our own pollution model, or wind-based "how long will it last" rules. The air forecast already includes the weather.
- A "stagnant air" bin. It would repeat PM2.5 and ozone and double-count in the score. If wanted later: a mixing-height source and the trapped-air badge in [env-signals-and-aggregators.md](env-signals-and-aggregators.md), which is a new data source (ask first).
- "Tornado lung". It isn't a diagnosis, and its exposures (cleanup dust, mold, generator CO) are indoors. They belong in voice-note tags the user confirms.
