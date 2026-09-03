# Ambee datasets vs breathing-challenge triggers

Reviewed against [docs.ambeedata.com](https://docs.ambeedata.com) (2026-09-03). For a **15-day trial**: pull the “use” rows, skip the rest.

## Implemented in the app

When `AMBEE_API_KEY` is set, each **new** log (after sync) calls Ambee endpoints in parallel, fail-open:

| Call | Stored / shown |
|------|----------------|
| `/latest/by-lat-lng` | `PM2.5`, ground-level `O₃`; AQI if AirNow missing |
| `/v3/pollen/latest` | Tree / grass / weed risk (+ top species in tooltip) |
| `/weather/latest/by-lat-lng` | Outdoor temp (preferred over NWS forecast), humidity, dewpoint |
| `/fire/latest/by-lat-lng` | Nearest fire km if ≤ 50 km |
| `/disasters/latest/by-lat-lng` + `/disasters/latest/by-continent` | Storms (SW), cyclones (TC), extreme temp (ET), wildfires (WF), volcanoes (VO, shown on **Air**, not Wildfires) — **with distance** |

Snapshot JSON lives in `AttackLog.envSnapshotJson`. Badges say **outdoor / modeled**. Existing Supabase DBs need `prisma/supabase-add-env-snapshot.sql` once.

NWS alerts, AirNow (when keyed), and FIRMS still run. We do **not** call fire-risk, ILI, or weather.`ozone`. Inversion heuristic is dropped (not measurable here).

This is **outdoor ambient context**, not a diagnosis. Common inhaler-use triggers Ambee can help *associate* with a log: pollen, particles, ozone, heat/cold/humidity, and (weakly) nearby fire. It cannot see indoor mold, perfume, exercise, illness in *this* person, or a true inversion.

---

## What to call in the trial (priority)

| Priority | API | Endpoint to hit | Why it matters for breathing |
|----------|-----|-----------------|------------------------------|
| **1 — unique gap** | Pollen | `GET /v3/pollen/latest?lat=&lng=` (+ `speciesRisk` in North America) | Tree / grass / weed **counts + NAB-style risk**. We have **none** of this today. Species in NA: cedar/juniper, oak, birch, ragweed, etc. |
| **1** | Air quality | `GET /latest/by-lat-lng?lat=&lng=` | **PM2.5, PM10, O3, NO2, SO2, CO** + US AQI + `aqiInfo.pollutant` (which chemical is driving). Beats our single AirNow integer. |
| **1** | Weather | `GET /weather/latest/by-lat-lng?lat=&lng=` | **Temperature, humidity, dewPoint, apparentTemperature, wind, precip, visibility**. Humidity/dewpoint are the fields NWS forecast was missing. |
| **2** | AQ / pollen / weather history | `GET /history/by-lat-lng` and `/v3/pollen/history` (`from`/`to`, **48h hourly**) | Lag: “smoke or high pollen in the 24h *before* the log.” |
| **2** | Fire latest | `GET /fire/latest/by-lat-lng` | Nearby **detected/reported** fires (FRP, confidence, last 7 days). Pair with **PM2.5**, not as “smoke here.” |
| **3** | Forecasts | AQ `/forecast/aq/by-lat-lng`, pollen `/v3/pollen/forecast/48hrs`, weather `/weather/forecast/by-lat-lng` | Warnings, not stamping an attack that already happened. One bake-off call is enough. |

Always use **lat/lng** (same pin as the inhaler log). City / country / postal endpoints are too coarse for a diary.

Auth: header `x-api-key`. Watch **206 / 422 / 429** — trial quotas trim or stop mid-response.

---

## Trigger catalog → Ambee field

### Pollen (allergic airways) — **use; we cannot get this from NWS/AirNow**

| Trigger | Ambee field | Notes |
|---------|-------------|--------|
| Tree pollen | `Count.tree_pollen`, `Risk.tree_pollen` | NAB bins: Low 0–99, Mod 100–212, High 213–939, VH 940+ |
| Grass pollen | `Count.grass_pollen`, `Risk.grass_pollen` | Low 0–29 … VH 342+ |
| Weed / ragweed | `Count.weed_pollen`, `Risk.weed_pollen` | NA species includes **Ragweed** |
| Specific allergen | `Species.Tree.*` / `Weed.Ragweed` | North America genera listed in docs. `speciesRisk=true`. Rest of world is often tree/grass/weed **only**. |

**Coverage hole:** pollen is **not** South America, Arctic, Antarctica, oceans. Fine for a US prototype.

**Store:** all three counts + risks + any non-zero species. Display the highest risk class, not a fake “pollen AQI.”

### Particles and gases (irritant / inflammatory)

| Trigger | Ambee field | Notes |
|---------|-------------|--------|
| Fine particles (smoke, traffic, haze) | `PM25` | Primary outdoor asthma pollutant. µg/m³. |
| Coarse dust / PM10 | `PM10` | Dust storms, some wildfire ash. |
| Ground-level **ozone** | `OZONE` on **air-quality** API | Do **not** use weather.`ozone` (~300) — that is **column** ozone, not what you breathe. |
| Traffic / combustion | `NO2`, `CO` | Useful if logs cluster near roads. |
| Industrial / coal | `SO2` | Sparse signal; keep in raw JSON. |
| Combined index | `AQI` + `aqiInfo.pollutant` / `category` | Always keep the **driver pollutant**. A “Good” AQI can hide moderate ozone. |

Docs claim **~500 m** AQ grid, hourly, US EPA AQI. Sample JSON has `timestamp` / `localTime` — store those as `asOf`. **No distance-to-monitor** in the public schema; still label **outdoor modeled/ambient**, not “air at this address.”

### Heat, cold, humidity, wind (non-allergic)

| Trigger | Ambee weather field | Notes |
|---------|---------------------|--------|
| Heat | `temperature`, `apparentTemperature` | Feels-like includes humidity/wind. |
| Cold | `temperature` (and wind) | Better than our 12-hour NWS period. |
| Dry or sticky air | `humidity`, `dewPoint` | **Highest-value weather fields** for asthma. |
| Wind / dust | `windSpeed`, `windGust`, `windBearing` | Downwind of fire; dust. |
| Rain (sometimes clears pollen) | `precipIntensity`, `precipProbability` | Context, not a trigger by itself. |
| Fog / poor visibility | `visibility`, `icon`/`summary` | Weak proxy only. |

Units: pass `units=si` if you want SI; default looks imperial in their samples (`temperature: 70`, `dewPoint: 69.2`).

Marketing weather page says **~5 km** native (sub-km on request); developer docs still say 500 m. **Ask / measure in the trial** — don’t trust the 500 m claim for weather.

### Fire and smoke

| Trigger | Ambee | Use? |
|---------|-------|------|
| Fire near the pin | `/fire/latest` — lat/lng, `frp`, `confidence`, `fireType` detected vs reported, sometimes name / area | **Yes** — compute **distance km** yourself. |
| Smoke in the lung | **Not a first-class field** on the public fire API | Use **PM2.5** (and ozone) as the smoke sensor. |
| “Will it burn later?” | `/fire/risk` — 4-week North America FWI-style | **Skip for trigger ID.** Risk ≠ exposure today. |

### Extreme weather (named events)

`/disasters/latest/by-lat-lng` plus `/disasters/latest/by-continent` (NAR for US pins). We keep **SW, ET, WF, TC, VO** and compute **distance from the inhaler pin**. Distant wildfires (Wildfires? row) and volcanoes (**Air** row — ash, not fire) are in-scope for the “far events affect local air” hypothesis; pair both with **PM2.5**. Skip EQ, drought, flood, sea ice for breathing.

NWS alerts stay as the free-API storms/heat column.

### Viral / “sick season” (contextual, not a personal trigger)

`/ili/forecast/by-lat-lng` — 30-day **ILI risk** plus optional 28-day pollen/weather (`details=true`). US + parts of EU. **Beta.**

Useful as “region is in a flu-like wave,” **not** “this log was caused by a virus.” Do not badge ILI on an inhaler event. Optional later for cohort priors.

### Skip for trigger identification

| Product | Why skip |
|---------|----------|
| Elevation | Static altitude, not a time-varying trigger. |
| Geocode | City name for UI only. |
| AQ by city / country | Too coarse. |
| Map tiles / webhooks | Not the log-stamp path. |
| Soil moisture / soil temp | Not a breathing trigger. |
| Weather `uvIndex` | Not a typical asthma trigger. |
| Weather `ozone` | Wrong ozone. |

**Ambee does not offer:** mixing height / inversion, indoor AQ, monitor distance, NWS-quality watches, or (in public fire docs) smoke-plume-at-point.

API **history is 48 hours** per request. “30+ years” / pollen from 2016 is a **bulk download**, not the REST diary path. For the trial, 48h lag is the useful window.

---

## How this maps onto our information model

Stamp **observations** (not a single AQI column):

| Observation signal | Ambee source |
|--------------------|--------------|
| `pm25`, `pm10`, `ozone`, `no2`, `aqi_us` | Air quality latest/history |
| `pollen_tree` / `_grass` / `_weed` (+ species) | Pollen latest/history |
| `temperature`, `humidity`, `dewpoint`, `wind` | Weather latest/history |
| `nearest_fire_km` | Fire latest, computed |
| `smoke_at_point` | **Derived**: high PM2.5 while fire nearby — not a vendor boolean |

Keep **NWS `ALERT` rows** for named extreme weather. Keep `PROVIDER_PAYLOAD` raw JSON for the trial bake-off.

---

## 15-day trial script (don’t burn quota)

**Three pins** (already in the app): Denver `39.7392, -104.9903`; Northern CA demo `41.7569, -120.1561`; plus one **rural** point with no nearby EPA monitor.

Per pin, **latest** (4 calls):

1. `/latest/by-lat-lng`
2. `/v3/pollen/latest?lat=&lng=` (add species flag)
3. `/weather/latest/by-lat-lng`
4. `/fire/latest/by-lat-lng`

Once per pin, **history 48h** for AQ + pollen + weather (3 calls) — this is the lag-feature test.

Optional once: AQ forecast, pollen 48h forecast, disasters, ILI `details=false`.

**Compare on the same pin, same hour:**

- Ambee `PM25` / `OZONE` / AQI vs our OpenAQ nearest-station row (AirNow is fallback only)
- Ambee temp/humidity vs NWS forecast period
- Ambee fire list vs FIRMS box + NWS Red Flag
- Pollen: anything vs nothing (we have no baseline)

Write down: did AQ include `timestamp` and a plausible PM2.5 in smoke country? Did pollen return NA species in Denver? Did weather humidity look like a station or a smooth model? Did fire return a radius you can measure?

---

## Honest limitations (say this in-product)

- Outdoor **modeled** surface (~500 m claimed for AQ/pollen; weather may be coarser).
- Not indoor air, not the street corner unless a sensor happens to sit there.
- Pollen is modeled counts/risk, not a Burkard trap in the backyard.
- Fire list ≠ smoke in the lungs; **PM2.5** is the exposure.
- 48h REST history is enough for short lag, not for “your last three autumns.”
