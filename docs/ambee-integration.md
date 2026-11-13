# Ambee integration (ready, on demo data)

Decided Oct 17, 2026: **assume Ambee.** The contract and key aren't in hand, so the app runs on
`DemoAmbee` (pretend data in Ambee's own shapes and units), and every table, mapping and screen is built
so that turning on the key changes one thing: `AmbeeClient.current` returns the live client.

See [ambee-trigger-datasets.md](ambee-trigger-datasets.md) for what Ambee offers and why each dataset
matters, and the FigJam board "On API Calls Scoping" for when each call happens.

## What exists

| Piece | Where | Status |
|---|---|---|
| Response models (air quality, pollen v3 with species, weather, fire) | `AsthmaCore/Conditions/Ambee.swift` | Air quality and pollen **checked against live responses** (Nov 13, 2026): pollen hours are `timestamp` / `unixTs`, history names `majorPollutant`, latest returns the station's own lat/lng. Weather and fire still as documented. Every field optional. |
| `AmbeeHour`: one hour at one place, our units | same | µg/m³, ppb, grains/m³, °F, %. `isForecast` marks forecast hours. |
| Mapping to readings (`observations(source:)`) | same | Each reading labelled with its source ("Ambee" / "Ambee (demo)"), outdoor, model-grid scale. |
| Mapping to the look-back (`Ambee.lookBack`) | same | 48 h history → the two windows the look-back already stores. |
| `AmbeeSource` protocol: `latest`, `history` (48 h), `forecast` | same | The app only talks to this. |
| `DemoAmbee` | same | Deterministic by place and hour: ozone afternoons in summer, particles at rush hour, tree pollen in spring, grass in early summer, ragweed in late summer, a cool front every few days. |
| `AmbeeClient` (live) | `AsthmaLog/Providers/AmbeeClient.swift` | Air quality and pollen only; weather stays on WeatherKit (poc-estimate.md). Endpoints: `/latest/by-lat-lng`, `/v3/pollen/latest?speciesRisk=true`, `/history/by-lat-lng`, `/v3/pollen/history`, `/forecast/aq/by-lat-lng`, `/v3/pollen/forecast/48hrs`, plus `/fire/latest/by-lat-lng` on smoke-like days. Header `x-api-key`. Each returned 200 live; history gives hourly rows for the range asked, forecasts 48 hours. `latest` merges air and pollen, which arrive stamped at different hours (`Ambee.newest`). |
| Key | `AMBEE_API_KEY` in `ios/Config/Secrets.xcconfig` | Settings › Data sources shows "Demo data" until it's set. |
| `CachedAmbee` | `AsthmaCore/Conditions/AmbeeCache.swift` | Every live call goes through it (`AmbeeClient.current`). Places snap to a ~500 m cell and Ambee is asked for the cell's centre. Latest: once per cell per hour. History: past hours kept 60 days, only gaps fetched; hours Ambee has nothing for aren't asked again; the last ~3 h (Ambee lags) at most hourly. Forecast: reused 3 h. Simultaneous asks share one call. Saved to Caches. |
| Where live Ambee shows | App | Each moment's air and pollen (`ConditionsService`); the look-ahead hours (`NowHour.forecast`: Ambee hourly ahead of AirNow's daily categories); pollen on every sky (`DemoPollen.best`: the moment's real readings, the Design-crit demo season only when it has none). Without a key, all of this stays on the labelled demo. |
| Resolution | Checked Nov 13 | History and forecast come back for the exact point asked (Ambee says 500 m). **Latest** comes back from a named point that can be several km away (6.5 km in San Francisco), with its own lat/lng. |
| History reach | Checked Nov 13 | The POC key returns **two days** of history; a request reaching further back is a 400 for the whole range. `CachedAmbee` never asks beyond 47 h, so the chart's lines and the baselines' air come from what was fetched in time. |
| Where history shows | App | The chart's lines behind now (`NowHour.history`, on a 3-hour boundary so a new hour isn't a new call) and each baseline's air (`BaselineFiller.dayOfAir`). |
| New signals | `Signal.pollenTree`, `.pollenGrass` | Alongside the existing `pollenWeed`. |

## The rules while it's demo

- **Display only.** Demo Ambee data is labelled "Ambee (demo)" wherever it shows and **never** enters
  frames, the lift table, Insights or the look-ahead. Same rule as demo pollen and demo moments.
- **Fail open.** A failed Ambee call never blocks a log; whatever loaded is used.

## When the key arrives

1. ~~Put the key in `Secrets.xcconfig`, rebuild.~~ Done Nov 13 (add the `AMBEE_API_KEY =` line if your copy predates it).
2. ~~Check the response models against live responses.~~ Done Nov 13 for air quality and pollen. Then run the bake-off in ambee-trigger-datasets.md ("Write down…") against the live response, and fix the
   response models where Ambee's shapes differ from the docs. The decoding tests show which fields matter.
3. Wire `AmbeeClient.current` into `ConditionsService` (current reading), `LookBackService` (history,
   replacing the OpenAQ hours), and the forecast (replacing AirNow's daily categories). Pollen bins
   (`pollen_weed`, and tree / grass as new bins) then fill from real data.
4. ~~Caching~~ Done Nov 13 (`CachedAmbee`). Still to do from the FigJam board's call budget: pre-cache Home and Work, call for a new place only after
   5 minutes there, reuse an hour's data across moments in that hour.
