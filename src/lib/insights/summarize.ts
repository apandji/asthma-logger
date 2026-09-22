import type { LiftReport, NarratorInput, NarratorOutput } from "./types";
import { NARRATOR_RULES } from "./types";
import { formatLift } from "./lift";
import {
  clampStyle,
  styleBand,
  stylePromptBlock,
  type StyleBand,
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
  "Outdoor air only — not a medical diagnosis. Comparison to your usual logged days, not a prediction. Style changes voice, not the numbers.";

/** Zero-model narrator — always available on device; respects style bands. */
export function summarizeWithTemplate(input: NarratorInput): NarratorOutput {
  const score = clampStyle(input.styleScore ?? 35);
  const band = styleBand(score);
  const gated = input.rows.filter((r) => r.gated);
  const drivers = gated.slice(0, 3).map((r) => `${r.bin}:${r.level}`);

  if (gated.length === 0) {
    const headline =
      input.nBaselines < 12
        ? emptySampleHeadline(band, input.nAttacks, input.nBaselines)
        : emptyGateHeadline(band, input.nAttacks, input.nBaselines);
    return {
      headline,
      caveat: CAVEAT,
      drivers: [],
      source: "template",
      styleScore: score,
      styleBand: band,
    };
  }

  const top = gated[0];
  const second = gated[1];
  const liftLabel = formatLift(top.lift);
  const counts = `${top.attacksWith} of ${input.nAttacks} attacks vs ${top.baselinesWith} of ${input.nBaselines} usual days`;
  const headline = styledHeadline(band, {
    binLabel: labelBin(top.bin),
    level: top.level,
    counts,
    liftLabel,
    secondLabel: second ? `${labelBin(second.bin)} (${second.level})` : null,
    season: input.season,
  });

  return {
    headline,
    caveat: CAVEAT,
    drivers,
    source: "template",
    styleScore: score,
    styleBand: band,
  };
}

function emptySampleHeadline(band: StyleBand, attacks: number, baselines: number): string {
  if (band === "poetic") {
    return `The diary is still thin — ${attacks} attack marks and ${baselines} quiet-day samples. Keep a few ordinary days so the air has something honest to compare against.`;
  }
  if (band === "plain") {
    return `You have ${attacks} attack logs and ${baselines} usual-day samples. Keep logging quiet days so we can compare.`;
  }
  return `Insufficient baseline samples for association analysis (n_attack=${attacks}, n_usual=${baselines}). Continue usual-day logging.`;
}

function emptyGateHeadline(band: StyleBand, attacks: number, baselines: number): string {
  if (band === "poetic") {
    return `Nothing has repeated enough to speak of yet (${attacks} attacks, ${baselines} usual days). Patterns need more weather to echo.`;
  }
  if (band === "plain") {
    return `Nothing clears the sample gate yet (${attacks} attacks, ${baselines} usual days). Patterns need more repeats.`;
  }
  return `No gated associations (n_attack=${attacks}, n_usual=${baselines}). Raise sample counts before interpreting lift.`;
}

function styledHeadline(
  band: StyleBand,
  opts: {
    binLabel: string;
    level: string;
    counts: string;
    liftLabel: string;
    secondLabel: string | null;
    season: string | null;
  },
): string {
  const { binLabel, level, counts, liftLabel, secondLabel, season } = opts;

  if (band === "clinical") {
    let h = `${binLabel} ${level}: elevated co-occurrence — ${counts} (lift ≈ ${liftLabel}×).`;
    if (secondLabel) h += ` Secondary: ${secondLabel}.`;
    if (season) h += ` Season stratum: ${season}.`;
    return h;
  }

  if (band === "plain") {
    let h = `${binLabel} (${level}) showed up more on attack days — ${counts} (~${liftLabel}×).`;
    if (secondLabel) h += ` Also watching: ${secondLabel}.`;
    if (season) h += ` Season context: ${season}.`;
    return h;
  }

  // poetic
  let h = `When the outdoor air leans ${level} on ${binLabel.toLowerCase()}, your diary marks it more often — ${counts} (~${liftLabel}×).`;
  if (secondLabel) h += ` A quieter echo: ${secondLabel}.`;
  if (season) h += ` ${capitalize(season)} sits behind the pattern.`;
  return h;
}

function capitalize(s: string): string {
  return s.length ? s[0].toUpperCase() + s.slice(1) : s;
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

export function buildNarratorPrompt(input: NarratorInput): string {
  const score = clampStyle(input.styleScore ?? 35);
  const band = styleBand(score);

  return [
    "You write one honest insight for an asthma outdoor-air diary.",
    "You are given a precomputed lift table. Do not invent counts or new drivers.",
    'Reply with ONLY compact JSON: {"headline":"...","caveat":"...","drivers":["bin:level",...]}',
    "",
    stylePromptBlock(band),
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
