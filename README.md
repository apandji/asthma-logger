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

### Step 3: Redeploy

Vercel → **Deployments** → **⋯** → **Redeploy**

---

## Local dev

```bash
cp .env.example .env
# set DATABASE_URL to the same Supabase URI
npm install
npm run dev
```

Use `http://localhost:3000/?demo=1` for Denver demo coords without GPS.
