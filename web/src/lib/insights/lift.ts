import type { FeatureFrame, LiftReport, LiftRow } from "./types";

/** Default gates — keep soft for demos; raise for production (see predictive-engine). */
export type LiftGate = {
  minAttacks: number;
  minBaselines: number;
  minAttacksInLevel: number;
};

export const DEFAULT_GATE: LiftGate = {
  minAttacks: 8,
  minBaselines: 20,
  minAttacksInLevel: 4,
};

/** Looser gate so synthetic talk demos show gated rows quickly. */
export const DEMO_GATE: LiftGate = {
  minAttacks: 6,
  minBaselines: 12,
  minAttacksInLevel: 3,
};

type BinDef = {
  bin: string;
  levelOf: (f: FeatureFrame) => string | null;
};

const BINS: BinDef[] = [
  { bin: "pm25", levelOf: (f) => (f.pm25Band === "unknown" ? null : f.pm25Band) },
  { bin: "ozone", levelOf: (f) => (f.ozoneBand === "unknown" ? null : f.ozoneBand) },
  { bin: "pollen_weed", levelOf: (f) => (f.pollenWeed === "unknown" ? null : f.pollenWeed) },
  { bin: "temp", levelOf: (f) => (f.tempBand === "unknown" ? null : f.tempBand) },
  { bin: "humidity", levelOf: (f) => (f.humidityBand === "unknown" ? null : f.humidityBand) },
  { bin: "smoke_at_point", levelOf: (f) => (f.smokeAtPoint ? "yes" : "no") },
  { bin: "heat_alert", levelOf: (f) => (f.heatAlert ? "yes" : "no") },
  {
    bin: "hour",
    levelOf: (f) => {
      if (f.hourOfDay >= 5 && f.hourOfDay < 12) return "morning";
      if (f.hourOfDay >= 12 && f.hourOfDay < 17) return "afternoon";
      if (f.hourOfDay >= 17 && f.hourOfDay < 22) return "evening";
      return "night";
    },
  },
];

function rate(withLevel: number, total: number): number {
  if (total <= 0) return 0;
  return withLevel / total;
}

function liftValue(attackRate: number, baselineRate: number, attacksWith: number): number {
  if (baselineRate <= 0) return attacksWith > 0 ? Number.POSITIVE_INFINITY : 1;
  return attackRate / baselineRate;
}

/**
 * Case-control style rates: share of attack frames with level vs share of baseline frames.
 * Not P(attack | weather). Smoothing is applied only for ranking stability in predictive-engine;
 * this prototype reports raw rates so the talk can show the exact counts.
 */
export function computeLift(frames: FeatureFrame[], gate: LiftGate = DEFAULT_GATE): LiftReport {
  const attacks = frames.filter((f) => f.kind === "attack");
  const baselines = frames.filter((f) => f.kind === "baseline");
  const nAttacks = attacks.length;
  const nBaselines = baselines.length;

  const rows: LiftRow[] = [];

  for (const def of BINS) {
    const levels = new Set<string>();
    for (const f of frames) {
      const level = def.levelOf(f);
      if (level) levels.add(level);
    }

    for (const level of [...levels].sort()) {
      // Skip the "absent" half of boolean bins for the card — only show yes when interesting.
      if ((def.bin === "smoke_at_point" || def.bin === "heat_alert") && level === "no") continue;

      const attacksWith = attacks.filter((f) => def.levelOf(f) === level).length;
      const baselinesWith = baselines.filter((f) => def.levelOf(f) === level).length;
      const attackRate = rate(attacksWith, nAttacks);
      const baselineRate = rate(baselinesWith, nBaselines);
      const lift = liftValue(attackRate, baselineRate, attacksWith);
      const gated =
        nAttacks >= gate.minAttacks &&
        nBaselines >= gate.minBaselines &&
        attacksWith >= gate.minAttacksInLevel &&
        lift > 1.25;

      rows.push({
        bin: def.bin,
        level,
        attacksWith,
        baselinesWith,
        nAttacks,
        nBaselines,
        attackRate,
        baselineRate,
        lift,
        gated,
      });
    }
  }

  rows.sort((a, b) => {
    const la = Number.isFinite(a.lift) ? a.lift : 999;
    const lb = Number.isFinite(b.lift) ? b.lift : 999;
    return lb - la;
  });

  const gatedRows = rows.filter((r) => r.gated);
  const seasonHint = majoritySeason(frames);

  return { nAttacks, nBaselines, seasonHint, rows, gatedRows };
}

function majoritySeason(frames: FeatureFrame[]): string | null {
  if (frames.length === 0) return null;
  const counts = new Map<string, number>();
  for (const f of frames) counts.set(f.season, (counts.get(f.season) ?? 0) + 1);
  let best: string | null = null;
  let n = 0;
  for (const [s, c] of counts) {
    if (c > n) {
      best = s;
      n = c;
    }
  }
  return best;
}

export function formatLift(lift: number): string {
  if (!Number.isFinite(lift)) return "∞";
  if (lift >= 10) return lift.toFixed(0);
  return lift.toFixed(1);
}
