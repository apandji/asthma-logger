import type { Feeling } from "./feelings";

export type { Feeling } from "./feelings";
export { FEELING_OPTIONS, feelingDisplay } from "./feelings";
export type EnvStatus = "pending" | "ready" | "failed" | "skipped";

export type LocalLog = {
  id: string;
  loggedAt: string;
  latitude: number;
  longitude: number;
  feeling: Feeling | null;
  syncStatus: "pending" | "synced" | "error";
  lastError?: string;
  serverEnvStatus?: EnvStatus;
  /** Full server row after sync — used for badges if live fetch is stale */
  serverLog?: AttackLogDTO;
};

export type EnvSnapshot = {
  v: 1;
  humidityPct: number | null;
  dewpointF: number | null;
  pm25: number | null;
  ozonePpb: number | null;
  aqiSource: "airnow" | "ambee" | null;
  tempSource: "nws_forecast" | "ambee_weather" | null;
  aqiPollutant: string | null;
  pollen: {
    treeRisk: string | null;
    grassRisk: string | null;
    weedRisk: string | null;
    treeCount: number | null;
    grassCount: number | null;
    weedCount: number | null;
    topSpecies: string | null;
    asOf: string | null;
  } | null;
  nearestFireKm: number | null;
  nearestFireSummary: string | null;
};

export type AttackLogDTO = {
  id: string;
  loggedAt: string;
  latitude: number;
  longitude: number;
  feeling: string | null;
  envStatus: EnvStatus;
  envFetchedAt: string | null;
  envError: string | null;
  aqi: number | null;
  aqiCategory: string | null;
  temperatureF: number | null;
  isExtremeTemp: boolean;
  hasStormAlert: boolean;
  stormSummary: string | null;
  hasWildfireNearby: boolean;
  wildfireSummary: string | null;
  possibleInversion: boolean;
  inversionNote: string | null;
  snapshot?: EnvSnapshot | null;
};

export type EnvEnrichment = {
  aqi: number | null;
  aqiCategory: string | null;
  temperatureF: number | null;
  isExtremeTemp: boolean;
  hasStormAlert: boolean;
  stormSummary: string | null;
  hasWildfireNearby: boolean;
  wildfireSummary: string | null;
  possibleInversion: boolean;
  inversionNote: string | null;
  snapshot: EnvSnapshot | null;
  raw: Record<string, unknown>;
};
