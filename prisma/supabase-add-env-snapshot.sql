-- Run once on an existing AttackLog table (SQL Editor → New query → Run)
ALTER TABLE "AttackLog" ADD COLUMN IF NOT EXISTS "envSnapshotJson" TEXT;
