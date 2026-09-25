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
  "Outdoor air only — not a medical diagnosis. “Potentially triggered” means these showed up more on your attack logs than on usual days, not that they caused an attack.";

/** Zero-model narrator — always available on device. */
export function summarizeWithTemplate(input: NarratorInput): NarratorOutput {
  const signals = input.rows.filter((r) => r.gated || (r.lift > 1.25 && r.attacksWith >= 2));
  const top = signals.length > 0 ? signals : input.rows;

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

  const names = top.slice(0, 3).map((r) => labelDriver(r.bin, r.level));
  const lead = top[0];
  const liftLabel = formatLift(lead.lift);
  const early = !top.some((r) => r.gated);

  let headline = `Your attacks were potentially triggered by ${joinList(names)}.`;
  headline += ` ${labelDriver(lead.bin, lead.level)} showed up on ${lead.attacksWith} of ${input.nAttacks} attacks vs ${lead.baselinesWith} of ${input.nBaselines} usual days (~${liftLabel}×).`;
  if (early) {
    headline += " Early signal — more usual-day logs will tighten this.";
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

function joinList(parts: string[]): string {
  if (parts.length <= 1) return parts[0] ?? "unclear outdoor signals";
  if (parts.length === 2) return `${parts[0]} and ${parts[1]}`;
  return `${parts.slice(0, -1).join(", ")}, and ${parts[parts.length - 1]}`;
}

export function buildOllamaPrompt(input: NarratorInput): string {
  const top = input.rows.slice(0, 3);
  const driverIds = top.map((r) => `${r.bin}:${r.level}`);
  const human = top.map((r) => labelDriver(r.bin, r.level));
  const hasSignals = top.length > 0 && input.nAttacks > 0;

  const exampleHeadline = hasSignals
    ? `Your attacks were potentially triggered by ${joinList(human)}. ${labelDriver(top[0].bin, top[0].level)} showed up on ${top[0].attacksWith} of ${input.nAttacks} attacks vs ${top[0].baselinesWith} of ${input.nBaselines} usual days.`
    : `You have ${input.nAttacks} attack logs and ${input.nBaselines} usual-day samples — keep logging quiet days.`;

  return [
    "You narrate an asthma outdoor-air diary for the user.",
    "You receive a precomputed lift table. Numbers are already correct — do not invent counts or new drivers.",
    "",
    "Return ONLY one JSON object (no markdown, no prose outside JSON):",
    '{"headline":"...","caveat":"...","drivers":["ozone:high","heat_alert:yes"]}',
    "",
    "headline requirements:",
    '- Start like: "Your attacks were potentially triggered by X, Y, and Z."',
    "- Then one short sentence with the real counts for the #1 driver (attacksWith of nAttacks vs baselinesWith of nBaselines).",
    "- Name 1–3 drivers from the table using plain language (ozone, weed pollen, heat, afternoon, smoke-like air).",
    "- Keep headline under 320 characters. Put disclaimers ONLY in caveat — never in headline.",
    "",
    "caveat requirements:",
    '- One short line: outdoor air only, not a diagnosis, “potentially” means higher on attack days than usual days.',
    "",
    "drivers requirements:",
    `- Use ONLY ids from this list: ${JSON.stringify(driverIds.length ? driverIds : ["(none)"])}`,
    '- Never output the literal string "bin:level".',
    "",
    "Rules:",
    ...input.rules.map((r) => `- ${r}`),
    "",
    "Good example shape for THIS table:",
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

function sanitizeDrivers(
  raw: unknown,
  input: NarratorInput,
): string[] {
  const allowed = new Set(input.rows.map((r) => `${r.bin}:${r.level}`));
  const fromModel = Array.isArray(raw)
    ? raw.filter((d): d is string => typeof d === "string" && d !== "bin:level" && allowed.has(d))
    : [];
  if (fromModel.length > 0) return fromModel.slice(0, 3);
  return input.rows.slice(0, 3).map((r) => `${r.bin}:${r.level}`);
}

function headlineLooksUseless(headline: string, input: NarratorInput): boolean {
  const h = headline.toLowerCase();
  if (/need more usual days|need more attacks|draw more conclusions|based on a precomputed/i.test(h)) {
    return input.rows.length > 0 && input.nAttacks > 0;
  }
  if (!/potentially triggered|showed up|more often|lined up/i.test(h) && input.rows.length > 0) {
    // Vague titles like "Outdoor air quality and asthma…" with no drivers
    const mentionsDriver = input.rows.some(
      (r) =>
        h.includes(labelBin(r.bin).toLowerCase()) ||
        h.includes(r.bin.replaceAll("_", " ")) ||
        h.includes(r.level),
    );
    return !mentionsDriver;
  }
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

    let headline = parsed.headline.trim();
    const drivers = input ? sanitizeDrivers(parsed.drivers, input) : Array.isArray(parsed.drivers)
      ? parsed.drivers.filter((d): d is string => typeof d === "string" && d !== "bin:level")
      : [];

    if (input && headlineLooksUseless(headline, input)) {
      // Prefer template voice over Gemma's empty disclaimer.
      return {
        ...summarizeWithTemplate(input),
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
