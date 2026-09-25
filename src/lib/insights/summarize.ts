import type { LiftReport, NarratorInput, NarratorOutput } from "./types";
import { NARRATOR_RULES } from "./types";
import { formatLift } from "./lift";

/** Human labels for bins — shared by template + LLM prompt. */
export function labelBin(bin: string): string {
  switch (bin) {
    case "pm25":
      return "PM2.5";
    case "ozone":
      return "ozone";
    case "pollen_weed":
      return "weed pollen";
    case "temp":
      return "heat";
    case "humidity":
      return "humidity";
    case "smoke_at_point":
      return "smoke-like air";
    case "heat_alert":
      return "heat alerts";
    case "hour":
      return "time of day";
    default:
      return bin.replaceAll("_", " ");
  }
}

export function labelDriver(bin: string, level: string): string {
  if (bin === "hour") return `${level}`;
  if (bin === "smoke_at_point" || bin === "heat_alert") return labelBin(bin);
  if (bin === "temp" && level === "hot") return "hot temperatures";
  if (bin === "temp" && level === "cold") return "cold temperatures";
  return `${labelBin(bin)} (${level})`;
}

/**
 * Prefer gated rows; otherwise the strongest lift signals so the narrator
 * still has something concrete to say on small demo diaries.
 */
export function pickNarratorRows(report: LiftReport): NarratorInput["rows"] {
  const source =
    report.gatedRows.length > 0
      ? report.gatedRows
      : report.rows.filter((r) => r.lift > 1.25 && r.attacksWith >= 2).slice(0, 5);

  const rows = (source.length > 0 ? source : report.rows.slice(0, 5)).map((r) => ({
    bin: r.bin,
    level: r.level,
    attacksWith: r.attacksWith,
    baselinesWith: r.baselinesWith,
    attackRate: r.attackRate,
    baselineRate: r.baselineRate,
    lift: Number.isFinite(r.lift) ? r.lift : 99,
    gated: r.gated,
  }));

  return rows;
}

export function toNarratorInput(report: LiftReport): NarratorInput {
  return {
    nAttacks: report.nAttacks,
    nBaselines: report.nBaselines,
    season: report.seasonHint,
    rows: pickNarratorRows(report),
    rules: [...NARRATOR_RULES],
  };
}

const CAVEAT =
  "Outdoor air only — not a medical diagnosis. Comparison to your usual logged days, not a prediction.";

function joinList(parts: string[]): string {
  if (parts.length <= 1) return parts[0] ?? "unclear outdoor signals";
  if (parts.length === 2) return `${parts[0]} and ${parts[1]}`;
  return `${parts.slice(0, -1).join(", ")}, and ${parts[parts.length - 1]}`;
}

function topSignals(input: NarratorInput) {
  const signals = input.rows.filter((r) => r.gated || (r.lift > 1.25 && r.attacksWith >= 2));
  return signals.length > 0 ? signals : input.rows;
}

/** Dry lift-table voice — the “stats / association” side of the demo. */
export function summarizeWithTemplate(input: NarratorInput): NarratorOutput {
  const top = topSignals(input);

  if (top.length === 0 || input.nAttacks === 0) {
    return {
      headline:
        input.nBaselines < 8
          ? `You have ${input.nAttacks} attack logs and ${input.nBaselines} usual-day samples. Keep logging quiet days so we can compare.`
          : `Nothing clear yet (${input.nAttacks} attacks, ${input.nBaselines} usual days). Patterns need more repeats.`,
      caveat: CAVEAT,
      drivers: [],
      source: "template",
    };
  }

  const lead = top[0];
  const second = top[1];
  const liftLabel = formatLift(lead.lift);
  let headline = `${labelBin(lead.bin)} (${lead.level}) showed up on ${lead.attacksWith} of ${input.nAttacks} attacks vs ${lead.baselinesWith} of ${input.nBaselines} usual days (~${liftLabel}×).`;
  if (second) {
    headline += ` Next: ${labelBin(second.bin)} (${second.level}).`;
  }
  if (input.season) {
    headline += ` Season context: ${input.season}.`;
  }

  return {
    headline,
    caveat: CAVEAT,
    drivers: top.slice(0, 3).map((r) => `${r.bin}:${r.level}`),
    source: "template",
  };
}

/**
 * Warm diary voice used when Gemma hedges into empty disclaimers.
 * Must sound obviously different from summarizeWithTemplate.
 */
export function summarizeWithNarrativeFallback(input: NarratorInput): NarratorOutput {
  const top = topSignals(input);
  if (top.length === 0 || input.nAttacks === 0) {
    return summarizeWithTemplate(input);
  }
  const names = top.slice(0, 3).map((r) => labelDriver(r.bin, r.level));
  const lead = top[0];
  const liftLabel = formatLift(lead.lift);
  let headline = `Looking at your diary, the harder days keep lining up with ${joinList(names)}.`;
  headline += ` On attack logs, ${labelDriver(lead.bin, lead.level)} shows up about ${liftLabel}× as often as on quieter days (${lead.attacksWith}/${input.nAttacks} vs ${lead.baselinesWith}/${input.nBaselines}).`;
  if (input.season) {
    headline += ` That pattern is showing up in ${input.season}.`;
  }

  return {
    headline,
    caveat: CAVEAT,
    drivers: top.slice(0, 3).map((r) => `${r.bin}:${r.level}`),
    source: "template",
  };
}

export function buildOllamaPrompt(input: NarratorInput): string {
  const top = input.rows.slice(0, 3);
  const driverIds = top.map((r) => `${r.bin}:${r.level}`);
  const human = top.map((r) => labelDriver(r.bin, r.level));
  const lead = top[0];
  const liftLabel = lead ? formatLift(lead.lift) : "—";

  const exampleHeadline = lead
    ? `Looking at your diary, harder days keep lining up with ${joinList(human)} outdoors. ${labelDriver(lead.bin, lead.level)} shows up about ${liftLabel}× as often on attack logs (${lead.attacksWith} of ${input.nAttacks}) as on quieter days (${lead.baselinesWith} of ${input.nBaselines}).`
    : `You have ${input.nAttacks} attack logs and ${input.nBaselines} usual-day samples — keep logging quiet days.`;

  return [
    "You are the warm diary narrator for an asthma outdoor-air app.",
    "A separate Template button already prints dry lift stats. YOUR job is different: sound like a thoughtful friend reading the diary aloud.",
    "You receive a precomputed lift table. Numbers are ground truth — do not invent counts or new drivers.",
    "",
    "Return ONLY one JSON object (no markdown):",
    '{"headline":"...","caveat":"...","drivers":["ozone:high","pm25:moderate"]}',
    "",
    "headline voice (MUST differ from dry stats):",
    '- Open like a person: "Looking at your diary…", "On your harder days…", "What stands out is…"',
    "- Name 1–3 outdoor signals in plain language (ozone, weed pollen, heat, afternoon, smoke-like air).",
    "- Include the real #1 counts once, woven into the sentence (e.g. 8 of 10 vs 0 of 10), not as a spreadsheet readback.",
    '- Do NOT start with "Your attacks were potentially triggered by".',
    '- Do NOT start with "Ozone (high) showed up on N of M" — that is the Template voice.',
    "- Do NOT say weather caused an attack, or predict the next one.",
    "- Keep under 340 characters. Put hedging ONLY in caveat.",
    "",
    "caveat: one short outdoor-air / not-a-diagnosis line.",
    "",
    "drivers:",
    `- ONLY ids from: ${JSON.stringify(driverIds.length ? driverIds : ["(none)"])}`,
    '- Never output the literal string "bin:level".',
    "",
    "Rules:",
    ...input.rules.map((r) => `- ${r}`),
    "",
    "Example in the right register for THIS table:",
    JSON.stringify(
      {
        headline: exampleHeadline,
        caveat: CAVEAT,
        drivers: driverIds.slice(0, 3),
      },
      null,
      2,
    ),
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

function sanitizeDrivers(raw: unknown, input: NarratorInput): string[] {
  const allowed = new Set(input.rows.map((r) => `${r.bin}:${r.level}`));
  const fromModel = Array.isArray(raw)
    ? raw.filter((d): d is string => typeof d === "string" && d !== "bin:level" && allowed.has(d))
    : [];
  if (fromModel.length > 0) return fromModel.slice(0, 3);
  return input.rows.slice(0, 3).map((r) => `${r.bin}:${r.level}`);
}

function headlineLooksUseless(headline: string, input: NarratorInput): boolean {
  const h = headline.toLowerCase();
  if (/need more usual days|need more attacks|draw more conclusions|based on a precomputed|does not claim causation/i.test(h)) {
    return input.rows.length > 0 && input.nAttacks > 0;
  }
  if (input.rows.length === 0) return false;
  const mentionsDriver = input.rows.some(
    (r) =>
      h.includes(labelBin(r.bin).toLowerCase()) ||
      h.includes(r.bin.replaceAll("_", " ")) ||
      h.includes(r.level),
  );
  // Vague titles with no outdoor signal named
  if (!mentionsDriver && h.length < 120) return true;
  return false;
}

export function parseNarratorJson(
  text: string,
  model: string,
  latencyMs: number,
  source: NarratorOutput["source"] = "ollama",
  input?: NarratorInput,
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

    const headline = parsed.headline.trim();
    const drivers = input
      ? sanitizeDrivers(parsed.drivers, input)
      : Array.isArray(parsed.drivers)
        ? parsed.drivers.filter((d): d is string => typeof d === "string" && d !== "bin:level")
        : [];

    if (input && headlineLooksUseless(headline, input)) {
      return {
        ...summarizeWithNarrativeFallback(input),
        source,
        model: `${model} (repaired)`,
        latencyMs,
      };
    }

    return {
      headline,
      caveat:
        typeof parsed.caveat === "string" && parsed.caveat.trim()
          ? parsed.caveat.trim()
          : CAVEAT,
      drivers,
      source,
      model,
      latencyMs,
    };
  } catch {
    return null;
  }
}
