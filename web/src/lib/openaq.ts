/**
 * OpenAQ v3 — nearest ground stations for PM2.5 and ozone.
 * Fail-open: unset OPENAQ_API_KEY skips the fetch.
 * Docs: https://docs.openaq.org
 *
 * Values are hourly concentrations at a named monitor, not official NowCast AQI
 * and not the air at the GPS pin.
 */

import type { EnvAirStation } from "./types";

const OPENAQ_BASE = "https://api.openaq.org/v3";
const RADIUS_M = 25_000;
const MAX_READING_AGE_MS = 36 * 60 * 60 * 1000;

export function isOpenAqConfigured(): boolean {
  return Boolean(process.env.OPENAQ_API_KEY?.trim());
}

export type OpenAqReading = {
  configured: boolean;
  pm25: number | null;
  ozonePpb: number | null;
  aqi: number | null;
  aqiCategory: string | null;
  aqiPollutant: string | null;
  pm25Station: EnvAirStation | null;
  ozoneStation: EnvAirStation | null;
  error: string | null;
  raw: unknown;
};

type OpenAqParameter = {
  id?: number;
  name?: string;
  units?: string;
  displayName?: string;
};

type OpenAqSensor = {
  id?: number;
  name?: string;
  parameter?: OpenAqParameter;
};

type OpenAqLocation = {
  id?: number;
  name?: string | null;
  isMobile?: boolean;
  isMonitor?: boolean;
  provider?: { id?: number; name?: string };
  sensors?: OpenAqSensor[];
  coordinates?: { latitude?: number | null; longitude?: number | null };
  distance?: number | null;
  datetimeLast?: { utc?: string; local?: string } | null;
};

type OpenAqLatest = {
  datetime?: { utc?: string; local?: string };
  value?: number;
  sensorsId?: number;
  locationsId?: number;
};

const EMPTY: OpenAqReading = {
  configured: false,
  pm25: null,
  ozonePpb: null,
  aqi: null,
  aqiCategory: null,
  aqiPollutant: null,
  pm25Station: null,
  ozoneStation: null,
  error: null,
  raw: null,
};

type Breakpoint = { cLo: number; cHi: number; iLo: number; iHi: number };

/** EPA 24h PM2.5 breakpoints (µg/m³). Used only to color / compare — not NowCast. */
const PM25_BPS: Breakpoint[] = [
  { cLo: 0.0, cHi: 12.0, iLo: 0, iHi: 50 },
  { cLo: 12.1, cHi: 35.4, iLo: 51, iHi: 100 },
  { cLo: 35.5, cHi: 55.4, iLo: 101, iHi: 150 },
  { cLo: 55.5, cHi: 150.4, iLo: 151, iHi: 200 },
  { cLo: 150.5, cHi: 250.4, iLo: 201, iHi: 300 },
  { cLo: 250.5, cHi: 350.4, iLo: 301, iHi: 400 },
  { cLo: 350.5, cHi: 500.4, iLo: 401, iHi: 500 },
];

/** EPA 8h ozone breakpoints (ppm). Latest OpenAQ value is usually hourly. */
const O3_8HR_BPS: Breakpoint[] = [
  { cLo: 0, cHi: 0.054, iLo: 0, iHi: 50 },
  { cLo: 0.055, cHi: 0.07, iLo: 51, iHi: 100 },
  { cLo: 0.071, cHi: 0.085, iLo: 101, iHi: 150 },
  { cLo: 0.086, cHi: 0.105, iLo: 151, iHi: 200 },
  { cLo: 0.106, cHi: 0.2, iLo: 201, iHi: 300 },
];

export function aqiFromBreakpoints(c: number, bps: Breakpoint[]): number | null {
  if (!Number.isFinite(c) || c < 0) return null;
  const bp = bps.find((b) => c >= b.cLo && c <= b.cHi);
  if (!bp) {
    if (c > bps[bps.length - 1].cHi) return 500;
    return null;
  }
  return Math.round(((bp.iHi - bp.iLo) / (bp.cHi - bp.cLo)) * (c - bp.cLo) + bp.iLo);
}

export function pm25ToAqi(ug: number): number | null {
  return aqiFromBreakpoints(ug, PM25_BPS);
}

export function ozonePpmToAqi(ppm: number): number | null {
  return aqiFromBreakpoints(ppm, O3_8HR_BPS);
}

export function aqiCategoryName(aqi: number | null): string | null {
  if (aqi == null) return null;
  if (aqi <= 50) return "Good";
  if (aqi <= 100) return "Moderate";
  if (aqi <= 150) return "Unhealthy for Sensitive Groups";
  if (aqi <= 200) return "Unhealthy";
  if (aqi <= 300) return "Very Unhealthy";
  return "Hazardous";
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const r = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.asin(Math.min(1, Math.sqrt(a)));
}

function paramName(sensor: OpenAqSensor): string {
  return (sensor.parameter?.name ?? sensor.name ?? "").toLowerCase().replace(/\s+/g, "");
}

export function sensorMeasuresPm25(sensor: OpenAqSensor): boolean {
  const name = paramName(sensor);
  return name.includes("pm25") || name.includes("pm2.5") || sensor.parameter?.id === 2;
}

export function sensorMeasuresOzone(sensor: OpenAqSensor): boolean {
  const name = paramName(sensor);
  return name === "o3" || name.includes("ozone") || sensor.parameter?.id === 10;
}

function locationKm(loc: OpenAqLocation, lat: number, lon: number): number | null {
  const la = loc.coordinates?.latitude;
  const lo = loc.coordinates?.longitude;
  if (la != null && lo != null && Number.isFinite(la) && Number.isFinite(lo)) {
    return haversineKm(lat, lon, la, lo);
  }
  if (loc.distance != null && Number.isFinite(loc.distance)) {
    // OpenAQ v3 point+radius `distance` is meters (radius max 25 km).
    return loc.distance / 1000;
  }
  return null;
}

function isFresh(iso: string | undefined, nowMs: number): boolean {
  if (!iso) return true;
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return true;
  return nowMs - t <= MAX_READING_AGE_MS;
}

function locationHas(loc: OpenAqLocation, pred: (s: OpenAqSensor) => boolean): boolean {
  return (loc.sensors ?? []).some(pred);
}

export function pickNearestLocation(
  locations: OpenAqLocation[],
  lat: number,
  lon: number,
  pred: (s: OpenAqSensor) => boolean,
  nowMs = Date.now(),
): OpenAqLocation | null {
  const ranked = locations
    .filter((loc) => loc.id != null && !loc.isMobile && locationHas(loc, pred))
    .filter((loc) => isFresh(loc.datetimeLast?.utc, nowMs))
    .map((loc) => ({ loc, km: locationKm(loc, lat, lon) }))
    .filter((row): row is { loc: OpenAqLocation; km: number } => row.km != null)
    .sort((a, b) => {
      if (a.loc.isMonitor !== b.loc.isMonitor) return a.loc.isMonitor ? -1 : 1;
      return a.km - b.km;
    });
  return ranked[0]?.loc ?? null;
}

function ozoneToPpb(value: number, units: string | undefined): number {
  const u = (units ?? "").toLowerCase();
  if (u.includes("ppm")) return value * 1000;
  return value;
}

function pm25ToUg(value: number, units: string | undefined): number {
  const u = (units ?? "").toLowerCase();
  if (u.includes("ppm")) return value * 1000;
  return value;
}

function stationFrom(loc: OpenAqLocation, lat: number, lon: number, asOf: string | null): EnvAirStation {
  return {
    name: loc.name?.trim() || loc.provider?.name || null,
    km: locationKm(loc, lat, lon),
    asOf,
    isMonitor: loc.isMonitor ?? null,
    provider: loc.provider?.name ?? null,
  };
}

async function openaqGet<T>(path: string, params?: Record<string, string>): Promise<T> {
  const key = process.env.OPENAQ_API_KEY!.trim();
  const url = new URL(`${OPENAQ_BASE}${path}`);
  if (params) {
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  }
  const res = await fetch(url.toString(), {
    headers: { "X-API-Key": key, Accept: "application/json" },
    next: { revalidate: 0 },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`OpenAQ ${res.status}: ${body.slice(0, 160)}`);
  }
  return res.json() as Promise<T>;
}

async function searchLocations(lat: number, lon: number, monitor: boolean | null): Promise<OpenAqLocation[]> {
  const params: Record<string, string> = {
    coordinates: `${lat.toFixed(4)},${lon.toFixed(4)}`,
    radius: String(RADIUS_M),
    limit: "100",
    mobile: "false",
  };
  if (monitor != null) params.monitor = String(monitor);
  const data = await openaqGet<{ results?: OpenAqLocation[] }>("/locations", params);
  return data.results ?? [];
}

function matchLatest(
  loc: OpenAqLocation,
  latest: OpenAqLatest[],
  pred: (s: OpenAqSensor) => boolean,
): { value: number; units: string | undefined; asOf: string | null; sensor: OpenAqSensor } | null {
  const sensors = (loc.sensors ?? []).filter(pred);
  for (const sensor of sensors) {
    if (sensor.id == null) continue;
    const row = latest.find((r) => r.sensorsId === sensor.id);
    if (row?.value == null || !Number.isFinite(row.value) || row.value < 0) continue;
    const asOf = row.datetime?.utc ?? row.datetime?.local ?? null;
    if (asOf && !isFresh(asOf, Date.now())) continue;
    return { value: row.value, units: sensor.parameter?.units, asOf, sensor };
  }
  return null;
}

export async function fetchOpenAq(lat: number, lon: number): Promise<OpenAqReading> {
  if (!isOpenAqConfigured()) return { ...EMPTY, configured: false };

  try {
    let locations = await searchLocations(lat, lon, true);
    const hasPm = locations.some((l) => locationHas(l, sensorMeasuresPm25));
    const hasO3 = locations.some((l) => locationHas(l, sensorMeasuresOzone));
    if (!hasPm || !hasO3) {
      const extra = await searchLocations(lat, lon, false);
      const seen = new Set(locations.map((l) => l.id));
      for (const loc of extra) {
        if (loc.id != null && !seen.has(loc.id)) locations.push(loc);
      }
    }

    const pmLoc = pickNearestLocation(locations, lat, lon, sensorMeasuresPm25);
    const o3Loc = pickNearestLocation(locations, lat, lon, sensorMeasuresOzone);
    const uniqueIds = [...new Set([pmLoc?.id, o3Loc?.id].filter((id): id is number => id != null))];

    const latestById = new Map<number, OpenAqLatest[]>();
    await Promise.all(
      uniqueIds.map(async (id) => {
        const data = await openaqGet<{ results?: OpenAqLatest[] }>(`/locations/${id}/latest`);
        latestById.set(id, data.results ?? []);
      }),
    );

    let pm25: number | null = null;
    let ozonePpb: number | null = null;
    let pm25Station: EnvAirStation | null = null;
    let ozoneStation: EnvAirStation | null = null;

    if (pmLoc?.id != null) {
      const hit = matchLatest(pmLoc, latestById.get(pmLoc.id) ?? [], sensorMeasuresPm25);
      if (hit) {
        pm25 = pm25ToUg(hit.value, hit.units);
        pm25Station = stationFrom(pmLoc, lat, lon, hit.asOf);
      }
    }
    if (o3Loc?.id != null) {
      const hit = matchLatest(o3Loc, latestById.get(o3Loc.id) ?? [], sensorMeasuresOzone);
      if (hit) {
        ozonePpb = ozoneToPpb(hit.value, hit.units);
        ozoneStation = stationFrom(o3Loc, lat, lon, hit.asOf);
      }
    }

    const pmAqi = pm25 != null ? pm25ToAqi(pm25) : null;
    const o3Aqi = ozonePpb != null ? ozonePpmToAqi(ozonePpb / 1000) : null;
    let aqi: number | null = null;
    let aqiPollutant: string | null = null;
    if (pmAqi != null && (o3Aqi == null || pmAqi >= o3Aqi)) {
      aqi = pmAqi;
      aqiPollutant = "PM2.5";
    } else if (o3Aqi != null) {
      aqi = o3Aqi;
      aqiPollutant = "O3";
    }

    return {
      configured: true,
      pm25,
      ozonePpb,
      aqi,
      aqiCategory: aqiCategoryName(aqi),
      aqiPollutant,
      pm25Station,
      ozoneStation,
      error: null,
      raw: {
        locationIds: uniqueIds,
        pmLocation: pmLoc?.name ?? null,
        ozoneLocation: o3Loc?.name ?? null,
        count: locations.length,
      },
    };
  } catch (err) {
    return {
      ...EMPTY,
      configured: true,
      error: err instanceof Error ? err.message : "OpenAQ fetch failed",
    };
  }
}
