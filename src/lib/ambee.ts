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
  nearestLat: number | null;
  nearestLng: number | null;
  summary: string | null;
  count: number;
  raw: unknown;
};

export type AmbeeDisasterType = "SW" | "ET" | "WF" | "TC" | "VO";

export type AmbeeDisasterEvent = {
  type: AmbeeDisasterType;
  name: string;
  km: number | null;
  place: string | null;
  eventId: string | null;
  lat: number | null;
  lng: number | null;
};

export type AmbeeDisasterReading = {
  events: AmbeeDisasterEvent[];
  raw: unknown;
};

export type AmbeeBundle = {
  configured: boolean;
  aq: AmbeeAqReading | null;
  pollen: AmbeePollenReading | null;
  weather: AmbeeWeatherReading | null;
  fire: AmbeeFireReading | null;
  disasters: AmbeeDisasterReading | null;
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
  // Weather latest sometimes returns `data` as a single object, not an array
  const obj = asRecord(list);
  if (obj) {
    const history = obj.history;
    if (Array.isArray(history) && history.length > 0) {
      return asRecord(history[history.length - 1]);
    }
    return obj;
  }
  return null;
}

function humidityPct(value: unknown): number | null {
  const n = num(value);
  if (n == null) return null;
  // Ambee sometimes returns 0–1 (0.81) and sometimes 0–100 (81)
  if (n >= 0 && n <= 1) return n * 100;
  return n;
}

function temperatureF(value: unknown): number | null {
  const n = num(value);
  if (n == null) return null;
  return n;
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
    temperatureF: temperatureF(row?.temperature ?? row?.temp ?? row?.Temperature),
    humidityPct: humidityPct(row?.humidity ?? row?.relativeHumidity ?? row?.Humidity),
    dewpointF: num(row?.dewPoint ?? row?.dewpoint ?? row?.dew_point),
    apparentTemperatureF: num(row?.apparentTemperature ?? row?.feelsLike ?? row?.apparent_temperature),
    windSpeed: num(row?.windSpeed ?? row?.wind_speed),
    asOf: str(row?.timestamp ?? row?.time ?? row?.updatedAt),
    raw: payload,
  };
}

export function parseAmbeeFire(payload: unknown, originLat: number, originLon: number): AmbeeFireReading {
  const root = asRecord(payload);
  const list = Array.isArray(root?.data) ? root.data : [];
  let nearestKm: number | null = null;
  let nearestLat: number | null = null;
  let nearestLng: number | null = null;
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
      nearestLat = lat;
      nearestLng = lng;
      const name = str(rec.fireName) ?? str(rec.fireType) ?? "fire";
      const frp = num(rec.frp);
      const conf = rec.confidence != null ? String(rec.confidence) : null;
      const parts = [`${name} ${km < 10 ? km.toFixed(1) : Math.round(km)} km`];
      if (frp != null) parts.push(`FRP ${Math.round(frp)}`);
      if (conf) parts.push(conf);
      summary = parts.join(" · ");
    }
  }

  return { nearestKm, nearestLat, nearestLng, summary, count: counted, raw: payload };
}

const BREATHING_DISASTER_TYPES = new Set<AmbeeDisasterType>(["SW", "ET", "WF", "TC", "VO"]);

const DISASTER_LABEL: Record<AmbeeDisasterType, string> = {
  SW: "Storm",
  ET: "Extreme temp",
  WF: "Wildfire",
  TC: "Cyclone",
  VO: "Volcano",
};

function continentFor(lat: number, lon: number): string {
  if (lat >= 7 && lon >= -170 && lon <= -20) return "NAR";
  if (lat < 12 && lon >= -90 && lon <= -30) return "SAR";
  if (lat >= 35 && lon >= -25 && lon <= 45) return "EUR";
  if (lat >= -35 && lat <= 37 && lon >= -20 && lon <= 52) return "AFR";
  if (lat >= -50 && lat <= -10 && lon >= 110 && lon <= 180) return "AUS";
  return "ASIA";
}

function disasterList(payload: unknown): unknown[] {
  const root = asRecord(payload);
  if (!root) return [];
  if (Array.isArray(root.result)) return root.result;
  if (Array.isArray(root.data)) return root.data;
  return [];
}

export function formatDisaster(event: Pick<AmbeeDisasterEvent, "type" | "km" | "place">): string {
  const kind = DISASTER_LABEL[event.type];
  const km =
    event.km == null ? null : event.km < 10 ? `${event.km.toFixed(1)} km` : `${Math.round(event.km)} km`;
  const parts = [kind];
  if (event.place) parts.push(event.place);
  if (km) parts.push(km);
  return parts.join(" · ");
}

/** "Extreme Heat Warning in Madison; St. Louis; Jefferson" → "St. Louis" when possible. */
export function placeFromEventName(name: string | null): string | null {
  if (!name) return null;
  const m = name.match(/\bin\s+(.+)$/i);
  if (!m) return null;
  const parts = m[1]
    .split(";")
    .map((s) => s.trim())
    .filter(Boolean);
  if (!parts.length) return null;
  const prefer = parts.find((p) => /st\.?\s*louis/i.test(p)) ?? parts.find((p) => /city/i.test(p));
  return prefer ?? parts[0];
}

export function parseAmbeeDisasters(
  payload: unknown,
  originLat: number,
  originLon: number,
): AmbeeDisasterReading {
  const events: AmbeeDisasterEvent[] = [];
  const seen = new Set<string>();

  for (const item of disasterList(payload)) {
    const rec = asRecord(item);
    if (!rec) continue;
    const rawType = (str(rec.event_type ?? rec.eventType) ?? "").toUpperCase();
    if (!BREATHING_DISASTER_TYPES.has(rawType as AmbeeDisasterType)) continue;
    const type = rawType as AmbeeDisasterType;
    const eventId = str(rec.event_id ?? rec.eventId);
    const key = eventId ?? `${type}:${rec.lat}:${rec.lng}:${rec.event_name}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const lat = num(rec.lat);
    const lng = num(rec.lng ?? rec.lon);
    const km = lat != null && lng != null ? haversineKm(originLat, originLon, lat, lng) : null;
    const name = str(rec.event_name ?? rec.eventName) ?? DISASTER_LABEL[type];
    const city = str(rec.city);
    const state = str(rec.state);
    const place =
      (city && state ? `${city}, ${state}` : city ?? state) ??
      placeFromEventName(name) ??
      str(rec.country_code ?? rec.countryCode);

    // Ambee tags some heat watches as SW; treat those as ET
    const typeFixed: AmbeeDisasterType =
      type === "SW" && /heat|cold|freeze|frost/i.test(name) ? "ET" : type;

    events.push({ type: typeFixed, name, km, place, eventId, lat, lng });
  }

  events.sort((a, b) => (a.km ?? 1e9) - (b.km ?? 1e9));
  return { events, raw: payload };
}

export function mergeDisasterReadings(parts: Array<AmbeeDisasterReading | null>): AmbeeDisasterReading {
  const events: AmbeeDisasterEvent[] = [];
  const seen = new Set<string>();
  for (const part of parts) {
    if (!part) continue;
    for (const event of part.events) {
      const key = event.eventId ?? `${event.type}:${event.name}:${event.km}`;
      if (seen.has(key)) continue;
      seen.add(key);
      events.push(event);
    }
  }
  events.sort((a, b) => (a.km ?? 1e9) - (b.km ?? 1e9));
  return { events, raw: parts.map((p) => p?.raw ?? null) };
}

export async function fetchAmbeeBundle(lat: number, lon: number): Promise<AmbeeBundle> {
  if (!isAmbeeConfigured()) {
    return { configured: false, aq: null, pollen: null, weather: null, fire: null, disasters: null, errors: [] };
  }

  const q = `lat=${encodeURIComponent(String(lat))}&lng=${encodeURIComponent(String(lon))}`;
  const continent = continentFor(lat, lon);
  const errors: string[] = [];

  const [aqRes, pollenRes, weatherRes, fireRes, localDisasters, regionDisasters] = await Promise.allSettled([
    ambeeGet(`/latest/by-lat-lng?${q}`),
    ambeeGet(`/v3/pollen/latest?${q}`),
    ambeeGet(`/weather/latest/by-lat-lng?${q}`),
    ambeeGet(`/fire/latest/by-lat-lng?${q}`),
    ambeeGet(`/disasters/latest/by-lat-lng?${q}&limit=25&page=1`),
    ambeeGet(`/disasters/latest/by-continent?continent=${encodeURIComponent(continent)}&limit=25&page=1`),
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

  const disasters = mergeDisasterReadings([
    take(localDisasters, (body) => parseAmbeeDisasters(body, lat, lon), "disasters-local"),
    take(regionDisasters, (body) => parseAmbeeDisasters(body, lat, lon), "disasters-region"),
  ]);

  return {
    configured: true,
    aq: take(aqRes, parseAmbeeAq, "aq"),
    pollen: take(pollenRes, parseAmbeePollen, "pollen"),
    weather: take(weatherRes, parseAmbeeWeather, "weather"),
    fire: take(fireRes, (body) => parseAmbeeFire(body, lat, lon), "fire"),
    disasters,
    errors,
  };
}
