export type Feeling = "skip" | "ok" | "mild" | "bad";
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
  raw: Record<string, unknown>;
};
