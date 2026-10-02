import type { LiftReport, NarratorInput, NarratorOutput } from "./types";
import { NARRATOR_RULES } from "./types";
import { formatLift } from "./lift";
import {
  clampStyle,
  styleBand,
  stylePromptBlock,
  type StyleExampleFacts,
  type StyleScore,
} from "./style";

export function toNarratorInput(report: LiftReport, styleScore: StyleScore = 35): NarratorInput {
  const rows = (report.gatedRows.length > 0 ? report.gatedRows : report.rows.slice(0, 5)).map(
    (r) => ({
      bin: r.bin,
      level: r.level,
      attacksWith: r.attacksWith,
      baselinesWith: r.baselinesWith,
      attackRate: r.attackRate,
      baselineRate: r.baselineRate,
      lift: Number.isFinite(r.lift) ? r.lift : 99,
      gated: r.gated,
    }),
  );

  return {
    nAttacks: report.nAttacks,
    nBaselines: report.nBaselines,
    season: report.seasonHint,
    rows,
    rules: [...NARRATOR_RULES],
    styleScore: clampStyle(styleScore),
  };
}

const CAVEAT =
  "Outdoor air only — not a medical diagnosis. Comparison to your usual logged days, not a prediction.";

/**
 * Fixed factual narrator — always available on device.
 * Style score is ignored here; only Gemma / Ollama use clinical→poetic voice.
 */
export function summarizeWithTemplate(input: NarratorInput): NarratorOutput {
  const gated = input.rows.filter((r) => r.gated);
  const drivers = gated.slice(0, 3).map((r) => `${r.bin}:${r.level}`);

  if (gated.length === 0) {
    const headline =
      input.nBaselines < 12
        ? `You've used your inhaler ${input.nAttacks} times and logged ${input.nBaselines} usual moments. Keep logging usual days so there's something to compare.`
        : `Nothing stands out yet (${input.nAttacks} inhaler uses, ${input.nBaselines} usual days). Patterns need more repeats.`;
    return {
      headline,
      caveat: CAVEAT,
      drivers: [],
      source: "template",
    };
  }

  // Plain counts, no ratio: "8 of the 10 times you used your inhaler, ozone was high. …"
  const top = gated[0];
  const second = gated[1];
  let headline = `${top.attacksWith} of the ${input.nAttacks} times you used your inhaler, ${conditionClause(top.bin, top.level)}.`;
  headline +=
    top.baselinesWith === 0
      ? ` On usual days, that never happened (0 of ${input.nBaselines}).`
      : ` On usual days, that only happened ${top.baselinesWith} of ${input.nBaselines} times.`;
  if (second) {
    headline += ` Also common: ${conditionClause(second.bin, second.level)}.`;
  }
  if (input.season) {
    headline += ` Most of these logs are from ${input.season}.`;
  }

  return {
    headline,
    caveat: CAVEAT,
    drivers,
    source: "template",
  };
}

/** One bin level as a plain clause, e.g. "ozone was high", "it was evening". Mirrored in iOS `Narrator.clause`. */
export function conditionClause(bin: string, level: string): string {
  switch (bin) {
    case "pm25":
      return `PM2.5 was ${level}`;
    case "ozone":
      return `ozone was ${level}`;
    case "pollen_weed":
      return level === "none" ? "there was no weed pollen" : `weed pollen was ${level}`;
    case "temp":
      return `it was ${level} out`;
    case "humidity":
      return level === "ok" ? "humidity was normal" : `it was ${level}`;
    case "smoke_at_point":
      return level === "yes" ? "there were signs of smoke in the air" : "there were no signs of smoke in the air";
    case "heat_alert":
      return level === "yes" ? "there was a heat alert" : "there was no heat alert";
    case "hour":
      return `it was ${level}`;
    default:
      return `${labelBin(bin).toLowerCase()} was ${level}`;
  }
}

export function labelBin(bin: string): string {
  switch (bin) {
    case "pm25":
      return "PM2.5";
    case "ozone":
      return "Ozone";
    case "pollen_weed":
      return "Weed pollen";
    case "temp":
      return "Temperature";
    case "humidity":
      return "Humidity";
    case "smoke_at_point":
      return "Smoke-like air";
    case "heat_alert":
      return "Heat alert";
    case "hour":
      return "Time of day";
    default:
      return bin;
  }
}

/** @deprecated use buildNarratorPrompt */
export function buildOllamaPrompt(input: NarratorInput): string {
  return buildNarratorPrompt(input);
}

function exampleFactsFromInput(input: NarratorInput): StyleExampleFacts | undefined {
  const top = input.rows.find((r) => r.gated) ?? input.rows[0];
  if (!top) return undefined;
  return {
    binLabel: labelBin(top.bin),
    level: top.level,
    attacksWith: top.attacksWith,
    nAttacks: input.nAttacks,
    baselinesWith: top.baselinesWith,
    nBaselines: input.nBaselines,
    liftLabel: formatLift(top.lift),
  };
}

export function buildNarratorPrompt(input: NarratorInput): string {
  const score = clampStyle(input.styleScore ?? 35);
  const band = styleBand(score);
  const example = exampleFactsFromInput(input);

  return [
    "You write one honest insight for an asthma outdoor-air diary.",
    "You are given a precomputed lift table. Do not invent counts or new drivers.",
    'Reply with ONLY compact JSON: {"headline":"...","caveat":"...","drivers":["bin:level",...]}',
    "",
    "IMPORTANT: clinical / plain / poetic must be unmistakably different registers.",
    "If you write the same sentence shape for every style, you fail the task.",
    "",
    stylePromptBlock(band, example),
    "",
    "Rules:",
    ...input.rules.map((r) => `- ${r}`),
    "",
    `styleScore=${score} styleBand=${band}`,
    "",
    "Table JSON:",
    JSON.stringify(
      {
        nAttacks: input.nAttacks,
        nBaselines: input.nBaselines,
        season: input.season,
        rows: input.rows,
      },
      null,
      2,
    ),
  ].join("\n");
}

export function parseNarratorJson(
  text: string,
  model: string,
  latencyMs: number,
  source: NarratorOutput["source"] = "ollama",
  styleScore?: StyleScore,
): NarratorOutput | null {
  const trimmed = text.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const parsed = JSON.parse(trimmed.slice(start, end + 1)) as {
      headline?: unknown;
      caveat?: unknown;
      drivers?: unknown;
    };
    if (typeof parsed.headline !== "string" || !parsed.headline.trim()) return null;
    const score = clampStyle(styleScore ?? 35);
    return {
      headline: parsed.headline.trim(),
      caveat:
        typeof parsed.caveat === "string" && parsed.caveat.trim()
          ? parsed.caveat.trim()
          : CAVEAT,
      drivers: Array.isArray(parsed.drivers)
        ? parsed.drivers.filter((d): d is string => typeof d === "string")
        : [],
      source,
      model,
      latencyMs,
      styleScore: score,
      styleBand: styleBand(score),
    };
  } catch {
    return null;
  }
}
