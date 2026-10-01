import { isLocalAirSmoky } from "@/lib/hazard-copy";
import type { AttackLogDTO } from "@/lib/types";
import { buildDemoFrames } from "./demo-frames";
import type { FeatureFrame, FrameKind } from "./types";

export type FramesBuildMeta = {
  nLogs: number;
  nSkippedNoEnv: number;
  nAttacks: number;
  nBaselines: number;
  /** Demo usual-day frames mixed in because no ok-day logs yet */
  supplementedDemoBaselines: number;
  baselineNote: string;
};

function seasonFromDate(iso: string): FeatureFrame["season"] {
  const m = new Date(iso).getMonth();
  if (m <= 1 || m === 11) return "winter";
  if (m <= 4) return "spring";
  if (m <= 7) return "summer";
  return "fall";
}

function bandPm25(v: number | null | undefined): FeatureFrame["pm25Band"] {
  if (v == null || !Number.isFinite(v)) return "unknown";
  if (v < 12) return "low";
  if (v < 35) return "moderate";
  return "high";
}

function bandOzone(ppb: number | null | undefined): FeatureFrame["ozoneBand"] {
  if (ppb == null || !Number.isFinite(ppb)) return "unknown";
  if (ppb < 55) return "low";
  if (ppb < 70) return "moderate";
  return "high";
}

function bandTemp(f: number | null | undefined, isExtreme: boolean): FeatureFrame["tempBand"] {
  if (f == null || !Number.isFinite(f)) return "unknown";
  if (isExtreme || f >= 90) return "hot";
  if (f <= 32) return "cold";
  return "mild";
}

function bandHumidity(pct: number | null | undefined): FeatureFrame["humidityBand"] {
  if (pct == null || !Number.isFinite(pct)) return "unknown";
  if (pct < 35) return "dry";
  if (pct > 65) return "humid";
  return "ok";
}

function pollenWeedFromRisk(risk: string | null | undefined): FeatureFrame["pollenWeed"] {
  if (!risk) return "unknown";
  const r = risk.toLowerCase();
  if (r.includes("very") || r.includes("vh") || r.includes("high")) return "high";
  if (r.includes("moderate") || r.includes("mod")) return "moderate";
  if (r.includes("low")) return "low";
  if (r.includes("none") || r === "0") return "none";
  return "unknown";
}

function pickEnv(log: AttackLogDTO) {
  const snap = log.snapshot;
  const free = snap?.free;
  const ambee = snap?.ambee;
  return {
    pm25: free?.pm25 ?? ambee?.pm25 ?? null,
    ozone: free?.ozonePpb ?? ambee?.ozonePpb ?? null,
    tempF: log.temperatureF ?? free?.temperatureF ?? ambee?.temperatureF ?? null,
    humidity: free?.humidityPct ?? ambee?.humidityPct ?? null,
    pollenWeedRisk: free?.pollen?.weedRisk ?? ambee?.pollen?.weedRisk ?? null,
    aqi: log.aqi ?? free?.aqi ?? ambee?.aqi ?? null,
  };
}

function logHasUsableEnv(log: AttackLogDTO): boolean {
  if (log.envStatus !== "ready") return false;
  const e = pickEnv(log);
  return (
    e.pm25 != null ||
    e.ozone != null ||
    e.tempF != null ||
    e.humidity != null ||
    e.pollenWeedRisk != null ||
    log.aqi != null
  );
}

function frameKindFromFeeling(feeling: string | null): FrameKind {
  if (feeling === "ok") return "baseline";
  return "attack";
}

export function attackLogToFrame(log: AttackLogDTO, kind?: FrameKind): FeatureFrame | null {
  if (!logHasUsableEnv(log)) return null;
  const e = pickEnv(log);
  const d = new Date(log.loggedAt);
  const smoke = isLocalAirSmoky({ pm25: e.pm25, aqi: e.aqi });
  const heatAlert = log.isExtremeTemp || /heat|excessive/i.test(log.stormSummary ?? "");

  return {
    id: log.id,
    kind: kind ?? frameKindFromFeeling(log.feeling),
    hourOfDay: d.getHours(),
    season: seasonFromDate(log.loggedAt),
    tempBand: bandTemp(e.tempF, log.isExtremeTemp),
    humidityBand: bandHumidity(e.humidity),
    pm25Band: bandPm25(e.pm25),
    ozoneBand: bandOzone(e.ozone),
    pollenWeed: pollenWeedFromRisk(e.pollenWeedRisk),
    smokeAtPoint: smoke,
    heatAlert,
  };
}

export type BuildFramesOptions = {
  /** When true, never mix synthetic usual-day frames */
  strict?: boolean;
  /** Inject demo baselines when logged usual-days are scarce (default true for talk demo) */
  supplementDemoBaselines?: boolean;
};

/**
 * Builds feature frames from diary logs.
 * Attacks = inhaler logs (mild/bad/null feeling). Baselines = feeling "ok" usual-day check-ins.
 */
export function buildFramesFromLogs(
  logs: AttackLogDTO[],
  options: BuildFramesOptions = {},
): { frames: FeatureFrame[]; meta: FramesBuildMeta } {
  const strict = options.strict ?? false;
  const supplement = options.supplementDemoBaselines ?? !strict;

  const sorted = [...logs].sort(
    (a, b) => new Date(a.loggedAt).getTime() - new Date(b.loggedAt).getTime(),
  );

  let nSkippedNoEnv = 0;
  const frames: FeatureFrame[] = [];

  for (const log of sorted) {
    const frame = attackLogToFrame(log);
    if (!frame) {
      nSkippedNoEnv += 1;
      continue;
    }
    frames.push(frame);
  }

  let nAttacks = frames.filter((f) => f.kind === "attack").length;
  let nBaselines = frames.filter((f) => f.kind === "baseline").length;
  let supplementedDemoBaselines = 0;
  let baselineNote =
    nBaselines > 0
      ? "Usual-day rows come from logs where you marked feeling “ok.”"
      : "No “ok” usual-day logs yet — correlation uses supplemented demo usual-days until you log quiet days.";

  if (supplement && nBaselines < 8 && nAttacks >= 1) {
    const demoBaselines = buildDemoFrames().filter((f) => f.kind === "baseline");
    supplementedDemoBaselines = demoBaselines.length;
    frames.push(...demoBaselines.map((f) => ({ ...f, id: `demo-baseline-${f.id}` })));
    if (nBaselines > 0 && supplementedDemoBaselines > 0) {
      baselineNote =
        "Your attack logs are real; usual-day rows are synthetic placeholders until you log feeling “ok.”";
    }
  }

  nAttacks = frames.filter((f) => f.kind === "attack").length;
  nBaselines = frames.filter((f) => f.kind === "baseline").length;

  return {
    frames,
    meta: {
      nLogs: logs.length,
      nSkippedNoEnv,
      nAttacks,
      nBaselines,
      supplementedDemoBaselines,
      baselineNote,
    },
  };
}
