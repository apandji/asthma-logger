# Team handoff — Asthma trigger log prototype

Last updated: March 2026

## Vision

Barebones asthma trigger log: user taps when using their inhaler → capture **precise geolocation + timestamp** → attach **environmental context** (AQI, heat/cold, storms, wildfires, inversions) → optional **feeling** → offline-first with sync. Long-term: personal + collective insights on what triggers attacks.

---

## What’s live today

| Item | Detail |
|------|--------|
| **App** | https://asthma-logger.vercel.app |
| **Repo** | https://github.com/apandji/asthma-logger |
| **Stack** | Next.js (App Router), Prisma + Postgres (Supabase), IndexedDB offline queue |
| **Env APIs** | NWS (free), EPA AirNow, NASA FIRMS |

### User flow

1. Tap **Log inhaler use** (no feeling required upfront).
2. Browser geolocation → save to IndexedDB immediately (works offline).
3. Background sync to server → `enrichEnvironment()` fetches NWS/AirNow/FIRMS.
4. User can optionally tag each log with feeling: **ok / mild / bad** (PATCH after sync).

### Demo mode

Append `?demo=1` to try preset locations (Denver, Northern CA red-flag area) without GPS.

### UI conventions

- Emojis on **env tags** and **feeling buttons** only.
- Env tags: severity colors (blue info, green/yellow/orange/red) + hover/tap tooltip showing data source.
- Named weather alerts as tags (e.g. “Heat Advisory”), not generic “weather alert”.

---

## Local development

```bash
cd asthma-log   # or clone repo
npm install
cp .env.example .env   # set DATABASE_URL
npx prisma db push     # or run prisma/supabase-init.sql on Supabase
npm run dev
```

Open http://localhost:3000

---

## Environment variables (Vercel)

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | Yes | Supabase Postgres connection string |
| `AIRNOW_API_KEY` | Recommended | EPA AirNow AQI by lat/lon |
| `FIRMS_MAP_KEY` | Optional | NASA FIRMS satellite hotspots (~50 km box) |

**Health check:** `GET /api/health/env-sources` — confirms AirNow/FIRMS keys are accepted.

---

## Key source files

| Path | Purpose |
|------|---------|
| `src/app/home-client.tsx` | Main UI, demo mode, feelings, env badges |
| `src/lib/env-data.ts` | NWS / AirNow / FIRMS enrichment |
| `src/lib/env-badges.ts` | Badge labels, emoji, severity, `source` |
| `src/lib/env-colors.ts` | Severity → color mapping |
| `src/lib/feelings.ts` | Feeling options |
| `src/lib/local-db.ts` | IndexedDB + sync queue |
| `src/lib/logs.ts` | `upsertAndEnrich`, DTO mapping |
| `prisma/schema.prisma` | `AttackLog` model |

### API routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/logs` | GET, POST | List / create log |
| `/api/logs/sync` | POST | Batch offline sync |
| `/api/logs/[id]` | PATCH | Update `feeling` |
| `/api/health/env-sources` | GET | Env API diagnostics |

---

## Data model (`AttackLog`)

Stored per inhaler event:

- `id`, `clientId`, `loggedAt`, `latitude`, `longitude`
- `feeling` — optional: `ok` \| `mild` \| `bad`
- **Enrichment:** `temperatureF`, `aqi`, `hasStormAlert`, `stormSummary`, `hasWildfireNearby`, `wildfireSummary`, `hasInversion`, `envRaw` (JSON snapshot)

### Env detection (current heuristics)

| Signal | Source | Notes |
|--------|--------|-------|
| Temperature / extreme | NWS forecast | Extreme if ≤20°F or ≥95°F |
| Weather alerts | NWS active alerts | Keyword match on event/headline → `stormSummary` |
| Wildfire / smoke | NWS + FIRMS | Fire/smoke/red-flag keywords; FIRMS hotspots in ~50 km |
| Inversion | NWS forecast | Heuristic (not direct measurement) |
| AQI | AirNow | Requires `AIRNOW_API_KEY` |

---

## Known gaps / next steps

1. **Insights engine** — not built; see [insights-and-collective-vision.md](./insights-and-collective-vision.md).
2. **Collective / cohort features** — brainstorm only.
3. **Possible improvements:** re-enrich old logs, pollen/humidity, 24–48h lag features, auth/multi-user, charts UI, baseline sampling for “normal” vs attack windows.

---

## Further reading

**[Insights & collective vision](./insights-and-collective-vision.md)** — personal lift stats, logistic regression, geocell aggregates, k-anonymity, federated learning, phased roadmap, open questions for the team.
