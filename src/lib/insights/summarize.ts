import type { LiftReport, NarratorInput, NarratorOutput } from "./types";
import { NARRATOR_RULES } from "./types";
import { formatLift } from "./lift";
import {
  clampStyle,
  styleBand,
  stylePromptBlock,
  type StyleBand,
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
    attacksWith: top.attacksWith,
    nAttacks: input.nAttacks,
    baselinesWith: top.baselinesWith,
    nBaselines: input.nBaselines,
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
    return `The book of quiet days is still missing pages — ${attacks} hard marks, ${baselines} ordinary ones. Leave a few calm afternoons in the log so the outdoor air has a fair chorus to answer.`;
  }
  if (band === "plain") {
    return `Here's where we are: ${attacks} attack logs and only ${baselines} usual-day samples. Log a few okay days and the comparison gets real.`;
  }
  return `Sample inadequacy: n_attack=${attacks}, n_usual=${baselines}. Association analysis deferred pending additional baseline observations.`;
}

function emptyGateHeadline(band: StyleBand, attacks: number, baselines: number): string {
  if (band === "poetic") {
    return `The weather has not yet rhymed often enough to quote (${attacks} attacks, ${baselines} usual days). Wait for the pattern to return like a season.`;
  }
  if (band === "plain") {
    return `Nothing clear yet — ${attacks} attacks and ${baselines} usual days, but no weather bin repeats enough to call out. Keep logging.`;
  }
  return `Null result under gating: n_attack=${attacks}, n_usual=${baselines}. No exposure level meets minimum cell counts for lift reporting.`;
}

function styledHeadline(
  band: StyleBand,
  opts: {
    binLabel: string;
    level: string;
    attacksWith: number;
    nAttacks: number;
    baselinesWith: number;
    nBaselines: number;
    counts: string;
    liftLabel: string;
    secondLabel: string | null;
    season: string | null;
  },
): string {
  const {
    binLabel,
    level,
    attacksWith,
    nAttacks,
    baselinesWith,
    nBaselines,
    counts,
    liftLabel,
    secondLabel,
    season,
  } = opts;

  if (band === "clinical") {
    let h = `Association signal: ${binLabel}=${level}. Attack-conditioned prevalence ${attacksWith}/${nAttacks}; usual-day prevalence ${baselinesWith}/${nBaselines}; crude lift ${liftLabel}×. Not causal.`;
    if (secondLabel) h += ` Secondary exposure: ${secondLabel}.`;
    if (season) h += ` Season stratum: ${season}.`;
    return h;
  }

  if (band === "plain") {
    let h = `Here's the pattern: ${binLabel.toLowerCase()} ran ${level} more often on days you logged an attack (${counts}, about ${liftLabel}×).`;
    if (secondLabel) h += ` Also showing up: ${secondLabel}.`;
    if (season) h += ` This is mostly a ${season} slice of your diary.`;
    return h;
  }

  const image = poeticImage(binLabel, level, season);
  let h = `${image} Your diary keeps answering the same outdoor weather — ${counts} (~${liftLabel}×).`;
  if (secondLabel) h += ` Underneath that, a softer rhyme: ${secondLabel}.`;
  return h;
}

function poeticImage(binLabel: string, level: string, season: string | null): string {
  const seasonBit = season ? ` in ${season}` : "";
  switch (binLabel) {
    case "Ozone":
      return level === "high"
        ? `Afternoon light that tastes a little sharp${seasonBit}.`
        : `A thinner sky${seasonBit}, ozone leaning ${level}.`;
    case "PM2.5":
      return level === "high"
        ? `Haze hangs low enough to feel${seasonBit}.`
        : `A dust-soft air${seasonBit}, particles ${level}.`;
    case "Weed pollen":
      return `Pollen weather — weed counts ${level}${seasonBit}.`;
    case "Temperature":
      return level === "hot"
        ? `Heat presses the outdoor hour${seasonBit}.`
        : `The outdoor temperature sits ${level}${seasonBit}.`;
    case "Humidity":
      return `The air turns ${level} with moisture${seasonBit}.`;
    case "Smoke-like air":
      return `A smoky edge on the outdoor air${seasonBit}.`;
    case "Heat alert":
      return `The forecast names the heat out loud${seasonBit}.`;
    case "Time of day":
      return `Those ${level} hours keep returning${seasonBit}.`;
    default:
      return `Outdoor air marked ${level} for ${binLabel.toLowerCase()}${seasonBit}.`;
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
