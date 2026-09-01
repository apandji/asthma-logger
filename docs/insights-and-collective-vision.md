# Asthma trigger log — insights & collective intelligence (brainstorm)

> Working doc for product + engineering. Not medical advice. Patterns are hypotheses until validated with a clinician.

## Problem we're solving

Users log **attack moments** (inhaler use) with time, location, optional feeling, and environmental context (AQI, temperature, weather alerts, wildfire/smoke signals, etc.).

Over time we want to answer:

- **Personal:** "What conditions tend to be present when *I* reach for my inhaler?"
- **Collective:** "What can I learn from others — in my area, my climate, or my cohort — especially when I don't have much data yet?"

---

## Current data model (prototype)

Each **attack log** includes:

| Field | Examples |
|-------|----------|
| Time | `loggedAt` |
| Location | precise lat/long (stored per user) |
| Feeling (optional) | ok, mild, bad |
| Temperature | °F from NWS forecast |
| AQI | EPA AirNow (when keyed) |
| Weather alerts | NWS (heat, storm, cold, air quality, etc.) |
| Wildfire / smoke | NWS alerts + optional NASA FIRMS hotspots |
| Inversion | heuristic from NWS (not a direct measurement) |

**Gap for strong insights:** we mostly log **attack moments**, not **baseline** env on normal days. Personal and collective analysis both improve a lot if we add passive baseline sampling (see below).

---

## Layer 1: Personal insights engine

### Unit of analysis

One **attack moment** = timestamp + location + optional feeling + env snapshot at log time.

### What to compute (weekly or after N logs)

1. **Top associations** — "On 70% of your logs, AQI was Moderate+ vs 25% of background days"
2. **Time patterns** — "Most logs between 6–9am"
3. **Lag patterns** — "Often within 24h after a heat/smoke alert"
4. **Location clusters** — home / work / other (fuzzed zones in UI, not exact pins)

### Methods (simple → advanced)

| Stage | Approach | When |
|-------|----------|------|
| **A** | Rules + lift / odds ratios (`P(feature \| attack) / P(feature \| baseline)`) | First — most interpretable |
| **B** | Logistic regression on binned features | ~30+ attack logs |
| **C** | Gradient boosting + SHAP (LightGBM, etc.) | 50+ logs, with regularization |
| **D** | Time-series (Prophet, lag features) | When we add daily baseline + longer history |

### LLM role

Use LLMs to **narrate** pre-computed stats, not to invent triggers from raw rows.

Example output:

> "It seems like you reach for your inhaler more often on days with moderate–high AQI and active heat advisories. This is based on 12 logs over 6 weeks — correlation, not proof."

Always include: confidence, sample size, "talk to your doctor," correlation ≠ causation.

### Critical addition: baseline sampling

Without baseline, insights are weak ("you always have high AQI when you log" — because you only log when you feel bad).

**Proposal:** 1–2×/day (or on app open), record **env only** — no attack. Store as `baseline_sample` rows.

Compare attack days vs baseline days for the same user.

---

## Layer 2: Collective benefit (global scale)

### The tension

| Personal | Collective |
|----------|------------|
| "What triggers **me**?" | "What triggers **people like me** in **places like mine**?" |
| Needs my history | Needs privacy, scale, humility about causation |

**Principle:** user data stays user-owned; the crowd helps you learn faster (cold start, validation, regional context).

### What "collective" can mean

#### A. Regional norms (anonymous aggregates)

> "In your metro, 34% of attack logs this week coincided with AQI > 100."

- Bucket into **H3 geocells** or metro regions
- Never publish cells with fewer than **k users** (e.g. k = 50)
- UI: **"You vs your region"**

#### B. Cohort similarity

Group by non-identifying attributes:

- Climate zone (Köppen / WMO)
- Urban vs rural
- Optional self-reported tags (adult/child, allergic asthma — careful with medical framing)
- Country / language (weak proxy)

> "Among users in humid subtropical cities, smoke alerts appear on 40% of attack logs."

#### C. Trigger library (crowdsourced taxonomy)

After logging, optional: "What do you think triggered it?"

- smoke, pollen, exercise, stress, illness, cold air, perfume, etc.

Cluster free text → canonical tags over time. Feeds both personal recall and collective ontology.

#### D. Early warning / nowcast (population signal)

If attack logs **spike** in a geocell alongside smoke/heat/AQI:

- "Unusual asthma activity reported near you — consider precautions"
- Symptom surveillance, not diagnosis; avoid panic; show uncertainty

#### E. Federated / privacy-preserving ML (later)

- Train on device or federated averaging
- Global model learns broad patterns; personal head fine-tunes on recent logs
- Higher engineering cost; valuable at scale + under regulation

### Bayesian cold start (concept)

Cohort data = **prior**. Personal logs = **likelihood**. Combined = **posterior**.

New user in a hot, smoky climate gets sensible starting hypotheses before their 10th log.

---

## Architecture sketch

```
[User device]
  attack log + optional feeling
  local store + sync
  daily baseline env samples (future)
        ↓
[Regional API]
  env enrichment (provider per country)
  user-owned rows in DB
        ↓
[Nightly jobs]
  Personal:  features → insights JSON → UI (+ optional LLM narrative)
  Collective: geocell aggregates → cohort stats
        ↓
[Insights served]
  "Your patterns"
  "Near you" (k-anonymized)
  "Your cohort" (opt-in)
```

### Suggested tables (future)

| Table | Purpose |
|-------|---------|
| `attack_log` | user_id, time, location, env snapshot, feeling |
| `baseline_sample` | user_id, time, env only |
| `personal_insight` | user_id, period, ranked factors, narrative, confidence |
| `aggregate_cell` | geocell, period, counts, feature histograms — **no user ids** |

---

## Global env data (don't assume US-only APIs)

Normalize to shared feature bins (`aqi_band`, `temp_band`, `has_smoke_alert`, etc.) so Lagos and St. Louis share one schema.

| Region | Air quality | Weather / alerts | Fires |
|--------|-------------|------------------|-------|
| US | AirNow, EPA | NWS | FIRMS, NWS |
| EU | EEA, OpenAQ | national met, Meteoalarm | EFFIS |
| Global fallback | OpenAQ, IQAir, WAQI | Open-Meteo | FIRMS, GDACS |

---

## Privacy & trust

1. **Opt-in** for anything collective; default personal-only
2. **Location fuzzing** before aggregation (H3 res 6–7, ~1–5 km)
3. **k-anonymity** — no regional stats if cell has &lt; k users
4. **Export + delete** — GDPR-minded from day one
5. **No selling raw health data** — state business model clearly
6. **Copy discipline** — patterns, not prescriptions
7. **Children** — stricter defaults, parental consent flows
8. **Differential privacy** on published aggregates (optional, for maps/research)

---

## Product surfaces (ideas)

1. **Your week** — personal ranked triggers + confidence
2. **Near you** — anonymized regional pulse (if k met)
3. **Your cohort** — climate/urban peer patterns (opt-in)
4. **Trigger vote** — post-log optional context (feeds taxonomy)
5. **Research export** — de-identified dataset with explicit consent

---

## What collective adds that personal-only cannot

| Personal only | + Collective |
|---------------|--------------|
| "I log when AQI is high" | "High AQI is common on attack logs **here**" |
| Few logs → noisy stats | Cohort **priors** stabilize early insights |
| New user cold start | Day-1 regional/cohort context |
| Personal hunch | "Your smoke sensitivity looks **higher than** regional average" |

---

## Phased roadmap

| Phase | Focus |
|-------|--------|
| **Now** | Ship logging + env enrichment; personal lift stats; baseline sampling design |
| **v2** | Weekly personal insight screen; template or LLM narrative |
| **v3** | Geocell aggregates — "you vs area" (one country, k-anonymity) |
| **v4** | Cohort priors, trigger taxonomy, cold-start UX |
| **v5** | Spike detection; public health partnerships |
| **v6** | Federated learning; DP-published research aggregates |

---

## Risks to design against

- **Affluent-user bias** — smartphone users in cities ≠ global asthma burden
- **API inequality** — US-heavy alert coverage skews "global" models
- **Overconfident narratives** — LLM explaining noise from 8 logs
- **False reassurance** — "region quiet" while user's trigger is indoor mold
- **Regulation** — health-adjacent claims (EU MDR, FDA wellness boundary)

---

## ML / stats reference (personal layer)

Features to bin per log:

- `aqi_high`, `heat_advisory`, `wildfire_nearby`, `temp_extreme`, `hour_of_day`, `day_of_week`, `season`, `location_cluster`

Outputs:

- Lift scores per feature
- Logistic regression coefficients (interpretable)
- SHAP values from tree models (when enough data)

**Do not** use ML accuracy alone — optimize for **interpretability** and **appropriate uncertainty**.

---

## Open questions for teammates

- [ ] Minimum log count before showing personal insights?
- [ ] Opt-in UX for collective features — what do we promise in plain language?
- [ ] k threshold for regional views (50? 100?)?
- [ ] Baseline sampling: passive vs prompted — battery / annoyance tradeoff?
- [ ] Which countries/providers for v2 global enrichment?
- [ ] Clinical advisor review before any "insight" copy ships?
- [ ] Business model: subscription, research partnerships, public health grants?

---

## One-line vision

**A personal attack diary that gets sharper every week you use it — and, if you opt in, gets a head start from anonymized patterns in your climate, your season, and your corner of the world.**

---

*Last updated: 2026-09-01 — from Cursor agent brainstorm session.*
