import { z } from "zod";
import { prisma } from "@/lib/db";
import { enrichEnvironment } from "@/lib/env-data";
import type { AttackLogDTO, EnvStatus } from "@/lib/types";
import type { AttackLog } from "@prisma/client";

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
