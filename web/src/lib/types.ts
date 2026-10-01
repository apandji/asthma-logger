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
  /** Named place from reverse geocode, e.g. "St. Louis, MO" */
  placeName?: string | null;
};

export type EnvPollenSnapshot = {
  treeRisk: string | null;
  grassRisk: string | null;
  weedRisk: string | null;
  treeCount: number | null;
  grassCount: number | null;
  weedCount: number | null;
  topSpecies: string | null;
  asOf: string | null;
};

export type EnvDisasterType = "SW" | "ET" | "WF" | "TC" | "VO";

export type EnvDisasterHit = {
  type: EnvDisasterType;
  name: string;
  km: number | null;
  place: string | null;
  lat?: number | null;
  lng?: number | null;
  eventAt?: string | null;
  expiresAt?: string | null;
  burnedArea?: number | null;
  containedPct?: number | null;
};

/** Named ground station behind a PM2.5 or ozone reading. */
export type EnvAirStation = {
  name: string | null;
  km: number | null;
  asOf: string | null;
  isMonitor: boolean | null;
  provider: string | null;
};

/** Per-source values for side-by-side comparison (v2). */
export type EnvSourceValues = {
  temperatureF: number | null;
  humidityPct: number | null;
  dewpointF: number | null;
  aqi: number | null;
  aqiCategory: string | null;
  aqiPollutant: string | null;
  pm25: number | null;
  ozonePpb: number | null;
  /** Nearest PM2.5 station when the value is a ground reading (OpenAQ). */
  pm25Station?: EnvAirStation | null;
  /** Nearest ozone station when the value is a ground reading (OpenAQ). */
  ozoneStation?: EnvAirStation | null;
  pollen: EnvPollenSnapshot | null;
  /** Short wildfire label for the comparison row */
  wildfire: string | null;
  /** Severe storm / cyclone events (Ambee disasters SW+TC, or NWS alerts) */
  storms: string | null;
  /** Extreme temperature event from Ambee disasters (ET) */
  extremeTempEvent: string | null;
  /** Volcanic ash event — air quality, not a wildfire */
  volcano: string | null;
  disasters: EnvDisasterHit[] | null;
};

/** v1 snapshot — legacy, read-only */
export type EnvSnapshotV1 = {
  v: 1;
  humidityPct: number | null;
  dewpointF: number | null;
  pm25: number | null;
  ozonePpb: number | null;
  aqiSource: "airnow" | "ambee" | null;
  tempSource: "nws_forecast" | "ambee_weather" | null;
  aqiPollutant: string | null;
  pollen: EnvPollenSnapshot | null;
  nearestFireKm: number | null;
  nearestFireSummary: string | null;
};

export type EnvSnapshot = {
  v: 2;
  free: EnvSourceValues;
  ambee: EnvSourceValues;
  /** Which source won for the primary log fields (legacy columns) */
  aqiSource: "openaq" | "airnow" | "ambee" | null;
  tempSource: "nws_forecast" | "ambee_weather" | null;
  /** Fail-open Ambee errors (e.g. weather not on trial) */
  ambeeErrors?: string[];
  /** Fail-open OpenAQ error (missing key is not an error) */
  openaqError?: string;
  /** Nearest named place (NWS relative location), e.g. "St. Louis, MO" */
  placeName?: string | null;
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
  placeName?: string | null;
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
