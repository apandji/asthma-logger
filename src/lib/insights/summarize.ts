import type { LiftReport, NarratorInput, NarratorOutput } from "./types";
import { NARRATOR_RULES } from "./types";
import { formatLift } from "./lift";

export function toNarratorInput(report: LiftReport): NarratorInput {
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
  };
}

/** Zero-model narrator — always available on device. */
export function summarizeWithTemplate(input: NarratorInput): NarratorOutput {
  const gated = input.rows.filter((r) => r.gated);
  const caveat = "Outdoor air only — not a medical diagnosis. Comparison to your usual logged days, not a prediction.";

  if (gated.length === 0) {
    return {
      headline:
        input.nBaselines < 12
          ? `You have ${input.nAttacks} attack logs and ${input.nBaselines} usual-day samples. Keep logging quiet days so we can compare.`
          : `Nothing clears the sample gate yet (${input.nAttacks} attacks, ${input.nBaselines} usual days). Patterns need more repeats.`,
      caveat,
      drivers: [],
      source: "template",
    };
  }

  const top = gated[0];
  const liftLabel = formatLift(top.lift);
  const second = gated[1];
  let headline = `${labelBin(top.bin)} (${top.level}) showed up on ${top.attacksWith} of ${input.nAttacks} attacks vs ${top.baselinesWith} of ${input.nBaselines} usual days (~${liftLabel}×).`;
  if (second) {
    headline += ` Next: ${labelBin(second.bin)} (${second.level}).`;
  }
  if (input.season) {
    headline += ` Season context: ${input.season}.`;
  }

  return {
    headline,
    caveat,
    drivers: gated.slice(0, 3).map((r) => `${r.bin}:${r.level}`),
    source: "template",
  };
}

function labelBin(bin: string): string {
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

export function buildOllamaPrompt(input: NarratorInput): string {
  return [
    "You write one honest insight for an asthma outdoor-air diary.",
    "You are given a precomputed lift table. Do not invent counts or new drivers.",
    "Reply with ONLY compact JSON: {\"headline\":\"...\",\"caveat\":\"...\",\"drivers\":[\"bin:level\",...]}",
    "",
    "Rules:",
    ...input.rules.map((r) => `- ${r}`),
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

export function parseNarratorJson(text: string, model: string, latencyMs: number): NarratorOutput | null {
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
    return {
      headline: parsed.headline.trim(),
      caveat:
        typeof parsed.caveat === "string" && parsed.caveat.trim()
          ? parsed.caveat.trim()
          : "Outdoor air only — not a medical diagnosis.",
      drivers: Array.isArray(parsed.drivers)
        ? parsed.drivers.filter((d): d is string => typeof d === "string")
        : [],
      source: "ollama",
      model,
      latencyMs,
    };
  } catch {
    return null;
  }
}
