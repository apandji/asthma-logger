import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { toDTO } from "@/lib/logs";
import { fetchHourlyHistory, OPEN_METEO_MAX_PAST_DAYS } from "@/lib/open-meteo";
import {
  attackFlags,
  derivePatterns,
  matchHour,
  type AttackSample,
  type HourSample,
} from "@/lib/patterns";

export const dynamic = "force-dynamic";

/** Group logs by ~0.1° (~7 mi) so one model series covers a neighbourhood. */
const PLACE_DECIMALS = 1;
/** Cap outbound calls per request (2 per place). */
const MAX_PLACES = 8;

function placeKey(lat: number, lon: number): string {
  return `${lat.toFixed(PLACE_DECIMALS)},${lon.toFixed(PLACE_DECIMALS)}`;
}

function safeTimeZone(tz: string | null): string {
  if (!tz) return "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return tz;
  } catch {
    return "UTC";
  }
}

function localHourFn(tz: string): (ms: number) => number {
  const fmt = new Intl.DateTimeFormat("en-US", { timeZone: tz, hour: "numeric", hour12: false });
  return (ms) => {
    const part = fmt.formatToParts(new Date(ms)).find((p) => p.type === "hour")?.value ?? "0";
    return Number(part) % 24;
  };
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const tz = safeTimeZone(url.searchParams.get("tz"));
  const toLocalHour = localHourFn(tz);

  const rows = await prisma.attackLog.findMany({ orderBy: { loggedAt: "desc" }, take: 200 });
  const logs = rows.map(toDTO);

  // Most-logged places first so the cap drops the rarest ones.
  const byPlace = new Map<string, { lat: number; lon: number; ids: string[] }>();
  for (const log of logs) {
    const key = placeKey(log.latitude, log.longitude);
    const p = byPlace.get(key) ?? { lat: 0, lon: 0, ids: [] };
    p.ids.push(log.id);
    p.lat += log.latitude;
    p.lon += log.longitude;
    byPlace.set(key, p);
  }
  const places = [...byPlace.values()]
    .sort((a, b) => b.ids.length - a.ids.length)
    .slice(0, MAX_PLACES)
    .map((p) => ({ ...p, lat: p.lat / p.ids.length, lon: p.lon / p.ids.length }));

  const series = await Promise.all(
    places.map((p) => fetchHourlyHistory(p.lat, p.lon, OPEN_METEO_MAX_PAST_DAYS)),
  );
  for (const s of series) for (const h of s) h.localHour = toLocalHour(h.t);

  const seriesByLogId = new Map<string, HourSample[]>();
  places.forEach((p, i) => {
    for (const id of p.ids) seriesByLogId.set(id, series[i]);
  });

  const attackHourTimes = new Set<number>();
  const attacks: AttackSample[] = logs.map((log) => {
    const hour = matchHour(seriesByLogId.get(log.id) ?? [], log.loggedAt);
    if (hour) attackHourTimes.add(hour.t);
    return { logId: log.id, loggedAt: log.loggedAt, hour, flags: attackFlags(log) };
  });

  const baseline: HourSample[] = [];
  for (const s of series) for (const h of s) if (!attackHourTimes.has(h.t)) baseline.push(h);

  const report = derivePatterns(attacks, baseline, { places: places.length });
  return NextResponse.json({ report, tz });
}
