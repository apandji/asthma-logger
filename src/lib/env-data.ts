import { fetchAmbeeBundle } from "./ambee";
import type { EnvEnrichment, EnvSnapshot, EnvSourceValues } from "./types";

const NWS_USER_AGENT =
  process.env.NWS_USER_AGENT ?? "(asthma-log-prototype, local-dev@example.com)";

const EXTREME_COLD_F = 20;
const EXTREME_HOT_F = 95;

type NwsPoint = {
  properties?: {
    forecast?: string;
    relativeLocation?: { properties?: { city?: string; state?: string } };
  };
};

type NwsPeriod = {
  temperature?: number;
  temperatureUnit?: string;
  windSpeed?: string;
  shortForecast?: string;
  detailedForecast?: string;
  isDaytime?: boolean;
};

type NwsAlert = {
  properties?: {
    event?: string;
    headline?: string;
    severity?: string;
  };
};

async function nwsFetch<T>(url: string): Promise<T> {
  const res = await fetch(url, {
    headers: {
      Accept: "application/geo+json",
      "User-Agent": NWS_USER_AGENT,
    },
    next: { revalidate: 0 },
  });
  if (!res.ok) throw new Error(`NWS ${res.status} for ${url}`);
  return res.json() as Promise<T>;
}

function toFahrenheit(temp: number, unit?: string): number {
  if (!unit || unit.toUpperCase() === "F") return temp;
  return (temp * 9) / 5 + 32;
}

function parseWindMph(windSpeed?: string): number | null {
  if (!windSpeed) return null;
  const nums = [...windSpeed.matchAll(/(\d+)/g)].map((m) => Number(m[1]));
  return nums.length ? Math.max(...nums) : null;
}

async function fetchAirNow(lat: number, lon: number) {
  const key = process.env.AIRNOW_API_KEY;
  if (!key) {
    return { aqi: null, aqiCategory: null, pm25: null, ozonePpb: null, raw: null as unknown };
  }

  const url = new URL("https://www.airnowapi.org/aq/observation/latLong/current/");
  url.searchParams.set("format", "application/json");
  url.searchParams.set("latitude", String(lat));
  url.searchParams.set("longitude", String(lon));
  url.searchParams.set("distance", "25");
  url.searchParams.set("API_KEY", key);

  const res = await fetch(url.toString(), { next: { revalidate: 0 } });
  if (!res.ok) throw new Error(`AirNow ${res.status}`);
  const data = (await res.json()) as Array<{
    AQI?: number;
    Category?: { Name?: string };
    ParameterName?: string;
    Value?: number;
  }>;
  if (!Array.isArray(data) || data.length === 0) {
    return { aqi: null, aqiCategory: null, pm25: null, ozonePpb: null, raw: data };
  }
  const pmRow = data.find((d) => /PM2\.5/i.test(d.ParameterName ?? ""));
  const ozoneRow = data.find((d) => /OZONE/i.test(d.ParameterName ?? ""));
  const best = data.reduce((a, b) => ((a.AQI ?? -1) >= (b.AQI ?? -1) ? a : b));
  return {
    aqi: best.AQI ?? null,
    aqiCategory: best.Category?.Name ?? null,
    pm25: pmRow?.Value ?? null,
    ozonePpb: ozoneRow?.Value ?? null,
    raw: data,
  };
}

async function fetchFirmsHotspots(lat: number, lon: number) {
  const mapKey = process.env.FIRMS_MAP_KEY?.trim();
  if (!mapKey) return { count: 0, raw: null as unknown, source: "skipped" as const, error: null as string | null };

  const delta = 0.45;
  const west = lon - delta;
  const south = lat - delta;
  const east = lon + delta;
  const north = lat + delta;
  const url = `https://firms.modaps.eosdis.nasa.gov/api/area/csv/${mapKey}/VIIRS_SNPP_NRT/${west},${south},${east},${north}/1`;

  const res = await fetch(url, { next: { revalidate: 0 } });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`FIRMS ${res.status}: ${text.slice(0, 120)}`);
  }
  if (/invalid map_key/i.test(text)) {
    throw new Error("FIRMS Invalid MAP_KEY — check FIRMS_MAP_KEY on Vercel");
  }

  const lines = text.trim().split("\n").filter(Boolean);
  const count = lines.length > 1 ? lines.length - 1 : 0; // subtract CSV header row
  return { count, raw: text.slice(0, 2000), source: "firms" as const, error: null as string | null };
}

function alertLooksLikeFire(event: string, headline: string): boolean {
  const hay = `${event} ${headline}`.toLowerCase();
  return hay.includes("fire") || hay.includes("smoke") || hay.includes("red flag") || hay.includes("burn");
}

function alertLooksLikeStorm(event: string, headline: string): boolean {
  const hay = `${event} ${headline}`.toLowerCase();
  return (
    hay.includes("thunder") ||
    hay.includes("storm") ||
    hay.includes("tornado") ||
    hay.includes("severe") ||
    hay.includes("hurricane") ||
    hay.includes("tropical") ||
    hay.includes("wind") ||
    hay.includes("blizzard") ||
    hay.includes("winter") ||
    hay.includes("heat") ||
    hay.includes("cold") ||
    hay.includes("freeze") ||
    hay.includes("frost") ||
    hay.includes("air quality") ||
    hay.includes("smoke") ||
    hay.includes("fog")
  );
}

function inversionHeuristic(periods: NwsPeriod[]) {
  if (periods.length < 2) return { possible: false, note: null };
  const night = periods.find((p) => p.isDaytime === false);
  const day = periods.find((p) => p.isDaytime === true);
  if (!night || !day || night.temperature == null || day.temperature == null) {
    return { possible: false, note: null };
  }
  const nightF = toFahrenheit(night.temperature, night.temperatureUnit);
  const dayF = toFahrenheit(day.temperature, day.temperatureUnit);
  const windMph = parseWindMph(night.windSpeed) ?? 99;
  const forecast = `${night.shortForecast ?? ""} ${night.detailedForecast ?? ""}`.toLowerCase();
  const clearCalm = windMph <= 6 && (forecast.includes("clear") || forecast.includes("fair") || forecast.includes("mostly clear"));
  const spread = dayF - nightF;
  if (clearCalm && spread >= 15) {
    return {
      possible: true,
      note: `Heuristic: calm clear night, day/night spread ~${Math.round(spread)}°F. Not a measured inversion.`,
    };
  }
  return { possible: false, note: null };
}

export async function enrichEnvironment(lat: number, lon: number): Promise<EnvEnrichment> {
  const raw: Record<string, unknown> = {};
  const point = await nwsFetch<NwsPoint>(`https://api.weather.gov/points/${lat.toFixed(4)},${lon.toFixed(4)}`);
  raw.point = point.properties?.relativeLocation?.properties ?? null;
  const forecastUrl = point.properties?.forecast;
  const alertsUrl = `https://api.weather.gov/alerts/active?point=${lat.toFixed(4)},${lon.toFixed(4)}`;

  const [forecast, alerts, airNow, firms, ambee] = await Promise.all([
    forecastUrl ? nwsFetch<{ properties?: { periods?: NwsPeriod[] } }>(forecastUrl) : Promise.resolve(null),
    nwsFetch<{ features?: NwsAlert[] }>(alertsUrl).catch((err: Error) => {
      raw.alertsError = err.message;
      return { features: [] as NwsAlert[] };
    }),
    fetchAirNow(lat, lon).catch((err: Error) => {
      raw.airNowError = err.message;
      return { aqi: null, aqiCategory: null, pm25: null, ozonePpb: null, raw: null };
    }),
    fetchFirmsHotspots(lat, lon).catch((err: Error) => {
      raw.firmsError = err.message;
      return { count: 0, raw: null, source: "error" as const };
    }),
    fetchAmbeeBundle(lat, lon),
  ]);

  const periods = forecast?.properties?.periods ?? [];
  raw.forecastPeriods = periods.slice(0, 4);
  raw.airNow = airNow.raw;
  raw.firms = firms;
  raw.ambee = {
    configured: ambee.configured,
    errors: ambee.errors,
    aq: ambee.aq?.raw ?? null,
    pollen: ambee.pollen?.raw ?? null,
    weather: ambee.weather?.raw ?? null,
    fire: ambee.fire?.raw ?? null,
  };

  const current = periods[0];
  const nwsTempF = current?.temperature != null ? toFahrenheit(current.temperature, current.temperatureUnit) : null;
  const ambeeTempF = ambee.weather?.temperatureF ?? null;
  const temperatureF = ambeeTempF ?? nwsTempF;
  const tempSource: EnvSnapshot["tempSource"] = ambeeTempF != null ? "ambee_weather" : nwsTempF != null ? "nws_forecast" : null;
  const isExtremeTemp = temperatureF != null && (temperatureF <= EXTREME_COLD_F || temperatureF >= EXTREME_HOT_F);

  const ambeeAqi = ambee.aq?.aqi ?? null;
  const aqi = airNow.aqi ?? ambeeAqi;
  const aqiCategory = airNow.aqiCategory ?? ambee.aq?.aqiCategory ?? null;
  const aqiSource: EnvSnapshot["aqiSource"] =
    airNow.aqi != null ? "airnow" : ambeeAqi != null ? "ambee" : null;

  const alertFeatures = alerts.features ?? [];
  raw.alerts = alertFeatures.map((a) => ({
    event: a.properties?.event,
    headline: a.properties?.headline,
    severity: a.properties?.severity,
  }));

  const stormAlerts = alertFeatures.filter((a) => alertLooksLikeStorm(a.properties?.event ?? "", a.properties?.headline ?? ""));
  const fireAlerts = alertFeatures.filter((a) => alertLooksLikeFire(a.properties?.event ?? "", a.properties?.headline ?? ""));
  const hasStormAlert = stormAlerts.length > 0;
  const stormSummary = hasStormAlert
    ? stormAlerts.slice(0, 3).map((a) => a.properties?.event ?? a.properties?.headline ?? "Storm alert").join("; ")
    : null;
  const ambeeFireNearby = ambee.fire?.nearestKm != null && ambee.fire.nearestKm <= 50;
  const hasWildfireNearby = fireAlerts.length > 0 || firms.count > 0 || ambeeFireNearby;
  const wildfireParts: string[] = [];
  if (fireAlerts.length) wildfireParts.push(fireAlerts.slice(0, 2).map((a) => a.properties?.event ?? "Fire/smoke alert").join("; "));
  if (firms.count > 0) wildfireParts.push(`${firms.count} FIRMS hotspot(s) within ~50km (24h)`);
  if (ambeeFireNearby && ambee.fire?.summary) wildfireParts.push(`Ambee ${ambee.fire.summary}`);
  const wildfireSummary = hasWildfireNearby ? wildfireParts.join(" | ") : null;
  const inversion = inversionHeuristic(periods);

  const pollen = ambee.pollen
    ? {
        treeRisk: ambee.pollen.treeRisk,
        grassRisk: ambee.pollen.grassRisk,
        weedRisk: ambee.pollen.weedRisk,
        treeCount: ambee.pollen.treeCount,
        grassCount: ambee.pollen.grassCount,
        weedCount: ambee.pollen.weedCount,
        topSpecies: ambee.pollen.topSpecies,
        asOf: ambee.pollen.asOf,
      }
    : null;

  const freeWildfireParts: string[] = [];
  if (fireAlerts.length) freeWildfireParts.push(fireAlerts.slice(0, 2).map((a) => a.properties?.event ?? "Fire/smoke alert").join("; "));
  if (firms.count > 0) freeWildfireParts.push(`${firms.count} FIRMS hotspot(s) within ~50km`);

  const free: EnvSourceValues = {
    temperatureF: nwsTempF,
    humidityPct: null,
    dewpointF: null,
    aqi: airNow.aqi,
    aqiCategory: airNow.aqiCategory,
    aqiPollutant: null,
    pm25: airNow.pm25,
    ozonePpb: airNow.ozonePpb,
    pollen: null,
    wildfire: freeWildfireParts.length ? freeWildfireParts.join(" · ") : null,
  };

  const ambeeWildfire =
    ambee.fire?.nearestKm != null && ambee.fire.nearestKm <= 50 && ambee.fire.summary
      ? ambee.fire.summary
      : null;

  const ambeeValues: EnvSourceValues = {
    temperatureF: ambeeTempF,
    humidityPct: ambee.weather?.humidityPct ?? null,
    dewpointF: ambee.weather?.dewpointF ?? null,
    aqi: ambeeAqi,
    aqiCategory: ambee.aq?.aqiCategory ?? null,
    aqiPollutant: ambee.aq?.aqiPollutant ?? null,
    pm25: ambee.aq?.pm25 ?? null,
    ozonePpb: ambee.aq?.ozonePpb ?? null,
    pollen,
    wildfire: ambeeWildfire,
  };

  const snapshot: EnvSnapshot = {
    v: 2,
    free,
    ambee: ambeeValues,
    aqiSource,
    tempSource,
  };

  return {
    aqi,
    aqiCategory,
    temperatureF,
    isExtremeTemp,
    hasStormAlert,
    stormSummary,
    hasWildfireNearby,
    wildfireSummary,
    possibleInversion: inversion.possible,
    inversionNote: inversion.note,
    snapshot,
    raw,
  };
}
