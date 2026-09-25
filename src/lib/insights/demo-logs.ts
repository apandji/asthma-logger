import type { AttackLogDTO, EnvSnapshot, EnvSourceValues, EnvStatus } from "@/lib/types";

function emptySources(): EnvSourceValues {
  return {
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
  };
}

function snapshot(partial: {
  tempF: number;
  humidity: number;
  pm25: number;
  ozone: number;
  aqi: number;
  aqiCategory: string;
  weedRisk: string;
  heat?: boolean;
  smoke?: boolean;
}): EnvSnapshot {
  const free: EnvSourceValues = {
    ...emptySources(),
    temperatureF: partial.tempF,
    humidityPct: partial.humidity,
    pm25: partial.pm25,
    ozonePpb: partial.ozone,
    aqi: partial.aqi,
    aqiCategory: partial.aqiCategory,
    aqiPollutant: "O3",
    pollen: {
      treeRisk: "Low",
      grassRisk: "Low",
      weedRisk: partial.weedRisk,
      treeCount: null,
      grassCount: null,
      weedCount: null,
      topSpecies: null,
      asOf: new Date().toISOString(),
    },
    wildfire: partial.smoke ? "Smoke-like PM nearby" : null,
  };
  return {
    v: 2,
    free,
    ambee: { ...emptySources() },
    aqiSource: "airnow",
    tempSource: "nws_forecast",
    placeName: "Los Angeles, CA",
  };
}

type SeedSpec = {
  id: string;
  daysAgo: number;
  hour: number;
  feeling: "mild" | "bad" | "ok" | null;
  tempF: number;
  humidity: number;
  pm25: number;
  ozone: number;
  aqi: number;
  aqiCategory: string;
  weedRisk: string;
  heat?: boolean;
  smoke?: boolean;
};

/**
 * Talk-demo diary: LA-ish summer story — high-ozone attacks in the afternoon,
 * milder “ok” mornings as usual-day baselines.
 */
const SPECS: SeedSpec[] = [
  // Attacks (inhaler use)
  { id: "demo-atk-01", daysAgo: 18, hour: 15, feeling: "bad", tempF: 94, humidity: 42, pm25: 18, ozone: 78, aqi: 112, aqiCategory: "Unhealthy for Sensitive Groups", weedRisk: "Moderate", heat: true },
  { id: "demo-atk-02", daysAgo: 16, hour: 16, feeling: "mild", tempF: 96, humidity: 28, pm25: 9, ozone: 82, aqi: 128, aqiCategory: "Unhealthy for Sensitive Groups", weedRisk: "High", heat: true },
  { id: "demo-atk-03", daysAgo: 14, hour: 14, feeling: "bad", tempF: 91, humidity: 48, pm25: 22, ozone: 74, aqi: 105, aqiCategory: "Unhealthy for Sensitive Groups", weedRisk: "Moderate" },
  { id: "demo-atk-04", daysAgo: 12, hour: 18, feeling: "mild", tempF: 84, humidity: 50, pm25: 8, ozone: 71, aqi: 98, aqiCategory: "Moderate", weedRisk: "Low" },
  { id: "demo-atk-05", daysAgo: 10, hour: 17, feeling: "bad", tempF: 93, humidity: 68, pm25: 48, ozone: 76, aqi: 118, aqiCategory: "Unhealthy for Sensitive Groups", weedRisk: "High", heat: true, smoke: true },
  { id: "demo-atk-06", daysAgo: 8, hour: 15, feeling: "mild", tempF: 90, humidity: 40, pm25: 11, ozone: 62, aqi: 84, aqiCategory: "Moderate", weedRisk: "High" },
  { id: "demo-atk-07", daysAgo: 6, hour: 19, feeling: null, tempF: 82, humidity: 55, pm25: 16, ozone: 73, aqi: 101, aqiCategory: "Unhealthy for Sensitive Groups", weedRisk: "Moderate" },
  { id: "demo-atk-08", daysAgo: 5, hour: 13, feeling: "bad", tempF: 95, humidity: 30, pm25: 10, ozone: 80, aqi: 122, aqiCategory: "Unhealthy for Sensitive Groups", weedRisk: "Moderate", heat: true },
  { id: "demo-atk-09", daysAgo: 3, hour: 16, feeling: "mild", tempF: 92, humidity: 44, pm25: 20, ozone: 75, aqi: 108, aqiCategory: "Unhealthy for Sensitive Groups", weedRisk: "Low" },
  { id: "demo-atk-10", daysAgo: 1, hour: 20, feeling: "mild", tempF: 79, humidity: 70, pm25: 7, ozone: 58, aqi: 72, aqiCategory: "Moderate", weedRisk: "Moderate" },
  // Usual-day baselines (feeling ok)
  { id: "demo-ok-01", daysAgo: 17, hour: 8, feeling: "ok", tempF: 72, humidity: 55, pm25: 6, ozone: 32, aqi: 38, aqiCategory: "Good", weedRisk: "None" },
  { id: "demo-ok-02", daysAgo: 15, hour: 9, feeling: "ok", tempF: 74, humidity: 58, pm25: 8, ozone: 28, aqi: 35, aqiCategory: "Good", weedRisk: "Low" },
  { id: "demo-ok-03", daysAgo: 13, hour: 8, feeling: "ok", tempF: 70, humidity: 62, pm25: 5, ozone: 30, aqi: 36, aqiCategory: "Good", weedRisk: "None" },
  { id: "demo-ok-04", daysAgo: 11, hour: 10, feeling: "ok", tempF: 76, humidity: 50, pm25: 9, ozone: 40, aqi: 42, aqiCategory: "Good", weedRisk: "None" },
  { id: "demo-ok-05", daysAgo: 9, hour: 8, feeling: "ok", tempF: 71, humidity: 60, pm25: 7, ozone: 34, aqi: 40, aqiCategory: "Good", weedRisk: "Low" },
  { id: "demo-ok-06", daysAgo: 7, hour: 9, feeling: "ok", tempF: 73, humidity: 52, pm25: 6, ozone: 36, aqi: 41, aqiCategory: "Good", weedRisk: "None" },
  { id: "demo-ok-07", daysAgo: 6, hour: 8, feeling: "ok", tempF: 69, humidity: 65, pm25: 10, ozone: 29, aqi: 34, aqiCategory: "Good", weedRisk: "None" },
  { id: "demo-ok-08", daysAgo: 4, hour: 10, feeling: "ok", tempF: 75, humidity: 48, pm25: 8, ozone: 45, aqi: 48, aqiCategory: "Good", weedRisk: "Low" },
  { id: "demo-ok-09", daysAgo: 2, hour: 8, feeling: "ok", tempF: 72, humidity: 57, pm25: 5, ozone: 31, aqi: 37, aqiCategory: "Good", weedRisk: "None" },
  { id: "demo-ok-10", daysAgo: 0, hour: 9, feeling: "ok", tempF: 74, humidity: 54, pm25: 7, ozone: 38, aqi: 43, aqiCategory: "Good", weedRisk: "None" },
];

function loggedAt(daysAgo: number, hour: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - daysAgo);
  d.setUTCHours(hour, 15, 0, 0);
  return d.toISOString();
}

export function buildDemoAttackLogs(): AttackLogDTO[] {
  return SPECS.map((s) => {
    const snap = snapshot(s);
    return {
      id: s.id,
      loggedAt: loggedAt(s.daysAgo, s.hour),
      latitude: 34.0522,
      longitude: -118.2437,
      feeling: s.feeling,
      envStatus: "ready" as EnvStatus,
      envFetchedAt: loggedAt(s.daysAgo, s.hour),
      envError: null,
      aqi: s.aqi,
      aqiCategory: s.aqiCategory,
      temperatureF: s.tempF,
      isExtremeTemp: Boolean(s.heat),
      hasStormAlert: false,
      stormSummary: s.heat ? "Excessive Heat Warning" : null,
      hasWildfireNearby: Boolean(s.smoke),
      wildfireSummary: s.smoke ? "Elevated PM2.5 — smoke-like air" : null,
      possibleInversion: false,
      inversionNote: null,
      snapshot: snap,
      placeName: "Los Angeles, CA",
    };
  }).sort((a, b) => new Date(b.loggedAt).getTime() - new Date(a.loggedAt).getTime());
}

/** True when we should serve in-memory demo diary instead of Postgres. */
export function shouldUseDemoLogs(): boolean {
  if (process.env.DEMO_SEED === "0") return false;
  if (process.env.DEMO_SEED === "1") return true;
  return !process.env.DATABASE_URL;
}
