export const FEELING_OPTIONS = [
  { value: "ok" as const, label: "ok", emoji: "🙂" },
  { value: "mild" as const, label: "mild", emoji: "😮‍💨" },
  { value: "bad" as const, label: "bad", emoji: "😣" },
] as const;

export type Feeling = (typeof FEELING_OPTIONS)[number]["value"];

export function feelingDisplay(feeling: string | null | undefined): string | null {
  if (!feeling || feeling === "skip") return null;
  const opt = FEELING_OPTIONS.find((f) => f.value === feeling);
  return opt ? `${opt.emoji} ${opt.label}` : feeling.replace(/_/g, " ");
}
