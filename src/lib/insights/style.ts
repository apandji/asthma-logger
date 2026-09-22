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

/** Slight creativity bump for poetic; keep clinical tight for count fidelity. */
export function styleTemperature(band: StyleBand): number {
  switch (band) {
    case "clinical":
      return 0.1;
    case "plain":
      return 0.2;
    case "poetic":
      return 0.45;
  }
}

export function stylePromptBlock(band: StyleBand): string {
  const shared = [
    "Voice only — the lift table is ground truth.",
    "You MUST include the exact attack/usual counts for the top gated driver (e.g. 8 of 14 vs 3 of 40).",
    "Never invent drivers, counts, diagnoses, or predictions of an attack.",
    "Never say the weather caused the attack or that the lungs 'know' / 'remember' / 'warn'.",
    "Outdoor air context only.",
  ];

  let voice: string;
  switch (band) {
    case "clinical":
      voice = [
        "Register: CLINICAL.",
        "Write like a concise research note or chart review.",
        "Lead with the bin name and rates. Prefer numbers over metaphor.",
        "One or two tight sentences. No flourish.",
      ].join(" ");
      break;
    case "plain":
      voice = [
        "Register: PLAIN.",
        "Write like a clear diary coach — warm, short, no jargon wall.",
        "State the pattern in everyday words, then the counts.",
      ].join(" ");
      break;
    case "poetic":
      voice = [
        "Register: POETIC.",
        "You may use gentle metaphor about outdoor air, season, light, or time of day.",
        "Still embed the exact counts in the same headline (parentheses or dash is fine).",
        "Keep it under three sentences. No purple prose, no destiny language, no body-as-fate.",
      ].join(" ");
      break;
  }

  return ["Style:", voice, ...shared.map((r) => `- ${r}`)].join("\n");
}
