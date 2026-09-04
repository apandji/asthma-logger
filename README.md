# Asthma trigger log

## Deploy (Vercel + Supabase) — do these in order

### Step 1: Create the database table (one time)

1. [supabase.com/dashboard](https://supabase.com/dashboard) → your project
2. **SQL Editor** → **New query**
3. Paste everything from `prisma/supabase-init.sql` → **Run**

### Step 2: Add env var on Vercel

1. Supabase → **Project Settings** → **Database** → **Connection string** → **URI**
2. Use **Transaction pooler** (port 6543)
3. Replace `[YOUR-PASSWORD]` with your real password
4. Add `?pgbouncer=true` at the end if it's not already there

Example:
```
postgresql://postgres.xxxxx:YOUR_PASSWORD@aws-0-us-west-1.pooler.supabase.com:6543/postgres?pgbouncer=true
```

5. Vercel → your project → **Settings** → **Environment Variables**
6. Name: `DATABASE_URL` → paste that string → Production + Preview → Save

### Optional: nearest air monitors (OpenAQ)

Free key from [OpenAQ Explorer](https://explore.openaq.org/register). Docs: https://docs.openaq.org

1. Create an account → copy the API key from settings
2. Vercel → **Settings** → **Environment Variables**
3. Add `OPENAQ_API_KEY` = your key → Redeploy

New logs show **nearest PM2.5 and nearest ozone** within ~16 mi (25 km search radius), with station name and distance in miles. That is a ground reading at that site — not the air at the pin, and not official NowCast AQI. If the key is missing, we fall back to AirNow’s 25-mile max AQI.

### Optional: AQI fallback (AirNow)

Free key from EPA AirNow: https://docs.airnowapi.org/account/request/

1. Request an API key (usually emailed within a day)
2. Vercel → **Settings** → **Environment Variables**
3. Add `AIRNOW_API_KEY` = your key → Redeploy

Used only when OpenAQ is unset or finds no fresh station. Old logs keep whatever was stored at sync time.

### Optional: Ambee (pollen, PM2.5/ozone, humidity, nearby fire)

If you have a trial key from [Ambee](https://docs.ambeedata.com):

1. Existing database: run `prisma/supabase-add-env-snapshot.sql` in the Supabase SQL Editor (adds `envSnapshotJson`).
2. Vercel → **Settings** → **Environment Variables** → `AMBEE_API_KEY` → Redeploy.
3. New logs call Ambee once (4 endpoints: AQ, pollen, weather, fire). Missing key is fine — NWS/AirNow/FIRMS still run.
4. Hover/tap badges: they say **outdoor modeled**, not indoor air.

See `docs/ambee-trigger-datasets.md` for what we use vs skip.

### What env data you get without any extra keys

| Source | Data |
|--------|------|
| NWS (free, no key) | Temperature, heat/cold/storm alerts, wildfire alerts via NWS |
| OpenAQ (needs key) | Nearest PM2.5 + ozone station within ~16 mi (name + mi) |
| AirNow (needs key) | Official US AQI + category — fallback if OpenAQ is missing |
| NASA FIRMS (optional key) | Satellite wildfire hotspots |
| Ambee (optional trial key) | Pollen risk, PM2.5/O₃, humidity, nearest fire mi |


```bash
cp .env.example .env
# set DATABASE_URL to the same Supabase URI
npm install
npm run dev
```

Use `http://localhost:3000/?demo=1` for Denver demo coords without GPS.
