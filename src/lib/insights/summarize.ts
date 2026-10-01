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
        ? `You have ${input.nAttacks} attack logs and ${input.nBaselines} usual-day samples. Keep logging quiet days so we can compare.`
        : `Nothing clears the sample gate yet (${input.nAttacks} attacks, ${input.nBaselines} usual days). Patterns need more repeats.`;
    return {
      headline,
      caveat: CAVEAT,
      drivers: [],
      source: "template",
    };
  }

  const top = gated[0];
  const second = gated[1];
  const liftLabel = formatLift(top.lift);
  let headline = `${labelBin(top.bin)} (${top.level}) showed up on ${top.attacksWith} of ${input.nAttacks} attacks vs ${top.baselinesWith} of ${input.nBaselines} usual days (~${liftLabel}×).`;
  if (second) {
    headline += ` Next: ${labelBin(second.bin)} (${second.level}).`;
  }
  if (input.season) {
    headline += ` Season context: ${input.season}.`;
  }

  return {
    headline,
    caveat: CAVEAT,
    drivers,
    source: "template",
  };
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
