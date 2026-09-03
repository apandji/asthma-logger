/**
 * Ambee trial client — pollen, per-pollutant AQ, weather, nearby fires.
 * Fail-open: callers catch. Does not throw when AMBEE_API_KEY is unset.
 * Docs: https://docs.ambeedata.com
 */

const AMBEE_BASE = "https://api.ambeedata.com";

export function isAmbeeConfigured(): boolean {
  return Boolean(process.env.AMBEE_API_KEY?.trim());
}

export type AmbeeAqReading = {
  pm25: number | null;
  pm10: number | null;
  ozonePpb: number | null;
  no2: number | null;
  aqi: number | null;
  aqiCategory: string | null;
  aqiPollutant: string | null;
  asOf: string | null;
  raw: unknown;
};

export type AmbeePollenReading = {
  treeRisk: string | null;
  grassRisk: string | null;
  weedRisk: string | null;
  treeCount: number | null;
  grassCount: number | null;
  weedCount: number | null;
  topSpecies: string | null;
  asOf: string | null;
  raw: unknown;
};

export type AmbeeWeatherReading = {
  temperatureF: number | null;
  humidityPct: number | null;
  dewpointF: number | null;
  apparentTemperatureF: number | null;
  windSpeed: number | null;
  asOf: string | null;
  raw: unknown;
};

export type AmbeeFireReading = {
  nearestKm: number | null;
  summary: string | null;
  count: number;
  raw: unknown;
};

export type AmbeeBundle = {
  configured: boolean;
  aq: AmbeeAqReading | null;
  pollen: AmbeePollenReading | null;
  weather: AmbeeWeatherReading | null;
  fire: AmbeeFireReading | null;
  errors: string[];
};

function ambeeKey(): string {
  return process.env.AMBEE_API_KEY?.trim() ?? "";
}

async function ambeeGet(path: string): Promise<unknown> {
  const res = await fetch(`${AMBEE_BASE}${path}`, {
    headers: {
      "x-api-key": ambeeKey(),
      "Content-type": "application/json",
    },
    cache: "no-store",
  });
  const text = await res.text();
  if (res.status === 206) {
    // Trial quota trim — still parse whatever arrived
  } else if (!res.ok) {
    throw new Error(`Ambee ${res.status} ${path}: ${text.slice(0, 160)}`);
  }
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new Error(`Ambee invalid JSON ${path}: ${text.slice(0, 80)}`);
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function firstRow(payload: unknown): Record<string, unknown> | null {
  const root = asRecord(payload);
  if (!root) return null;
  const list = root.data ?? root.stations;
  if (Array.isArray(list) && list.length > 0) return asRecord(list[0]);
  return null;
}

function num(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

function str(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
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

export function parseAmbeeAq(payload: unknown): AmbeeAqReading {
  const row = firstRow(payload);
  const info = asRecord(row?.aqiInfo);
  return {
    pm25: num(row?.PM25 ?? row?.PM2_5 ?? row?.pm25),
    pm10: num(row?.PM10 ?? row?.pm10),
    ozonePpb: num(row?.OZONE ?? row?.ozone),
    no2: num(row?.NO2 ?? row?.no2),
    aqi: num(row?.AQI ?? row?.aqi),
    aqiCategory: str(info?.category),
    aqiPollutant: str(info?.pollutant),
    asOf: str(row?.timestamp ?? row?.localTime ?? row?.updatedAt),
    raw: payload,
  };
}

function maxSpecies(species: unknown): string | null {
  const root = asRecord(species);
  if (!root) return null;
  let bestName: string | null = null;
  let best = 0;
  for (const group of Object.values(root)) {
    if (typeof group === "number") {
      if (group > best) {
        best = group;
        bestName = "Other";
      }
      continue;
    }
    const rec = asRecord(group);
    if (!rec) continue;
    for (const [name, count] of Object.entries(rec)) {
      const n = num(count) ?? 0;
      if (n > best) {
        best = n;
        bestName = name;
      }
    }
  }
  return bestName && best > 0 ? `${bestName} ${best}` : null;
}

export function parseAmbeePollen(payload: unknown): AmbeePollenReading {
  const row = firstRow(payload);
  const risk = asRecord(row?.Risk);
  const count = asRecord(row?.Count);
  return {
    treeRisk: str(risk?.tree_pollen),
    grassRisk: str(risk?.grass_pollen),
    weedRisk: str(risk?.weed_pollen),
    treeCount: num(count?.tree_pollen),
    grassCount: num(count?.grass_pollen),
    weedCount: num(count?.weed_pollen),
    topSpecies: maxSpecies(row?.Species),
    asOf: str(row?.timestamp),
    raw: payload,
  };
}

export function parseAmbeeWeather(payload: unknown): AmbeeWeatherReading {
  const row = firstRow(payload);
  return {
    temperatureF: num(row?.temperature),
    humidityPct: num(row?.humidity),
    dewpointF: num(row?.dewPoint ?? row?.dewpoint),
    apparentTemperatureF: num(row?.apparentTemperature),
    windSpeed: num(row?.windSpeed),
    asOf: str(row?.timestamp),
    raw: payload,
  };
}

export function parseAmbeeFire(payload: unknown, originLat: number, originLon: number): AmbeeFireReading {
  const root = asRecord(payload);
  const list = Array.isArray(root?.data) ? root.data : [];
  let nearestKm: number | null = null;
  let summary: string | null = null;
  let counted = 0;

  for (const item of list) {
    const rec = asRecord(item);
    if (!rec) continue;
    const lat = num(rec.lat);
    const lng = num(rec.lng ?? rec.lon);
    if (lat == null || lng == null) continue;
    counted += 1;
    const km = haversineKm(originLat, originLon, lat, lng);
    if (nearestKm == null || km < nearestKm) {
      nearestKm = km;
      const name = str(rec.fireName) ?? str(rec.fireType) ?? "fire";
      const frp = num(rec.frp);
      const conf = rec.confidence != null ? String(rec.confidence) : null;
      const parts = [`${name} ${km < 10 ? km.toFixed(1) : Math.round(km)} km`];
      if (frp != null) parts.push(`FRP ${Math.round(frp)}`);
      if (conf) parts.push(conf);
      summary = parts.join(" · ");
    }
  }

  return { nearestKm, summary, count: counted, raw: payload };
}

export async function fetchAmbeeBundle(lat: number, lon: number): Promise<AmbeeBundle> {
  if (!isAmbeeConfigured()) {
    return { configured: false, aq: null, pollen: null, weather: null, fire: null, errors: [] };
  }

  const q = `lat=${encodeURIComponent(String(lat))}&lng=${encodeURIComponent(String(lon))}`;
  const errors: string[] = [];

  const [aqRes, pollenRes, weatherRes, fireRes] = await Promise.allSettled([
    ambeeGet(`/latest/by-lat-lng?${q}`),
    ambeeGet(`/v3/pollen/latest?${q}`),
    ambeeGet(`/weather/latest/by-lat-lng?${q}`),
    ambeeGet(`/fire/latest/by-lat-lng?${q}`),
  ]);

  const take = <T,>(result: PromiseSettledResult<unknown>, parse: (body: unknown) => T, label: string): T | null => {
    if (result.status === "rejected") {
      errors.push(`${label}: ${result.reason instanceof Error ? result.reason.message : "failed"}`);
      return null;
    }
    try {
      return parse(result.value);
    } catch (err) {
      errors.push(`${label}: ${err instanceof Error ? err.message : "parse failed"}`);
      return null;
    }
  };

  return {
    configured: true,
    aq: take(aqRes, parseAmbeeAq, "aq"),
    pollen: take(pollenRes, parseAmbeePollen, "pollen"),
    weather: take(weatherRes, parseAmbeeWeather, "weather"),
    fire: take(fireRes, (body) => parseAmbeeFire(body, lat, lon), "fire"),
    errors,
  };
}
