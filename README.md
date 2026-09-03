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

### Optional: AQI (air quality index)

Free key from EPA AirNow: https://docs.airnowapi.org/account/request/

1. Request an API key (usually emailed within a day)
2. Vercel → **Settings** → **Environment Variables**
3. Add `AIRNOW_API_KEY` = your key → Redeploy

New logs will show AQI. Old logs keep whatever was stored at sync time.

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
| AirNow (needs key) | Official US AQI + category |
| NASA FIRMS (optional key) | Satellite wildfire hotspots |
| Ambee (optional trial key) | Pollen risk, PM2.5/O₃, humidity, nearest fire km |


```bash
cp .env.example .env
# set DATABASE_URL to the same Supabase URI
npm install
npm run dev
```

Use `http://localhost:3000/?demo=1` for Denver demo coords without GPS.
