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
  attacksWith: number;
  nAttacks: number;
  baselinesWith: number;
  nBaselines: number;
  liftLabel: string;
};

/** Concrete few-shots using THIS diary's top row — Gemma copies register, not invented stats. */
export function styleFewShot(band: StyleBand, f: StyleExampleFacts): string {
  const counts = `${f.attacksWith} of ${f.nAttacks} vs ${f.baselinesWith} of ${f.nBaselines}`;
  const bin = f.binLabel;
  const lvl = f.level;

  if (band === "clinical") {
    return [
      "Example headline in THIS register (same facts, your voice must match this density):",
      `"Association signal: ${bin}=${lvl}. Attack-conditioned prevalence ${f.attacksWith}/${f.nAttacks}; usual-day prevalence ${f.baselinesWith}/${f.nBaselines}; crude lift ${f.liftLabel}×. Not causal."`,
    ].join("\n");
  }

  if (band === "plain") {
    return [
      "Example headline in THIS register (same facts, your voice must match this warmth):",
      `"Quick read: ${bin.toLowerCase()} was ${lvl} a lot more often when you logged an attack (${counts} usual-day comparison, about ${f.liftLabel}×). Outdoor air only — not a diagnosis."`,
    ].join("\n");
  }

  return [
    "Example headline in THIS register (same facts, your voice must match this lyric shape):",
    `"There is a weather that keeps finding the hard days — ${lvl} ${bin.toLowerCase()} in the outdoor air — and your log keeps answering (${counts}; ~${f.liftLabel}×). Not fate. Just a rhyme the diary keeps humming."`,
  ].join("\n");
}

export function stylePromptBlock(band: StyleBand, example?: StyleExampleFacts): string {
  const shared = [
    "CRITICAL: The three registers must sound OBVIOUSLY different. Do not write a bland middle sentence for every style.",
    "Voice only — the lift table is ground truth.",
    "You MUST include the exact attack/usual counts for the top gated driver (e.g. 8 of 14 vs 3 of 40).",
    "Never invent drivers, counts, diagnoses, or predictions of an attack.",
    "Never say weather caused the attack. Never say lungs know / remember / warn / whisper.",
    "Outdoor air context only.",
  ];

  let voice: string;
  switch (band) {
    case "clinical":
      voice = [
        "Register: CLINICAL (sound like a methods note).",
        "Use technical diction: prevalence, co-occurrence, lift, conditioned on attack days, usual-day sample.",
        "Lead with the exposure name and level. Prefer fractions (8/14) and '×' lift.",
        "No metaphors. No second-person coaching. One dense sentence preferred; max two.",
        "Forbidden words: 'weather leans', 'echo', 'humming', 'hard days', 'quick read'.",
      ].join(" ");
      break;
    case "plain":
      voice = [
        "Register: PLAIN (sound like a friend summarizing your diary).",
        "Start with 'Quick read:' or 'Here's the pattern:'. Use you/your.",
        "Everyday words only — no 'prevalence', 'co-occurrence', 'stratum', 'crude lift'.",
        "Say the pattern in one plain sentence, then the counts in the same breath.",
        "No metaphor, no research jargon.",
      ].join(" ");
      break;
    case "poetic":
      voice = [
        "Register: POETIC (sound like a short lyric essay, still honest).",
        "Open with imagery about outdoor air, season, heat, haze, pollen, afternoon light — then land the exact counts.",
        "Vary sentence rhythm. Allow one metaphor. Prefer sensory language over clinical nouns.",
        "Do NOT open with the pollutant name as a chart label. Do NOT use 'Quick read', 'prevalence', or 'co-occurrence'.",
        "Still include exact counts before the end. Max three sentences. No destiny / prophecy / body-as-fate.",
      ].join(" ");
      break;
  }

  const parts = ["Style:", voice, ...shared.map((r) => `- ${r}`)];
  if (example) {
    parts.push("", styleFewShot(band, example));
  }
  return parts.join("\n");
}
