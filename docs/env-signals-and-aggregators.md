# Making env signals useful — and talking to aggregators (Ambee)

Last updated: 2026-09-01

This is a working brief for product + vendor conversations. It is **not medical advice**.

The prototype already logs GPS + time, then stamps NWS / AirNow / FIRMS onto the event. That is enough to start a diary. It is **not** enough to tell someone what triggered an attack, because most of those stamps are regional outdoor context, not the air they breathed.

Two complementary ways to make it useful:

1. **Honesty** — say what the number actually is (how far away, how old, outdoor vs indoor). Ship this even if we never buy a vendor.
2. **Fidelity** — get closer to *outdoor ambient at this pin*, then (later) indoor / personal. Buy data only when it beats free sources on fields we will actually store and show.

Insights stay weak until we also sample **baseline days** (env without an attack). Better AQI on attack moments alone still cannot compute lift.

---

## What “useful” means for this app

A logged attack is useful if the user (and later, stats) can answer:

- What was the **outdoor air** like within a few km of me, around this hour?
- Which **hazard class** was active (heat, smoke, pollen, ozone, stagnant air, storm)?
- How **confident** is that, and is it a measurement or a model?
- How does this hour compare to **my normal days**?

It is *not* useful if we show a precise-looking badge that is actually a 25-mile monitor, a 12-hour forecast period, or a satellite hotspot 40 km upwind of someone else.

**Rule for UI and for the DB:** every env field gets provenance.

| Field | Example |
|-------|---------|
| `value` | AQI 87, 94°F, mixing height 180 m |
| `asOf` | observation time, not log time |
| `source` | AirNow, PurpleAir+EPA correction, HRRR, NWS alert |
| `spatialScale` | `station` \| `neighborhood` \| `city` \| `region` \| `model_grid` |
| `distanceKm` | km from GPS pin to the sensor / station / fire |
| `confidence` | high / medium / low, or vendor interval |
| `exposureKind` | `outdoor_ambient` (always, until we have indoor/personal) |

Copy pattern: **“Outdoor AQI 87 (PM2.5) · 11 mi from Denver-CAMP · 4:00p”** not **“AQI 87”**.

---

## Temperature

**Today:** NWS *forecast period* temp (often a 12-hour bucket), not a station reading. Extreme = ≤20°F or ≥95°F.

**Why that’s weak:** asthma care about the air *now* — heat, cold, and humidity. A forecast period can be several °F off and ignores humidity entirely.

### Honesty (no vendor)

- Label it **“Forecast high/low for this period”** if we keep NWS forecast.
- Prefer **nearest METAR / NWS station observation** (`api.weather.gov` stations + `/observations/latest`). Show station name + distance.
- Store **humidity / dewpoint** from the same observation. Dry cold and humid heat are different triggers.

### Fidelity

| Approach | Spatial scale | Notes |
|----------|---------------|--------|
| NWS/METAR observation | ~5–30 km to station | Free, official, US. Best first upgrade. |
| Open-Meteo / HRRR `temperature_2m` | ~3 km (US) | Free, hourly, includes humidity, wind, dewpoint. |
| Aggregator “hyperlocal weather” | claim ~0.5–3 km | Ask if it is **observation** or **downscaled model**. |
| Personal weather station | backyard | Sparse; only if we let users attach a station ID. |

**Do not** call it “your temperature.” Call it **outdoor air**. Indoor (AC, heating) is a different number we do not have.

### Ask Ambee

- Is `/weather/latest/by-lat-lng` an **observation**, a **reanalysis**, or a **forecast hour**?
- Native grid size vs interpolated-to-the-pin?
- Do you return **humidity, dewpoint, wet-bulb, wind, pressure** in the same call? (We want those.)
- Station ID + distance to nearest real obs, or only a modeled point?
- History: 48h hourly at that lat/lng (needed for lag: “was it 95°F yesterday?”).

**Buy weather from them only if** it beats Open-Meteo/HRRR on humidity + global coverage. For a US-first prototype, METAR + Open-Meteo is enough.

---

## AQI — hyperlocal *or* clearly not

**Today:** AirNow current obs, 25-mile search, prefers PM2.5, no monitor distance in the UI. Ozone is ignored unless it wins the max.

This is the highest-stakes badge. Users treat AQI as “the air I am breathing.” It is not.

### Honesty (ship regardless of vendor)

Show, on every log:

1. **Pollutant that drove the number** (PM2.5 vs O3 vs other).
2. **Monitor or grid cell identity** + **distance from pin**.
3. **Observation time** (AirNow is often ~1h stale).
4. One line of copy: **“Regional outdoor air — not indoor, not this street.”**

If distance > ~10 km or the reading is a city-wide model, use the word **regional**. If we have a sensor within ~2 km, say **nearby outdoor sensor**.

Store **PM2.5 µg/m³ and O3 ppb separately**, not only a composite AQI. Ozone is spatially patchy and asthma-relevant; blending it into one AQI hides that.

### What “hyperlocal” actually means (ask every vendor this)

| People say | Usually means | Good enough for? |
|------------|---------------|------------------|
| Regulatory AQI (AirNow) | Sparse official monitors, 5–25+ miles | County-scale outdoor context |
| “500 m / hyperlocal grid” | **Model interpolation** (satellite + monitors + land use) | Neighborhood *estimate*, not a measurement |
| PurpleAir / low-cost network | Real sensor on a porch, dense in some cities | Street-scale PM2.5; needs **EPA smoke correction**; misses ozone |
| Indoor / wearable | Air the person actually inhaled | Personal exposure — different product |

Ambee markets **~500 m** global AQ. That is a **modeled surface**, not a sensor at the GPS pin. Still more local than a 25-mile AirNow grab — **if** they also give uncertainty and nearest-station distance.

True hyperlocal for asthma is **indoor + breathing zone**. Outdoor grids will never capture cooking, mold, or a smoker in the next room. Be explicit with Ambee and with users: we are buying **outdoor ambient**, and we will label it that way.

### Practical stack (can mix)

1. **AirNow** — keep as the official US number; always show distance + parameter.
2. **PurpleAir outdoor, EPA-corrected** — optional “nearby sensors” row when one exists within ~2–5 km. Fast, local, noisier.
3. **Aggregator grid (Ambee)** — fill gaps, ozone + PM2.5 + history, non-US later.
4. **Later:** user-owned sensor or “I’m indoors / outdoors” toggle on the log.

### Ask Ambee (AQI)

- Native **grid resolution** vs “interpolated to this lat/lng”?
- Blend recipe: % ground monitors vs satellite vs proprietary sensors? Different in US vs India vs rural West?
- **Wildfire smoke:** do you apply a PurpleAir/EPA-style correction, or do cheap sensors inflate PM?
- Return **per-pollutant** (PM2.5, PM10, O3, NO2) + US AQI, not AQI alone.
- **Uncertainty / confidence interval** at this point? Distance to nearest *actual* ground monitor?
- **History:** hourly 48h+ at lat/lng (lag features). Archives from 2010 are nice for research, not for the tap-to-log path.
- **Forecast** 24–48h: useful for warnings, not for stamping an attack that already happened.
- Indoor vs outdoor: will they put in writing that this is outdoor ambient only?

**Buy AQ from them if** they give per-pollutant + history + a confidence/distance field we can show. Do not buy a single AQI integer that looks more precise than AirNow but hides the same 25-mile monitor.

---

## Wildfires → smoke at *this* pin

**Today:** NWS keywords (`fire` / `smoke` / `red flag` / `burn`) **or** any FIRMS hotspot in a ~50 km box. Red Flag is fire *weather*. FIRMS is a thermal pixel (could be a burn pile).

Users care about **smoke in the air they breathe**, not a hotspot over the ridge.

### Split into three badges (do this even on free data)

| Badge | Meaning | Source ideas |
|-------|---------|----------------|
| **Fire weather** | Red Flag, fire warning — dry/windy, not necessarily smoke here | NWS event type (already in the alert) |
| **Active fire nearby** | Satellite or reported fire, with **km + bearing** | FIRMS / Ambee fire; filter confidence + FRP |
| **Smoke here** | Elevated PM2.5 **and/or** a smoke plume overlapping the pin | AirNow/PurpleAir PM + NOAA HMS / HRRR-Smoke / vendor plume |

Drop the single **“Wildfire/smoke”** catch-all.

### Honesty

- Show **nearest fire: 18 km W, FRP x, confidence nominal, 3h ago**.
- If the only signal is Red Flag: **“Fire weather — no smoke detected at this location.”**
- If FIRMS count > 0 but AQI is Good: **hotspot nearby, air still clean** (or upwind). Downwind matters more than distance.

### Ask Ambee (fire)

Their fire API returns detections (`lat/lng`, `frp`, `confidence`, `fireType` detected vs reported, sometimes `fireName` / `areaBurnt`) and a **North America 4-week risk** product.

- Search **radius** for `/fire/latest/by-lat-lng`? (Docs don’t show one — what is the default box?)
- **Smoke plumes in the API** or only on the marketing page? We need **smoke at this point**, not a list of fires.
- Can you return **nearest fire distance + whether the pin is in a modeled smoke plume**?
- How do you de-dupe industrial heat / ag burns vs wildfire?
- **Do not sell us fire-risk forecast** as the attack stamp. Risk ≠ smoke today.

**Buy fire from them if** they give distance + plume/smoke-at-point. Otherwise keep FIRMS + treat **PM2.5 as the smoke sensor**, which is what the lung actually sees.

---

## Inversions → mixing height / stagnant air

**Today:** heuristic (calm clear night + ≥15°F day/night spread). The UI already says it is not measured. Accuracy is low.

What actually matters for asthma: **a shallow mixing layer trapping PM/ozone/smoke near the ground**. “Inversion” is meteorologist jargon; **stagnant / trapped air** is the user-facing idea.

### Honesty

- Rename badge to **“Trapped air?”** or **“Stagnant air (model)”**.
- Never imply a sounding was taken at the user’s house.

### Fidelity (free, US)

- **HRRR / Open-Meteo `boundary_layer_height` (PBLH)** at the pin, hourly.
- Store mixing height in meters. Badge when **PBLH is low** (e.g. &lt; 300–400 m at night) **and** PM or smoke is elevated.
- Keep **NWS Air Stagnation / Air Quality Alert** as a named extreme-weather event (official, rare, high signal).

Soundings (radiosonde) are the gold standard and too sparse to stamp every log. Mixing height from HRRR is the right prototype upgrade.

### Ask Ambee

- Do you have **mixing height, inversion, or atmospheric stability** at lat/lng? (Not listed on the public endpoint table.)
- If no: we will compute it from Open-Meteo/HRRR and only use you for AQ/pollen.

**Likely do not buy “inversion” from an aggregator** unless they show a vertical profile. This is a model field we can get free.

---

## Storms → extreme weather events

**Today:** one `hasStormAlert` / `stormSummary` bucket. Keyword match stuffs **heat, cold, freeze, fog, air quality, smoke, wind, winter, thunder** into “storm.” The UI already shows the NWS *event name*, which is the good part.

NWS already classified the event. We should **stop re-classifying with keywords**.

### Rename and taxonomize

Use NWS `event` + `severity` + `certainty` + `urgency` (we currently drop the last two).

Suggested classes for badges and later stats:

| Class | Examples |
|-------|----------|
| Heat | Heat Advisory, Excessive Heat Warning |
| Cold | Freeze, Wind Chill, Extreme Cold |
| Air quality | Air Quality Alert, Smoke Advisory |
| Fire weather | Red Flag Warning |
| Wind | High Wind, Dust Storm |
| Winter | Winter Storm, Blizzard |
| Convective | Severe Thunderstorm, Tornado |
| Flood / other | Flood, Dense Fog |

UI: **named event** as now, grouped under **“Extreme weather”** not “storm.”

Store the **full alert list**, not a semicolon-joined string, so Heat Advisory and Red Flag can both fire on one log.

### Ask Ambee

They have a **Natural Disaster** API (GDACS-style, 6h, last month). That is **not** a replacement for NWS watches/warnings.

- Confirm disasters ≠ NWS alerts.
- For the US, **keep NWS**. Use Ambee disasters only if we go global and need earthquakes/floods — low priority for inhaler logs.

**Do not buy weather alerts from Ambee for v1.** We already have the better US source for free.

---

## Highest-ROI add we don’t have: pollen

Ambee’s pollen API (tree/grass/weed, ~500 m claim, 48–120h forecast, history) is the gap most likely to matter for allergic asthma and **does not exist in the prototype at all**.

Ask:

- Species vs only tree/grass/weed buckets?
- NAB-style risk levels vs raw counts?
- Same provenance fields: as-of, spatial scale, outdoor-only.
- Coverage holes (their docs exclude some regions, e.g. parts of South America).

If the meeting is “what should we pilot,” **pollen + per-pollutant AQ + 48h history** beats a nicer temperature integer.

Trial field map (what to call vs skip): **[Ambee datasets vs breathing triggers](./ambee-trigger-datasets.md)**.

---

## Suggested architecture (vendor-agnostic)

Diagram, event/observation model, and today→target mapping: **[Information / data architecture](./data-architecture.md)**.

```
Log tap
  → GPS + time + indoor/outdoor (ask the user; default unknown)
  → Enrichment providers (parallel, independently fail):
        weather obs     (METAR / Open-Meteo / Ambee weather)
        air quality     (AirNow + optional PurpleAir + optional Ambee AQ)
        pollen          (Ambee or tomorrow.io / others)
        alerts          (NWS US; later per-country)
        fire/smoke      (FIRMS + PM2.5; optional vendor plume)
        mixing height   (HRRR / Open-Meteo)
  → Store normalized features + provenance JSON
  → UI shows named hazards + “how local is this?”
```

Normalize to bins for insights, independent of vendor:

`temp_band`, `humidity_band`, `pm25_band`, `ozone_band`, `pollen_risk`, `aq_alert`, `heat_alert`, `smoke_at_point`, `mixing_height_m`, `hour_of_day`

Keep raw vendor payloads in `envRawJson` (already exists).

---

## Ambee meeting: what to walk in with

### One-sentence product

We stamp **attack moments** with **outdoor environmental context**. We will label spatial scale honestly. We want fields that support **personal lift stats**, not a prettier badge.

### Pilot we could run in 2 weeks (Denver + a smoke-prone CA pin)

Same two demo points we already have. Side-by-side:

| Field | Our stack today | Ambee |
|-------|-----------------|-------|
| Temp / humidity | NWS forecast | `/weather/latest/by-lat-lng` |
| AQI / PM2.5 / O3 | AirNow 25 mi | `/latest/by-lat-lng` |
| Pollen | none | `/v3/pollen/latest` |
| Fires | FIRMS box + NWS keywords | `/fire/latest/by-lat-lng` |
| Alerts | NWS | (keep NWS) |
| History 48h | none | `/history/...` |

Ask for **sample JSON** for those two lat/lngs (and one rural point with no nearby monitor) *before* pricing.

### Buy / skip / later

| Buy if the bake-off wins | Skip / keep free | Later |
|--------------------------|------------------|-------|
| Pollen | NWS alerts | Indoor/personal sensors |
| AQ per-pollutant + history + confidence | Fire-risk 4-week forecast | Federated / cohort models |
| Smoke-at-point if they really have plumes | “Inversion” unless they have PBLH | Global disaster API |
| Weather only if humidity+global beats Open-Meteo | Single AQI integer with no distance | |

### Questions to get in writing

1. Spatial resolution **native vs interpolated**.
2. Distance to nearest **real** ground sensor for this pin.
3. Observation time vs model valid time.
4. Per-pollutant + pollen species, not only indexes.
5. Smoke **at the coordinate**, not a list of regional fires.
6. 48h hourly history on the same schema as “latest.”
7. Outdoor-ambient disclaimer we can show in-product.
8. Price unit: per lat/lng/hour vs monthly seat; what a diary app’s QPS looks like (one enrich per log + optional daily baseline).
9. SLA and US vs global quality difference (we are US-first; NWS/AirNow are strong here).

### What we will not claim, even with their data

- “This triggered your attack.”
- Indoor air quality.
- Clinical-grade inversion.
- Hyperlocal if the number is a 500 m model cell with no uncertainty.

---

## If we change nothing about vendors this week

Still worth doing in the app — these make the *current* sources useful:

1. Rename storm → **extreme weather**; use NWS event types.
2. AQI line: pollutant + **miles to monitor** + as-of time + “regional outdoor.”
3. Temp: switch to **station observation** or label as forecast; add humidity.
4. Split wildfire into **fire weather / fire nearby (km) / smoke (via AQI).**
5. Replace inversion boolean with **mixing height** (Open-Meteo) or drop the badge until we have it.
6. Prompt **indoors vs outdoors** on the log.
7. Start **baseline env samples** (app open or 1×/day) — otherwise no vendor makes insights trustworthy.
