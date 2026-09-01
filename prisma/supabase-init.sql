-- Run once in Supabase: SQL Editor → New query → paste → Run

CREATE TABLE IF NOT EXISTS "AttackLog" (
  "id" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "loggedAt" TIMESTAMP(3) NOT NULL,
  "latitude" DOUBLE PRECISION NOT NULL,
  "longitude" DOUBLE PRECISION NOT NULL,
  "feeling" TEXT,
  "envStatus" TEXT NOT NULL DEFAULT 'pending',
  "envFetchedAt" TIMESTAMP(3),
  "envError" TEXT,
  "aqi" INTEGER,
  "aqiCategory" TEXT,
  "temperatureF" DOUBLE PRECISION,
  "isExtremeTemp" BOOLEAN NOT NULL DEFAULT false,
  "hasStormAlert" BOOLEAN NOT NULL DEFAULT false,
  "stormSummary" TEXT,
  "hasWildfireNearby" BOOLEAN NOT NULL DEFAULT false,
  "wildfireSummary" TEXT,
  "possibleInversion" BOOLEAN NOT NULL DEFAULT false,
  "inversionNote" TEXT,
  "envRawJson" TEXT,
  "deviceId" TEXT,
  CONSTRAINT "AttackLog_pkey" PRIMARY KEY ("id")
);
