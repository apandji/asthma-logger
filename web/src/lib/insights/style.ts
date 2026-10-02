/** 0 = clinical, 100 = poetic. Voice only — never changes lift math. */
export type StyleScore = number;

export type StyleBand = "clinical" | "plain" | "poetic";

export function clampStyle(score: StyleScore): StyleScore {
  if (!Number.isFinite(score)) return 35;
  return Math.max(0, Math.min(100, Math.round(score)));
}

/** Stable bands so demos don't jitter at every slider tick. */
export function styleBand(score: StyleScore): StyleBand {
  const s = clampStyle(score);
  if (s <= 33) return "clinical";
  if (s <= 66) return "plain";
  return "poetic";
}

export function styleLabel(band: StyleBand): string {
  switch (band) {
    case "clinical":
      return "Clinical";
    case "plain":
      return "Plain";
    case "poetic":
      return "Poetic";
  }
}

/** Creativity by band — clinical stays tight; poetic can wander in diction. */
export function styleTemperature(band: StyleBand): number {
  switch (band) {
    case "clinical":
      return 0.05;
    case "plain":
      return 0.25;
    case "poetic":
      return 0.7;
  }
}

export type StyleExampleFacts = {
  binLabel: string;
  level: string;
  /** The template's plain clause, e.g. "ozone was high". */
  clause: string;
  attacksWith: number;
  nAttacks: number;
  baselinesWith: number;
  nBaselines: number;
};

/** Concrete few-shots using THIS diary's top row — the model copies register, not invented stats. Mirrored in iOS Style.swift. */
export function styleFewShot(band: StyleBand, f: StyleExampleFacts): string {
  if (band === "clinical") {
    return [
      "Example headline in THIS register (same facts, your voice must match this density):",
      `"${f.binLabel} ${f.level}: present on ${f.attacksWith} of ${f.nAttacks} inhaler uses and ${f.baselinesWith} of ${f.nBaselines} usual days. An association in your log, not a cause."`,
    ].join("\n");
  }

  if (band === "plain") {
    return [
      "Example headline in THIS register (same facts, your voice must match this warmth):",
      `"Here's what stands out: ${f.clause} on ${f.attacksWith} of the ${f.nAttacks} times you used your inhaler, and on only ${f.baselinesWith} of ${f.nBaselines} usual days."`,
    ].join("\n");
  }

  const clause = f.clause.charAt(0).toUpperCase() + f.clause.slice(1);
  return [
    "Example headline in THIS register (same facts, your voice must match this lyric shape):",
    `"Some days the outdoor air feels heavier. ${clause} on ${f.attacksWith} of the ${f.nAttacks} times you reached for your inhaler, and on just ${f.baselinesWith} of ${f.nBaselines} ordinary days. Not a cause, just something your log keeps noticing."`,
  ].join("\n");
}

export function stylePromptBlock(band: StyleBand, example?: StyleExampleFacts): string {
  const shared = [
    "CRITICAL: The three registers must sound OBVIOUSLY different. Do not write a bland middle sentence for every style.",
    "Voice only — the lift table is ground truth.",
    "You MUST include the exact counts for the top gated driver: how many of the times they used their inhaler, and how many usual days (e.g. 8 of 10 vs 3 of 24).",
    "Count inhaler uses as 'times you used your inhaler'. Never use the word 'attack'.",
    "Never state a ratio or multiplier like '3×' or 'twice as often'. Give the two counts instead.",
    "Never invent drivers, counts, diagnoses, or predictions.",
    "Never say the weather caused anything. Never say lungs know / remember / warn / whisper.",
    "Outdoor air context only.",
  ];

  let voice: string;
  switch (band) {
    case "clinical":
      voice =
        "Register: CLINICAL (sound like a short methods note). Precise and neutral: name the condition and level, then the two counts. Words like 'present on', 'inhaler uses', 'usual days', 'association'. No metaphors. No second-person coaching. One or two short sentences.";
      break;
    case "plain":
      voice =
        "Register: PLAIN (sound like a friend reading your log back to you). Use you/your. Short sentences, everyday words. No jargon (no 'prevalence', 'co-occurrence', 'lift'). No stock openers like 'Quick read'. Say what stands out, with the two counts in the same sentence.";
      break;
    case "poetic":
      voice =
        "Register: POETIC (a short lyric note, still honest). Open with one image of outdoor air, season, heat, haze, pollen or light, then land the exact counts. Vary rhythm. Allow one metaphor. Do NOT open with the pollutant name as a chart label. Max three sentences. No destiny / prophecy / body-as-fate.";
      break;
  }

  const parts = ["Style:", voice, ...shared.map((r) => `- ${r}`)];
  if (example) {
    parts.push("", styleFewShot(band, example));
  }
  return parts.join("\n");
}
