# Asthma trigger log

Prototype: tap when you use your inhaler → save lat/long + time locally → sync environmental context when online.

## Local dev

```bash
cp .env.example .env   # set DATABASE_URL to a Neon Postgres URL
npm install
npx prisma db push
npm run dev
```

Use `http://localhost:3000/?demo=1` for Denver demo coords without GPS.

## Deploy to Vercel

1. Push to GitHub
2. Create Postgres at [neon.tech](https://neon.tech)
3. Import repo on [vercel.com/new](https://vercel.com/new)
4. Set `DATABASE_URL` env var

Build runs `prisma db push` to create tables on first deploy.
