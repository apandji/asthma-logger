# Ambee POC: call estimate and reply

Ambee's offer (Oct 2026): *up to 10 users, 100 API calls per day across Pollen, Air Quality and Weather.*

This estimate uses Pandji's "Day in a Life (Bad Asthma Day, 3 inhaler uses)" model. **AQ and pollen come from Ambee; weather stays on WeatherKit** and isn't counted. Where we weren't sure, we rounded up, because testing will be heavy.

## The model

| When | Ambee calls | Kind |
|------|-------------|------|
| 7 am, every day | Forecast AQ + pollen for **Home** and **Work** = **4** | forecast (up to 120 h / 5 days per request) |
| Each new place you stay at **more than 5 minutes** | Forecast AQ + pollen there = **2** | forecast |
| Each inhaler moment | Historical AQ + pollen at that place = **2** (the hour, plus the 48 h look-back if a range is one call) | history |
| Checking a trip (e.g. Denver next week) | Forecast AQ + pollen = **2** (Ambee covers 5 days; WeatherKit covers 10) | forecast |
| Baseline moments (about 3 ordinary hours a day, filled in a day later at a visited place or Home; `BaselineBackfill`, `BaselineFiller`) | 1 day of history per place per dataset: Home + Work = **4** (6 if a third place) | history |
| Fire / natural disaster (optional) | **1–2** a day (Home, maybe Work) | current |

Pandji's bad day as drawn: 4 pre-cache + 5 conditional × 2 = **14**, plus 4 baselines and 1 fire = **19**.

A place becomes Frequent after more than 12 hours there, or more than 2 visits a week for at least 2 weeks. After that it joins the 7 am pre-cache, which adds 2 a day per Frequent place.

### Two assumptions about history

- **A (used below): one history request = one call**, whether it returns a day or a range. A moment's 48 h look-back is then one call per dataset.
- **B: billed per hour returned.** A day becomes 24 calls, and a moment with a 48 h look-back becomes 48 per dataset (about 96 per moment). That doesn't work. We would have to request only the moment's hour (2 calls) and drop the AQ/pollen look-back (OpenAQ already gives PM2.5 and ozone look-back). Baselines would be 3 hours × 2 = 6 a day. If forecasts were also billed per hour, one 120 h forecast would be 120 calls. **This is the most important thing to ask Ambee.**

## Per user per day (assumption A)

| Day | Pre-cache | Moments (history + new places + trips) | Baselines | Fire | **Total** |
|-----|-----------|-----------------------------------------|-----------|------|-----------|
| (a) Quiet: 0–1 uses, maybe 1 new place | 4 | 2 + 2 = 4 | 4 | 1 | **13** |
| (b) Bad day as drawn: 3 uses, 1 new place, 1 trip | 4 | 6 + 2 + 2 = 10 | 4 | 1 | **19** |
| (c) Heavy testing: 10 test logs across 3–4 places, forecasts reopened about 4 times | 4 | 20 + 6 + 8 = 34 | 8 | 2 | **48 (call it 50)** |

Loading the bundled data sets makes no Ambee calls: they're made-up, and backfill skips them. But loading **"My data"** back resets the backfill (`DataSets.load` → `BaselineFiller.reset`), so the 60-day pull below runs again unless the proxy caches it.

## 10-user POC

| Scenario | Per day | Per 30 days |
|----------|---------|-------------|
| Everyone quiet | 130 | 3,900 |
| Everyone on a bad day | 190 | 5,700 |
| Everyone testing heavily | 480 | 14,400 |

The offer is 100/day. That doesn't cover even a quiet day for 10 people (130).

**One-off backfill when someone joins** (up to 60 days, Home + Work, 2 datasets). A brand-new user has no past moments, so backfill grows a day at a time and is already counted under Baselines. The one-off case is someone bringing data in, or a reset.
- A day per call: 60 × 2 places × 2 datasets = **240 per user** (360 with a third place). For 10 users: **2,400–3,600**.
- A range per call: **1 per place per dataset**, so 4–6 per user and 40–60 for 10. (If Ambee caps a range at 30 days: 8–12 per user.)

**Ask:** **500 calls/day** (or a **15,000/month pool**) for 60–90 days. Add a one-off **3,600** for backfills, and bursts up to about 100 an hour, since a backfill runs 7 days at a time.

## The 100-person study (next semester, about 4 months / 120 days)

Mixed realistic average per user: 70% quiet (13), 25% bad (19), 5% heavy (48) ≈ **16 a day**.

| Scenario, 100 users | Per day | Per month (30 d) | Per semester (120 d) |
|---------------------|---------|-------------------|----------------------|
| Everyone quiet | 1,300 | 39,000 | 156,000 |
| Everyone on a bad day | 1,900 | 57,000 | 228,000 |
| Mixed average | **1,600** | **48,000** | **195,000** |
| Onboarding backfills, once | a day per call: 24,000–36,000 · a range per call: 400–600 | | |

### What a shared proxy cache saves in one town

AQ and pollen are regional: a monitor or a pollen grid cell covers kilometers, not a street. If the proxy keys its cache by about a 2–5 km cell and the hour, everyone in the same cell shares each call. Assume a university town is about 10 cells:
- Forecasts: 10 cells × 2 datasets × a refresh every 3 h (about 6 a day) = about 120.
- History (moments and baselines): about 1 day-pull per cell per dataset (20), plus deduped same-day moment pulls (roughly 100–200).
- Trips and places out of town: about 50–100.

That's **about 300–450 a day instead of about 1,600 (70–80% less)**, or about 10,000–14,000 a month. Backfill becomes per cell, not per person: 10 × 2 × 60 = 1,200 (a day per call) or 20 (a range per call). This needs Ambee to allow us to **store and share their data on our server**, which is a question for them. On the privacy side: the phone sends only the cell center, never the precise point. AGENTS.md says to ask before sending user data off the device, so that's a decision for the owner.

## Draft email

> Hi [name],
>
> Thank you for the POC offer. It's really helpful.
>
> felt air is an on-device asthma diary for people who use a rescue inhaler. Each puff is logged with the outdoor air at that moment, and the app compares inhaler moments with ordinary "baseline" hours to learn which conditions show up more often on someone's inhaler days. We already use Apple WeatherKit for weather. **Pollen and air quality are what we'd like from Ambee.**
>
> How we'd use the API: each morning we pre-load the 5-day AQ and pollen forecast for a person's Home and Work. We only make a call when someone stays somewhere new for more than 5 minutes, so no lookups while walking or driving through. Each inhaler moment, and about three baseline hours a day, gets that hour's AQ and pollen from history. The 5-day forecast is also used when someone checks an upcoming trip.
>
> That works out to about **13 calls per user per day on a quiet day, about 19 on a bad asthma day, and up to about 50 while we're testing heavily** (assuming a history or forecast request counts as one call). For 10 testers that's about 130–500 a day, so 100/day would be used up by mid-morning. Could we have **500 calls/day (or a 15,000/month pool) for 60–90 days, plus about 3,600 one-off calls** for loading each tester's past days? On our side we'll route every call through one server, so the key isn't in the app. It will cache per area and hour, enforce a hard daily cap, and fall back gracefully, so the app never fails without your data.
>
> We see this POC as the first step toward a **~100-person study next semester (about 4 months)**. Our estimate is about 1,600 calls a day without caching, and about 300–450 a day if participants are in one town and share the cache. Could you share pricing, or a research/academic rate, for that study?
>
> A few questions that decide whether this works:
> 1. Is the allowance per key (shared across users) or per user?
> 2. Does one history or forecast request count as one call, or one per hour or day returned?
> 3. Is historical pollen and AQ included, and how far back (we'd like 60 days)?
> 4. Are there burst or per-minute limits? What happens on overage: a block, throttling, or a charge?
> 5. Can the POC run for 60–90 days? Patterns take a few weeks of logs.
> 6. Is it OK to call through our own server and cache results by area and hour, shared between users?
> 7. Does the fire / natural-disaster API count against the same allowance?
> 8. What's the pricing path after the POC for about 100 and about 1,000 users?
>
> Thanks again. Happy to get on a call.
> Pandji

## Questions for Pandji before sending

1. Should the proxy be built for the POC? The email commits to it, and it's the main way to reduce calls. Sending cell centers off the phone needs your OK.
2. Should Frequent places join the 7 am pre-cache? Each one adds 2 a day per user.
3. Is the fire API under the same contract and key as this POC?
4. Is the study in one town, and roughly when does it start?
5. Are you comfortable showing per-user call counts to Ambee? They're only in this email, never on screen.
