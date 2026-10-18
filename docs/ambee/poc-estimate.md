# Ambee POC: call estimate and reply

Ambee's offer (Oct 2026): *up to 10 users, 100 API calls per day across Pollen, Air Quality and Weather.*

This estimate uses Pandji's "Day in a Life (Bad Asthma Day, 3 inhaler uses)" model. **AQ and pollen come from Ambee; weather stays on WeatherKit** and isn't counted. Where we weren't sure, we rounded up, because testing will be heavy.

**The POC has no server.** Each phone calls Ambee directly, with the key in the app (an accepted TestFlight risk, per AGENTS.md). Caching is per phone, by place and hour, so one phone never asks twice for the same place and hour. A server is likely for a larger study; see the end.

## The model

| When | Ambee calls | Kind |
|------|-------------|------|
| 7 am, every day | Forecast AQ + pollen for **Home**, **Work** and each **Frequent** place = 4, plus 2 per Frequent place | forecast (up to 120 h / 5 days per request) |
| Each new place you stay at **more than 5 minutes** | Forecast AQ + pollen there = **2** | forecast |
| Each inhaler moment | Historical AQ + pollen at that place = **2** (the hour, plus the 48 h look-back if a range is one call) | history |
| Checking a trip (e.g. Denver next week) | Forecast AQ + pollen = **2** (Ambee covers 5 days; WeatherKit covers 10) | forecast |
| Baseline moments (about 3 ordinary hours a day, filled in a day later at a visited place or Home; `BaselineBackfill`, `BaselineFiller`) | 1 day of history per place per dataset: Home + Work = **4** (6 if a third place) | history |
| Fire | **Conditional**: only when the air looks smoke-like (high PM2.5 at the moment; NowHomeView's `fireKey`), about 1–2 per smoke day | current |
| Natural disasters | **Conditional** (proposed): with the morning pre-load, only when the weather forecast shows a severe condition (thunderstorm, high wind), Home and Work, about 0–2 a day on those days | not built |

A place becomes **Frequent** after more than 12 hours there, or more than 2 visits a week for at least 2 weeks. Frequent places join the 7 am pre-cache. The figures below assume **2 Frequent places per person** (the high end of 1–2) = +4 a day. At 1 Frequent place, subtract 2.

**Fire** is triggered by the air only: one call when the air at a moment looks smoke-like (high PM2.5), as the app does today. There's no season or region logic, so fire calls are occasional and come only on smoke-like days, about 1–2 per person on such a day.

### Two assumptions about history

- **A (used below): one history request = one call**, whether it returns a day or a range. A moment's 48 h look-back is then one call per dataset.
- **B: billed per hour returned.** A day becomes 24 calls, and a moment with a 48 h look-back becomes 48 per dataset (about 96 per moment). That doesn't work. We would have to request only the moment's hour (2 calls) and drop the AQ/pollen look-back (OpenAQ already gives PM2.5 and ozone look-back). Baselines would be 3 hours × 2 = 6 a day. If forecasts were also billed per hour, one 120 h forecast would be 120 calls. **This is the most important thing to ask Ambee.**

## Per user per day (assumption A, 2 Frequent places)

| Day | Pre-cache | Moments (history + new places + trips) | Baselines | Fire | **Total** |
|-----|-----------|-----------------------------------------|-----------|------|-----------|
| (a) Quiet: 0–1 uses, maybe 1 new place | 8 | 2 + 2 = 4 | 4 | 0 | **16** |
| (b) Bad day as drawn: 3 uses, 1 new place, 1 trip | 8 | 6 + 2 + 2 = 10 | 4 | 0 (1–2 on a smoke day) | **22** (24 if smoky) |
| (c) Heavy testing: 10 test logs across 3–4 places, forecasts reopened about 4 times | 8 | 20 + 6 + 8 = 34 | 8 | 2 | **52 (call it 55)** |

With 1 Frequent place: 14 / 20 / 50. The phone's own cache may trim heavy testing (reopened forecasts, repeat logs at the same place in the same hour) to about 40. We count it at 55 to stay on the safe side.

Loading the bundled data sets makes no Ambee calls: they're made-up, and backfill skips them. But loading **"My data"** back resets the backfill (`DataSets.load` → `BaselineFiller.reset`), so the 60-day pull below runs again for that phone.

## 10-user POC

| Scenario | Per day | Per 30 days |
|----------|---------|-------------|
| Everyone quiet | 160 | 4,800 |
| Everyone on a bad day | 220 (240 if smoky) | 6,600 |
| Everyone testing heavily | 520–550 | about 16,000 |

The offer is 100/day. That doesn't cover even a quiet day for 10 people (160).

**One-off backfill when someone joins** (up to 60 days, Home + Work + Frequent places, 2 datasets). A brand-new user has no past moments, so backfill grows a day at a time and is already counted under Baselines. The one-off case is someone bringing data in, or a reset.
- A day per call: 60 × 2 datasets × 3–4 places = **360–480 per user**. For 10 users: **3,600–4,800**.
- A range per call: **1 per place per dataset**, so 6–8 per user and 60–80 for 10. (If Ambee caps a range at 30 days: 12–16 per user.)

**Ask:** **600 calls/day** (or an **18,000/month pool**) for 60–90 days. Add a one-off **5,000** for backfills, and bursts up to about 100 an hour, since a backfill runs 7 days at a time on one phone.

## A possible larger study (around 100 people, next semester; not defined yet)

Mixed realistic average per user: 70% quiet (16), 25% bad (22), 5% heavy (55) ≈ **20 a day**, plus 1–2 fire calls per person on smoke-like days.

**The plan is the same no-server setup, with each phone calling directly:**

| Scenario, 100 users | Per day | Per month (30 d) | Per 4 months (120 d) |
|---------------------|---------|-------------------|----------------------|
| Everyone quiet | 1,600 | 48,000 | 192,000 |
| Everyone on a bad day | 2,200 | 66,000 | 264,000 |
| Mixed average | **2,000** | **60,000** | **240,000** |
| Onboarding backfills, once | a day per call: 36,000–48,000 · a range per call: 600–800 | | |

**Possible later saving: a server with a shared cache.** This needs Ambee's OK to cache their data and share it between users. Pandji's OK is also needed, since the phone would send its area's center off the device. AQ and pollen are regional. If participants cluster in one town and the server caches by about a 2–5 km cell and the hour, everyone in a cell shares each call: forecasts, history, and baselines. That could be **about 70–80% less: around 400–600 a day** instead of 2,000. Backfills would then count per cell, not per person. This is a later option, not the plan.

## Draft email

> Hi [name],
>
> Thank you for the POC offer. It's really helpful.
>
> felt air is an on-device asthma diary for people who use a rescue inhaler. Each puff is logged with the outdoor air at that moment, and the app compares inhaler moments with ordinary "baseline" hours to learn which conditions show up more often on someone's inhaler days. We already use Apple WeatherKit for weather. **Pollen and air quality are what we'd like from Ambee.** For the POC, each tester's phone would call your API directly and cache results by place and hour.
>
> **What we'd like from Ambee:**
> - **Pollen** (tree, grass, weed, with species where available): latest, history and 5-day forecast.
> - **Air quality**: latest, history and 5-day forecast.
> - **Fire**: active fires near a place, called only when the air at a moment looks smoke-like (high PM2.5), so we can say "there are active wildfires 50 miles north" instead of just "smoky".
> - **Natural disasters**: events near a person's Home and Work (storms, floods, dust storms), checked with the morning pre-load only when the weather forecast shows a severe condition, so it's also occasional.
>
> How we'd use the API: each morning the app pre-loads the 5-day AQ and pollen forecast for a person's Home, Work and one or two places they visit often. We only make a call when someone stays somewhere new for more than 5 minutes, so no lookups while walking or driving through. Each inhaler moment, and about three baseline hours a day, gets that hour's AQ and pollen from history. The 5-day forecast is also used when someone checks an upcoming trip. Fire and natural-disaster calls are conditional, as above.
>
> That works out to about **16 calls per person per day on a quiet day, about 22 on a bad asthma day, and up to about 55 while we're testing heavily** (assuming one history or forecast request counts as one call). For 10 testers that's about 160–550 a day, so 100/day would be used up by mid-morning. Could we have **600 calls/day (or an 18,000/month pool) for 60–90 days, plus about 5,000 one-off calls** for loading each tester's past days?
>
> Looking ahead, we may run a larger study, around 100 people, next semester. By the same estimate that's about 2,000 calls a day. We'd likely add a server for that, so it would help to know whether caching your data on our side would be allowed. What would pricing look like at that scale, and is there a research or academic rate?
>
> A few questions that decide whether this works:
> 1. Is the allowance per key (shared across users) or per user?
> 2. Does one history or forecast request count as one call, or one per hour or day returned?
> 3. Is historical pollen and AQ included, and how far back (we'd like 60 days)?
> 4. Are there burst or per-minute limits? What happens on overage: a block, throttling, or a charge?
> 5. Can the POC run for 60–90 days? Patterns take a few weeks of logs.
> 6. Are the fire and natural-disaster endpoints included in the POC, and do they count against the same allowance?
> 7. What's the pricing path after the POC for about 100 and about 1,000 users?
> 8. For a later study, may we cache results on our own server and share them between users in the same area?
>
> Thanks again. Happy to get on a call.
> Pandji
