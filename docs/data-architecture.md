# Information / data architecture

Sketch of how the asthma trigger log should hold and move data — current prototype plus the aggregator-ready target. Pair with [env-signals-and-aggregators.md](./env-signals-and-aggregators.md).

![High-level information architecture](./data-architecture.png)

---

## 1. Context — who owns what

```mermaid
flowchart LR
  subgraph userOwned ["User-owned (precise)"]
    GPS["lat/lon + loggedAt"]
    Feel["feeling"]
    IO["indoors / outdoors"]
  end

  subgraph outdoorAmbient ["Outdoor ambient (stamped, with provenance)"]
    Wx["weather obs"]
    AQ["PM2.5 / O3 / AQI"]
    Pol["pollen"]
    Alerts["NWS named events"]
    Smoke["fire nearby + smoke-at-point"]
    Mix["mixing height"]
  end

  subgraph derived ["Derived (no new PII)"]
    Bins["feature bins"]
    Insights["personal lift stats"]
  end

  GPS --> outdoorAmbient
  outdoorAmbient --> Bins
  Bins --> Insights
```

Precise GPS never leaves the user’s event row. Providers only receive a rounded point (or the same pin, server-side) and return **outdoor** fields. Insights run on bins (`pm25_band`, `heat_alert`, …), not on raw coordinates.

**Today:** one `AttackLog` row with flattened env columns and `envRawJson`. No user account, no baseline events, no per-observation provenance.

---

## 2. Runtime flow

```mermaid
sequenceDiagram
  actor U as User
  participant App as Device (IndexedDB)
  participant API as App API
  participant Orch as Enrichment orchestrator
  participant P as Env providers (parallel)
  participant DB as Postgres

  U->>App: tap log (or daily baseline)
  App->>App: store event locally (pending)
  App->>API: POST /api/logs/sync
  API->>DB: upsert Event (env pending)
  API->>Orch: enrich(lat, lon, loggedAt)

  par independent, fail-open
    Orch->>P: weather obs
    Orch->>P: air quality
    Orch->>P: pollen
    Orch->>P: NWS alerts
    Orch->>P: fire / smoke
    Orch->>P: mixing height
  end

  P-->>Orch: values + provenance + raw JSON
  Orch->>DB: Observations, Alerts, feature bins, raw payloads
  API-->>App: Event + display DTO
  App->>U: honest badges (named event, miles, as-of)
```

Each provider is optional. A missing AirNow key must not block temperature or alerts.

---

## 3. Logical information model

```mermaid
erDiagram
  USER ||--o{ DEVICE : has
  USER ||--o{ EVENT : logs
  DEVICE ||--o{ EVENT : queues
  EVENT ||--o{ OBSERVATION : stamped_with
  EVENT ||--o{ ALERT : may_have
  EVENT ||--o{ PROVIDER_PAYLOAD : archives
  EVENT ||--o| FEATURE_ROW : denormalizes_to

  USER {
    uuid id "future — none today"
  }

  EVENT {
    uuid id
    enum kind "attack | baseline"
    datetime logged_at
    float latitude "precise, user-owned"
    float longitude
    enum indoor_outdoor "indoor | outdoor | unknown"
    enum feeling "ok | mild | bad | null"
    enum env_status "pending | ready | partial | failed"
  }

  OBSERVATION {
    uuid id
    enum signal "see signal catalog"
    float value
    string unit
    datetime as_of
    string source
    enum spatial_scale "station | neighborhood | model_grid | region"
    float distance_km
    enum confidence "high | medium | low"
    enum exposure_kind "outdoor_ambient"
    string station_or_sensor_id
  }

  ALERT {
    uuid id
    enum class "heat | cold | air_quality | fire_weather | wind | winter | convective | other"
    string event_name
    string severity
    string certainty
    string urgency
    string source "NWS"
    datetime onset
    datetime expires
  }

  FEATURE_ROW {
    uuid event_id PK
    string temp_band
    string humidity_band
    string pm25_band
    string ozone_band
    string pollen_risk
    boolean heat_alert
    boolean smoke_at_point
    float mixing_height_m
    int hour_of_day
  }

  PROVIDER_PAYLOAD {
    string provider
    json body
    datetime fetched_at
  }
```

`FEATURE_ROW` is what personal insights (and later k-anonymized aggregates) should read. Swap Ambee for AirNow without changing the insight jobs.

---

## 4. Signal catalog (what an Observation can be)

| Signal | Unit | Typical source | Spatial scale we should claim |
|--------|------|----------------|-------------------------------|
| `temperature` | °F | METAR / Open-Meteo / Ambee weather | station or model_grid |
| `humidity` / `dewpoint` | % / °F | same as temperature | same |
| `pm25` | µg/m³ | OpenAQ nearest station, AirNow fallback, Ambee model | station / neighborhood / model_grid |
| `ozone` | ppb | OpenAQ nearest station, AirNow fallback, Ambee model | station or model_grid |
| `aqi_us` | index | derived from pollutants | inherits driver pollutant |
| `pollen_tree` / `_grass` / `_weed` | count or risk | Ambee (gap today) | model_grid |
| `mixing_height` | m | HRRR / Open-Meteo | model_grid |
| `nearest_fire_km` | km | FIRMS / Ambee fire | satellite pixel |
| `smoke_at_point` | 0/1 or density | plume model or high PM2.5 | model_grid |

**Not observations** (they are `ALERT` rows): Heat Advisory, Red Flag, Air Quality Alert, Severe Thunderstorm, etc.

**Split wildfire** into alert (`fire_weather`) + observation (`nearest_fire_km`) + observation (`smoke_at_point`). Do not store a single `hasWildfireNearby` boolean.

---

## 5. Observation record (the honesty contract)

Every env number the UI shows is an `OBSERVATION`, not a bare column.

```json
{
  "signal": "pm25",
  "value": 27.4,
  "unit": "ug/m3",
  "asOf": "2026-09-01T16:00:00Z",
  "source": "airnow",
  "spatialScale": "station",
  "distanceKm": 17.6,
  "confidence": "high",
  "exposureKind": "outdoor_ambient",
  "stationOrSensorId": "Denver-CAMP",
  "display": "Outdoor PM2.5 27 µg/m³ · 11 mi from Denver-CAMP · 4:00p"
}
```

If `spatialScale` is `model_grid` or `distanceKm` is large, copy says **regional** or **modeled**, not **at your location**.

---

## 6. Today vs target (mapping)

| Today (`AttackLog`) | Target |
|---------------------|--------|
| one row, attack only | `EVENT.kind` = `attack` \| `baseline` |
| `feeling` | stays on event |
| — | `indoor_outdoor` |
| `temperatureF`, `isExtremeTemp` | observations + `temp_band` / heat alert |
| `aqi`, `aqiCategory` | `pm25`, `ozone`, `aqi_us` observations + distance |
| `hasStormAlert`, `stormSummary` | `ALERT[]` with NWS class + event name |
| `hasWildfireNearby`, `wildfireSummary` | fire-weather alert + `nearest_fire_km` + `smoke_at_point` |
| `possibleInversion` | `mixing_height` observation |
| `envRawJson` | `PROVIDER_PAYLOAD` per source |
| `deviceId` unused | `DEVICE` + later `USER` |
| GET last 100 logs, no auth | user-scoped events; precise GPS not in aggregates |

A first migration can keep a wide event table and add `observations Json` + `alerts Json` beside the old columns. Split tables when insights land.

---

## 7. Insights path (does not change the event model)

```mermaid
flowchart TB
  E["Events + observations"] --> F["Feature rows"]
  B["Baseline events for same user"] --> F
  F --> P["Personal lift / odds vs baseline"]
  F --> C["Opt-in: H3 cell histograms, k-anonymity"]
  P --> UI["Your week"]
  C --> UI2["Near you / cohort"]
```

No vendor belongs in this layer. If Ambee replaces AirNow, only the observation `source` and `spatialScale` change.

---

## 8. Privacy boundary

```mermaid
flowchart TB
  subgraph neverPublish ["Never publish / never aggregate raw"]
    lat["precise lat/lon"]
    feel["feeling"]
    id["user / device id"]
  end

  subgraph mayAggregate ["Opt-in only, k-anonymized"]
    cell["H3 geocell"]
    bins["feature bins"]
    counts["event counts"]
  end

  lat -->|"fuzz to cell, drop pin"| cell
```

Outdoor provider calls are not a privacy leak of identity, but storing everyone’s pins in one unauthenticated `GET /api/logs` is. Auth + user scope is part of this architecture, not a later nice-to-have if anyone else uses the app.
