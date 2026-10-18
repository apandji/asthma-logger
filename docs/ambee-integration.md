# Ambee integration (ready, on demo data)

Decided Oct 17, 2026: **assume Ambee.** The contract and key aren't in hand, so the app runs on
`DemoAmbee` (pretend data in Ambee's own shapes and units), and every table, mapping and screen is built
so that turning on the key changes one thing: `AmbeeClient.current` returns the live client.

See [ambee-trigger-datasets.md](ambee-trigger-datasets.md) for what Ambee offers and why each dataset
matters, and the FigJam board "On API Calls Scoping" for when each call happens.

## What exists

| Piece | Where | Status |
|---|---|---|
| Response models (air quality, pollen v3 with species, weather, fire) | `AsthmaCore/Conditions/Ambee.swift` | From Ambee's docs; decoding tested on the documented examples, **not yet on a live response**. Every field optional. |
| `AmbeeHour`: one hour at one place, our units | same | µg/m³, ppb, grains/m³, °F, %. `isForecast` marks forecast hours. |
| Mapping to readings (`observations(source:)`) | same | Each reading labelled with its source ("Ambee" / "Ambee (demo)"), outdoor, model-grid scale. |
| Mapping to the look-back (`Ambee.lookBack`) | same | 48 h history → the two windows the look-back already stores. |
| `AmbeeSource` protocol: `latest`, `history` (48 h), `forecast` | same | The app only talks to this. |
| `DemoAmbee` | same | Deterministic by place and hour: ozone afternoons in summer, particles at rush hour, tree pollen in spring, grass in early summer, ragweed in late summer, a cool front every few days. |
| `AmbeeClient` (live) | `AsthmaLog/Providers/AmbeeClient.swift` | Endpoints: `/latest/by-lat-lng`, `/v3/pollen/latest?speciesRisk=true`, `/weather/latest/by-lat-lng`, `/history/by-lat-lng`, `/v3/pollen/history`, `/weather/history/by-lat-lng`, `/forecast/aq/by-lat-lng`, `/v3/pollen/forecast/48hrs`, `/weather/forecast/by-lat-lng`. Header `x-api-key`. Compiled, never run. |
| Key | `AMBEE_API_KEY` in `ios/Config/Secrets.xcconfig` | Settings › Data sources shows "Demo data" until it's set. |
| New signals | `Signal.pollenTree`, `.pollenGrass` | Alongside the existing `pollenWeed`. |

## The rules while it's demo

- **Display only.** Demo Ambee data is labelled "Ambee (demo)" wherever it shows and **never** enters
  frames, the lift table, Insights or the look-ahead. Same rule as demo pollen and demo moments.
- **Fail open.** A failed Ambee call never blocks a log; whatever loaded is used.

## When the key arrives

1. Put the key in `Secrets.xcconfig`, rebuild.
2. Run the bake-off in ambee-trigger-datasets.md ("Write down…") against the live response, and fix the
   response models where Ambee's shapes differ from the docs. The decoding tests show which fields matter.
3. Wire `AmbeeClient.current` into `ConditionsService` (current reading), `LookBackService` (history,
   replacing the OpenAQ hours), and the forecast (replacing AirNow's daily categories). Pollen bins
   (`pollen_weed`, and tree / grass as new bins) then fill from real data.
4. Apply the call budget from the FigJam board: pre-cache Home and Work, call for a new place only after
   5 minutes there, reuse an hour's data across moments in that hour.
