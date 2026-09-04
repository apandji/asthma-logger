import { fetchAmbeeBundle, formatDisaster, isWildfireSmokeCandidate, wildfireDisasterHits } from "./ambee";
import { hotspotCopy, mergeFireCopy, NEARBY_KM, summarizeHazards, type HazardCopy } from "./hazard-copy";
import { fetchOpenAq } from "./openaq";
import { formatPlaceName, lookupPlaceName } from "./place";
import { formatMilesAway } from "./units";
import type { EnvDisasterHit, EnvEnrichment, EnvSnapshot, EnvSourceValues } from "./types";

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

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const r = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.asin(Math.min(1, Math.sqrt(a)));
}

async function fetchFirmsHotspots(lat: number, lon: number) {
  const empty = {
    count: 0,
    nearestKm: null as number | null,
    nearestLat: null as number | null,
    nearestLng: null as number | null,
    raw: null as unknown,
    source: "skipped" as const,
    error: null as string | null,
  };
  const mapKey = process.env.FIRMS_MAP_KEY?.trim();
  if (!mapKey) return empty;

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
  const count = lines.length > 1 ? lines.length - 1 : 0;
  let nearestKm: number | null = null;
  let nearestLat: number | null = null;
  let nearestLng: number | null = null;
  if (count > 0) {
    const header = lines[0].split(",").map((h) => h.trim().toLowerCase());
    const latIdx = header.indexOf("latitude");
    const lonIdx = header.indexOf("longitude");
    if (latIdx >= 0 && lonIdx >= 0) {
      for (const line of lines.slice(1)) {
        const cols = line.split(",");
        const hLat = Number(cols[latIdx]);
        const hLon = Number(cols[lonIdx]);
        if (!Number.isFinite(hLat) || !Number.isFinite(hLon)) continue;
        const km = haversineKm(lat, lon, hLat, hLon);
        if (nearestKm == null || km < nearestKm) {
          nearestKm = km;
          nearestLat = hLat;
          nearestLng = hLon;
        }
      }
    }
  }
  return { count, nearestKm, nearestLat, nearestLng, raw: text.slice(0, 2000), source: "firms" as const, error: null as string | null };
}

function alertLooksLikeFire(event: string, headline: string): boolean {
  const hay = `${event} ${headline}`.toLowerCase();
  // "burn" alone catches burn bans; require fire/smoke/red-flag wording.
  return (
    hay.includes("red flag") ||
    hay.includes("fire weather") ||
    hay.includes("wildfire") ||
    hay.includes("forest fire") ||
    /\bsmoke\b/.test(hay) ||
    (/\bfire\b/.test(hay) && !/\bburn ban\b/.test(hay))
  );
}

function alertHay(event: string, headline: string): string {
  return `${event} ${headline}`.toLowerCase();
}

/** Heat / cold / freeze — not a storm. Shown on the Temp row. */
function alertLooksLikeExtremeTemp(event: string, headline: string): boolean {
  const hay = alertHay(event, headline);
  return (
    hay.includes("heat") ||
    hay.includes("cold") ||
    hay.includes("freeze") ||
    hay.includes("frost") ||
    hay.includes("wind chill") ||
    hay.includes("hard freeze")
  );
}

/** Convective / winter storms only. Extreme heat, AQ, and wind advisories are not storms. */
function alertLooksLikeStorm(event: string, headline: string): boolean {
  if (alertLooksLikeExtremeTemp(event, headline)) return false;
  const hay = alertHay(event, headline);
  return (
    hay.includes("thunder") ||
    hay.includes("tornado") ||
    hay.includes("hurricane") ||
    hay.includes("tropical") ||
    hay.includes("blizzard") ||
    hay.includes("hail") ||
    /\bstorm\b/.test(hay)
  );
}

function summarizeDisasters(
  hits: EnvDisasterHit[],
  types: EnvDisasterHit["type"][],
  noun: "storm" | "wildfire" | "event" = "event",
): string | null {
  if (noun === "storm" || noun === "wildfire") {
    const copy = summarizeHazards(hits, types, noun);
    if (!copy) return null;
    return copy.detail ? `${copy.text} · ${copy.detail}` : copy.text;
  }
  const matched = hits.filter((h) => types.includes(h.type)).slice(0, 2);
  if (!matched.length) return null;
  return matched.map((h) => formatDisaster(h)).join(" · ");
}

export async function enrichEnvironment(lat: number, lon: number): Promise<EnvEnrichment> {
  const raw: Record<string, unknown> = {};
  const point = await nwsFetch<NwsPoint>(`https://api.weather.gov/points/${lat.toFixed(4)},${lon.toFixed(4)}`);
  const nwsPlace = point.properties?.relativeLocation?.properties;
  raw.point = nwsPlace ?? null;
  const placeName = formatPlaceName(nwsPlace?.city, nwsPlace?.state);
  const forecastUrl = point.properties?.forecast;
  const alertsUrl = `https://api.weather.gov/alerts/active?point=${lat.toFixed(4)},${lon.toFixed(4)}`;

  const [forecast, alerts, airNow, openaq, firms, ambee] = await Promise.all([
    forecastUrl ? nwsFetch<{ properties?: { periods?: NwsPeriod[] } }>(forecastUrl) : Promise.resolve(null),
    nwsFetch<{ features?: NwsAlert[] }>(alertsUrl).catch((err: Error) => {
      raw.alertsError = err.message;
      return { features: [] as NwsAlert[] };
    }),
    fetchAirNow(lat, lon).catch((err: Error) => {
      raw.airNowError = err.message;
      return { aqi: null, aqiCategory: null, pm25: null, ozonePpb: null, raw: null };
    }),
    fetchOpenAq(lat, lon),
    fetchFirmsHotspots(lat, lon).catch((err: Error) => {
      raw.firmsError = err.message;
      return { count: 0, nearestKm: null, nearestLat: null, nearestLng: null, raw: null, source: "error" as const };
    }),
    fetchAmbeeBundle(lat, lon),
  ]);

  const periods = forecast?.properties?.periods ?? [];
  raw.forecastPeriods = periods.slice(0, 4);
  raw.airNow = airNow.raw;
  raw.openaq = openaq.raw;
  if (openaq.error) raw.openaqError = openaq.error;
  raw.firms = firms;
  raw.ambee = {
    configured: ambee.configured,
    errors: ambee.errors,
    aq: ambee.aq?.raw ?? null,
    pollen: ambee.pollen?.raw ?? null,
    weather: ambee.weather?.raw ?? null,
    fire: ambee.fire?.raw ?? null,
    disasters: ambee.disasters?.raw ?? null,
  };

  const current = periods[0];
  const nwsTempF = current?.temperature != null ? toFahrenheit(current.temperature, current.temperatureUnit) : null;
  const ambeeTempF = ambee.weather?.temperatureF ?? null;
  const temperatureF = ambeeTempF ?? nwsTempF;
  const tempSource: EnvSnapshot["tempSource"] = ambeeTempF != null ? "ambee_weather" : nwsTempF != null ? "nws_forecast" : null;
  const isExtremeTemp = temperatureF != null && (temperatureF <= EXTREME_COLD_F || temperatureF >= EXTREME_HOT_F);

  const ambeeAqi = ambee.aq?.aqi ?? null;
  const openaqHasAir = openaq.pm25 != null || openaq.ozonePpb != null;
  const aqi = openaqHasAir ? openaq.aqi : airNow.aqi ?? ambeeAqi;
  const aqiCategory = openaqHasAir ? openaq.aqiCategory : airNow.aqiCategory ?? ambee.aq?.aqiCategory ?? null;
  const aqiSource: EnvSnapshot["aqiSource"] = openaqHasAir
    ? "openaq"
    : airNow.aqi != null
      ? "airnow"
      : ambeeAqi != null
        ? "ambee"
        : null;

  const alertFeatures = alerts.features ?? [];
  raw.alerts = alertFeatures.map((a) => ({
    event: a.properties?.event,
    headline: a.properties?.headline,
    severity: a.properties?.severity,
  }));

  const stormAlerts = alertFeatures.filter((a) => alertLooksLikeStorm(a.properties?.event ?? "", a.properties?.headline ?? ""));
  const extremeTempAlerts = alertFeatures.filter((a) =>
    alertLooksLikeExtremeTemp(a.properties?.event ?? "", a.properties?.headline ?? ""),
  );
  const fireAlerts = alertFeatures.filter((a) => alertLooksLikeFire(a.properties?.event ?? "", a.properties?.headline ?? ""));
  const hasStormAlert = stormAlerts.length > 0;
  const stormSummary = hasStormAlert
    ? stormAlerts.slice(0, 3).map((a) => a.properties?.event ?? a.properties?.headline ?? "Storm alert").join("; ")
    : null;
  const nwsExtremeTemp = extremeTempAlerts.length
    ? extremeTempAlerts
        .slice(0, 2)
        .map((a) => a.properties?.event ?? a.properties?.headline ?? "Extreme temperature")
        .join("; ")
    : null;

  const disasterHits: EnvDisasterHit[] = (ambee.disasters?.events ?? []).map((e) => ({
    type: e.type,
    name: e.name,
    km: e.km,
    place: e.place,
    lat: e.lat,
    lng: e.lng,
  }));

  const wfHits = wildfireDisasterHits(disasterHits);
  const ambeeWfNearby = wfHits.some((h) => h.km == null || h.km <= NEARBY_KM);
  const ambeeReportedNearby =
    ambee.fire?.fireType === "reported" &&
    ambee.fire.nearestKm != null &&
    ambee.fire.nearestKm <= 50 &&
    isWildfireSmokeCandidate(ambee.fire.fireName ?? ambee.fire.summary);
  // FIRMS / Ambee "detected" heat alone does not claim a breathing-relevant wildfire.
  const hasWildfireNearby = fireAlerts.length > 0 || ambeeWfNearby || ambeeReportedNearby;

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

  const needPlace = (hit: EnvDisasterHit | undefined) =>
    Boolean(hit && !hit.place && hit.lat != null && hit.lng != null);

  const nearestStorm = disasterHits.find((h) => h.type === "SW" || h.type === "TC");
  const nearestWf = wfHits[0];
  const nearestEt = disasterHits.find((h) => h.type === "ET");

  const [firePlace, firmsPlace, stormPlace, wfPlace, etPlace] = await Promise.all([
    ambee.fire?.nearestLat != null && ambee.fire.nearestLng != null
      ? lookupPlaceName(ambee.fire.nearestLat, ambee.fire.nearestLng).catch(() => null)
      : Promise.resolve(null),
    firms.nearestLat != null && firms.nearestLng != null
      ? lookupPlaceName(firms.nearestLat, firms.nearestLng).catch(() => null)
      : Promise.resolve(null),
    needPlace(nearestStorm) ? lookupPlaceName(nearestStorm!.lat!, nearestStorm!.lng!).catch(() => null) : Promise.resolve(nearestStorm?.place ?? null),
    needPlace(nearestWf) ? lookupPlaceName(nearestWf!.lat!, nearestWf!.lng!).catch(() => null) : Promise.resolve(nearestWf?.place ?? null),
    needPlace(nearestEt) ? lookupPlaceName(nearestEt!.lat!, nearestEt!.lng!).catch(() => null) : Promise.resolve(nearestEt?.place ?? null),
  ]);

  if (nearestStorm && stormPlace) nearestStorm.place = stormPlace;
  if (nearestWf && wfPlace) nearestWf.place = wfPlace;
  if (nearestEt && etPlace) nearestEt.place = etPlace;

  const ambeeWfHit = wfHits.find((h) => h.km == null || h.km <= NEARBY_KM);
  const wildfireParts: string[] = [];
  if (ambeeWfHit) {
    const label = ambeeWfHit.place
      ? `Ambee WF near ${ambeeWfHit.place}`
      : ambeeWfHit.name || "Ambee WF";
    wildfireParts.push(
      ambeeWfHit.km != null ? `${label} · ${formatMilesAway(ambeeWfHit.km)}` : label,
    );
  }
  if (fireAlerts.length) {
    wildfireParts.push(fireAlerts.slice(0, 2).map((a) => a.properties?.event ?? "Fire/smoke alert").join("; "));
  }
  if (ambeeReportedNearby && ambee.fire?.summary) {
    wildfireParts.push(`Ambee reported ${ambee.fire.summary}`);
  }
  // FIRMS is secondary context only — still stored when present.
  if (firms.count > 0) {
    wildfireParts.push(
      `${firms.count} FIRMS heat pixel(s) within ~31 mi (24h)${firms.nearestKm != null ? ` · closest ${formatMilesAway(firms.nearestKm)}` : ""}`,
    );
  }
  if (
    ambee.fire?.fireType !== "reported" &&
    ambee.fire?.nearestKm != null &&
    ambee.fire.nearestKm <= 50 &&
    ambee.fire.summary
  ) {
    wildfireParts.push(`Ambee detected heat ${ambee.fire.summary}`);
  }
  const wildfireSummary = wildfireParts.length ? wildfireParts.join(" | ") : null;

  const freeWildfireParts: string[] = [];
  if (fireAlerts.length) {
    freeWildfireParts.push(fireAlerts.slice(0, 2).map((a) => a.properties?.event ?? "Fire/smoke alert").join("; "));
  }
  if (firms.count > 0) {
    const firmsLine =
      firms.nearestKm != null
        ? (() => {
            const copy = hotspotCopy(firms.nearestKm, firmsPlace, firms.count);
            return copy.detail ? `${copy.text} · ${copy.detail}` : copy.text;
          })()
        : firms.count === 1
          ? "Satellite heat nearby"
          : `${firms.count} satellite heat spots nearby`;
    // Secondary when NWS already leads; alone when only heat pixels exist.
    freeWildfireParts.push(freeWildfireParts.length ? `also ${firmsLine}` : firmsLine);
  }

  const free: EnvSourceValues = {
    temperatureF: nwsTempF,
    humidityPct: null,
    dewpointF: null,
    aqi: openaqHasAir ? openaq.aqi : airNow.aqi,
    aqiCategory: openaqHasAir ? openaq.aqiCategory : airNow.aqiCategory,
    aqiPollutant: openaqHasAir ? openaq.aqiPollutant : null,
    pm25: openaqHasAir ? openaq.pm25 : airNow.pm25,
    ozonePpb: openaqHasAir ? openaq.ozonePpb : airNow.ozonePpb,
    pm25Station: openaqHasAir ? openaq.pm25Station : null,
    ozoneStation: openaqHasAir ? openaq.ozoneStation : null,
    pollen: null,
    wildfire: freeWildfireParts.length ? freeWildfireParts.join(" · ") : null,
    storms: stormSummary,
    extremeTempEvent: nwsExtremeTemp,
    volcano: null,
    disasters: null,
  };

  const ambeeStorms = summarizeDisasters(disasterHits, ["SW", "TC"], "storm");
  const ambeeEt = summarizeDisasters(disasterHits, ["ET"]);
  const ambeeVo = summarizeDisasters(disasterHits, ["VO"]);
  const ambeeWf = summarizeHazards(wfHits, ["WF"], "wildfire");

  const ambeeReportedFire: HazardCopy | null =
    ambee.fire?.fireType === "reported" &&
    ambee.fire.nearestKm != null &&
    ambee.fire.nearestKm <= 50 &&
    isWildfireSmokeCandidate(ambee.fire.fireName ?? ambee.fire.summary)
      ? (() => {
          const km = ambee.fire.nearestKm!;
          const loc = (firePlace ?? ambee.fire.fireName)?.replace(/^near\s+/i, "").trim() || null;
          return {
            text: loc ? `Near ${loc}` : "Wildfire reported",
            detail: formatMilesAway(km),
            nearby: km <= NEARBY_KM,
            km,
          };
        })()
      : null;

  const ambeeDetectedHeat =
    ambee.fire?.nearestKm != null &&
    ambee.fire.nearestKm <= 50 &&
    ambee.fire.fireType !== "reported"
      ? hotspotCopy(ambee.fire.nearestKm, firePlace)
      : null;

  // Ambee WF tag wins; reported fire API next; detected heat is secondary only.
  const ambeeFireMerged = mergeFireCopy(ambeeDetectedHeat, ambeeWf ?? ambeeReportedFire);
  const ambeeWildfire = ambeeFireMerged
    ? ambeeFireMerged.detail
      ? `${ambeeFireMerged.text} · ${ambeeFireMerged.detail}`
      : ambeeFireMerged.text
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
    storms: ambeeStorms,
    extremeTempEvent: ambeeEt,
    volcano: ambeeVo,
    disasters: disasterHits.length ? disasterHits : null,
  };

  const snapshot: EnvSnapshot = {
    v: 2,
    free,
    ambee: ambeeValues,
    aqiSource,
    tempSource,
    ambeeErrors: ambee.errors.length ? ambee.errors : undefined,
    openaqError: openaq.error ?? undefined,
    placeName,
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
    possibleInversion: false,
    inversionNote: null,
    snapshot,
    raw,
  };
}
