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
  source: "template" | "ollama" | "webllm" | "gemma-webgpu" | "stub";
  model?: string;
  latencyMs?: number;
};

export const NARRATOR_RULES = [
  "Sound like a diary narrator, not a stats readout or a causal diagnosis.",
  "Name the top outdoor signals from the table in plain language and weave in the #1 counts once.",
  "Do not invent drivers or counts. Do not predict a future attack or give medical advice.",
  "Soft association language is OK (“lining up with”, “shows up more on harder days”). Absolute causation is not.",
  "Put hedging only in caveat. Headline must stay concrete and human.",
  "If the table is empty or nAttacks is 0, then say we need more logs — otherwise never claim there is nothing to say.",
] as const;
