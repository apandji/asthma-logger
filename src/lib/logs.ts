import { z } from "zod";
import { prisma } from "@/lib/db";
import { enrichEnvironment } from "@/lib/env-data";
import type { AttackLogDTO, EnvSnapshot, EnvSnapshotV1, EnvStatus } from "@/lib/types";
import type { AttackLog } from "@prisma/client";

function migrateV1(v1: EnvSnapshotV1): EnvSnapshot {
  return {
    v: 2,
    free: { ...EMPTY_SOURCES },
    ambee: {
      temperatureF: null,
      humidityPct: v1.humidityPct,
      dewpointF: v1.dewpointF,
      aqi: v1.aqiSource === "ambee" ? null : null,
      aqiCategory: null,
      aqiPollutant: v1.aqiPollutant,
      pm25: v1.pm25,
      ozonePpb: v1.ozonePpb,
      pollen: v1.pollen,
      wildfire: v1.nearestFireSummary,
      storms: null,
      extremeTempEvent: null,
      volcano: null,
      disasters: null,
    },
    aqiSource: v1.aqiSource,
    tempSource: v1.tempSource,
  };
}

const EMPTY_SOURCES = {
  temperatureF: null,
  humidityPct: null,
  dewpointF: null,
  aqi: null,
  aqiCategory: null,
  aqiPollutant: null,
  pm25: null,
  ozonePpb: null,
  pollen: null,
  wildfire: null,
  storms: null,
  extremeTempEvent: null,
  volcano: null,
  disasters: null,
} as const;

function parseSnapshot(raw: string | null | undefined): EnvSnapshot | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as EnvSnapshot | EnvSnapshotV1;
    if (parsed?.v === 2) return parsed;
    if (parsed?.v === 1) return migrateV1(parsed);
    return null;
  } catch {
    return null;
  }
}

const feelingSchema = z.enum(["ok", "mild", "bad"]).nullable();

export const createLogSchema = z.object({
  id: z.string().uuid(),
  loggedAt: z.string().datetime(),
  latitude: z.number().min(18).max(72),
  longitude: z.number().min(-180).max(-65),
  feeling: feelingSchema.optional().default(null),
  deviceId: z.string().max(128).optional().nullable(),
});

export function toDTO(row: AttackLog): AttackLogDTO {
  const snapshot = parseSnapshot(row.envSnapshotJson);
  return {
    id: row.id,
    loggedAt: row.loggedAt.toISOString(),
    latitude: row.latitude,
    longitude: row.longitude,
    feeling: row.feeling,
    envStatus: row.envStatus as EnvStatus,
    envFetchedAt: row.envFetchedAt?.toISOString() ?? null,
    envError: row.envError,
    aqi: row.aqi,
    aqiCategory: row.aqiCategory,
    temperatureF: row.temperatureF,
    isExtremeTemp: row.isExtremeTemp,
    hasStormAlert: row.hasStormAlert,
    stormSummary: row.stormSummary,
    hasWildfireNearby: row.hasWildfireNearby,
    wildfireSummary: row.wildfireSummary,
    possibleInversion: row.possibleInversion,
    inversionNote: row.inversionNote,
    snapshot,
    placeName: snapshot?.placeName ?? null,
  };
}

export async function upsertAndEnrich(input: z.infer<typeof createLogSchema>) {
  const existing = await prisma.attackLog.findUnique({ where: { id: input.id } });

  const base = {
    loggedAt: new Date(input.loggedAt),
    latitude: input.latitude,
    longitude: input.longitude,
    feeling: input.feeling ?? null,
    deviceId: input.deviceId ?? null,
  };

  if (existing?.envStatus === "ready") {
    const row = await prisma.attackLog.update({ where: { id: input.id }, data: base });
    return toDTO(row);
  }

  let row = existing
    ? await prisma.attackLog.update({ where: { id: input.id }, data: base })
    : await prisma.attackLog.create({ data: { id: input.id, ...base, envStatus: "pending" } });

  try {
    const env = await enrichEnvironment(input.latitude, input.longitude);
    row = await prisma.attackLog.update({
      where: { id: input.id },
      data: {
        envStatus: "ready",
        envFetchedAt: new Date(),
        envError: null,
        aqi: env.aqi,
        aqiCategory: env.aqiCategory,
        temperatureF: env.temperatureF,
        isExtremeTemp: env.isExtremeTemp,
        hasStormAlert: env.hasStormAlert,
        stormSummary: env.stormSummary,
        hasWildfireNearby: env.hasWildfireNearby,
        wildfireSummary: env.wildfireSummary,
        possibleInversion: env.possibleInversion,
        inversionNote: env.inversionNote,
        envRawJson: JSON.stringify(env.raw),
        envSnapshotJson: env.snapshot ? JSON.stringify(env.snapshot) : null,
      },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "enrichment failed";
    row = await prisma.attackLog.update({
      where: { id: input.id },
      data: { envStatus: "failed", envFetchedAt: new Date(), envError: message },
    });
  }

  return toDTO(row);
}
