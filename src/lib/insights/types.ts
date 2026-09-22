/** Feature frame for lift / narrative. Matches predictive-engine bins. */
export type FrameKind = "attack" | "baseline";

export type FeatureFrame = {
  id: string;
  kind: FrameKind;
  /** Local hour 0–23 */
  hourOfDay: number;
  season: "winter" | "spring" | "summer" | "fall";
  tempBand: "cold" | "mild" | "hot" | "unknown";
  humidityBand: "dry" | "ok" | "humid" | "unknown";
  pm25Band: "low" | "moderate" | "high" | "unknown";
  ozoneBand: "low" | "moderate" | "high" | "unknown";
  pollenWeed: "none" | "low" | "moderate" | "high" | "unknown";
  smokeAtPoint: boolean;
  heatAlert: boolean;
};

export type LiftRow = {
  bin: string;
  level: string;
  attacksWith: number;
  baselinesWith: number;
  nAttacks: number;
  nBaselines: number;
  attackRate: number;
  baselineRate: number;
  /** attackRate / baselineRate; Infinity if baselineRate is 0 and attacksWith > 0 */
  lift: number;
  gated: boolean;
};

export type LiftReport = {
  nAttacks: number;
  nBaselines: number;
  seasonHint: string | null;
  rows: LiftRow[];
  gatedRows: LiftRow[];
};

export type NarratorInput = {
  nAttacks: number;
  nBaselines: number;
  season: string | null;
  rows: Array<{
    bin: string;
    level: string;
    attacksWith: number;
    baselinesWith: number;
    attackRate: number;
    baselineRate: number;
    lift: number;
    gated: boolean;
  }>;
  rules: string[];
};

export type NarratorOutput = {
  headline: string;
  caveat: string;
  drivers: string[];
  /** Which narrator produced this */
  source: "template" | "ollama" | "stub";
  model?: string;
  latencyMs?: number;
};

export const NARRATOR_RULES = [
  "Do not claim causation or predict an attack.",
  "Always mention the counts for the top driver when gated rows exist.",
  "If no gated rows, say we need more usual days or more attacks.",
  "Outdoor air only — not indoor, not a diagnosis.",
] as const;
