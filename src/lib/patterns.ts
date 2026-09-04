/**
 * Pattern recognition prototype.
 *
 * Compares the hours a user reached for their inhaler against "ordinary hours" at the
 * same places, and turns anything that stands out into a plain sentence:
 *
 *   "You reached for your inhaler when the air was Moderate or worse in 7 of 12 logs —
 *    58% of your logs vs 21% of ordinary hours near you."
 *
 * Pure functions only; no fetch, no Prisma. Everything here is correlation over a
 * personal diary, not medical advice, and the copy says so.
 */
import { wildfireDisasterHits } from "./ambee";
import { isLocalAirSmoky } from "./hazard-copy";
import type { AttackLogDTO } from "./types";

/** One model hour at a place. Values are Open-Meteo hourly, °F / mph / µg/m³. */
export type HourSample = {
  /** Start of hour, unix ms UTC. */
  t: number;
  pm25: number | null;
  aqi: number | null;
  tempF: number | null;
  dewF: number | null;
  rhPct: number | null;
  windMph: number | null;
  /** Local hour 0–23 in the user's timezone; filled in by the caller. */
  localHour?: number;
};

/** Signals we only have for attack hours (from the app's own enrichment). */
export type AttackFlags = {
  smoke: boolean;
  fireWeather: boolean;
  heatAlert: boolean;
  coldAlert: boolean;
  airAlert: boolean;
  stormAlert: boolean;
  pollenHigh: boolean;
  inversion: boolean;
};

export type AttackSample = {
  logId: string;
  loggedAt: string;
  /** Matched model hour at the log's place; null if outside the history window. */
  hour: HourSample | null;
  flags: AttackFlags;
};

export type PatternKind = "stands_out" | "descriptive" | "no_signal";

export type PatternStatement = {
  key: string;
  kind: PatternKind;
  text: string;
  count: number;
  total: number;
  /** Share of ordinary hours with the same condition, 0–1. Null when not comparable. */
  baseShare: number | null;
  /** attackShare / baseShare. Null when not comparable. */
  lift: number | null;
};

export type PatternReport = {
  totalLogs: number;
  /** Logs that matched a model hour (inside the history window). */
  matchedLogs: number;
  baselineHours: number;
  places: number;
  maturity: "locked" | "early" | "emerging" | "solid";
  statements: PatternStatement[];
  note: string;
};

/** Below this many logs we say nothing at all. */
export const MIN_LOGS = 5;
/** A condition must show up in at least this many logs to be called a pattern. */
export const MIN_HITS = 3;

const Z90 = 1.645;

/** Wilson score interval lower bound — keeps tiny samples from sounding certain. */
export function wilsonLower(hits: number, n: number, z = Z90): number {
  if (n <= 0) return 0;
  const p = hits / n;
  const z2 = z * z;
  const denom = 1 + z2 / n;
  const centre = p + z2 / (2 * n);
  const margin = z * Math.sqrt((p * (1 - p)) / n + z2 / (4 * n * n));
  return Math.max(0, (centre - margin) / denom);
}

export function wilsonUpper(hits: number, n: number, z = Z90): number {
  if (n <= 0) return 1;
  const p = hits / n;
  const z2 = z * z;
  const denom = 1 + z2 / n;
  const centre = p + z2 / (2 * n);
  const margin = z * Math.sqrt((p * (1 - p)) / n + z2 / (4 * n * n));
  return Math.min(1, (centre + margin) / denom);
}

// ---------------------------------------------------------------------------
// Features
// ---------------------------------------------------------------------------

type HourFeature = {
  key: string;
  /** Completes "You reached for your inhaler when …". */
  phrase: string;
  /** Subject for the negative sentence, e.g. "Heat". */
  subject: string;
  /** true / false, or null when the input is missing. */
  test: (h: HourSample) => boolean | null;
  /** Optional sentence override for features where "when …" reads badly. */
  standsOut?: (hits: number, n: number, share: number, baseShare: number) => string;
};

const num = (v: number | null | undefined): v is number => v != null && Number.isFinite(v);
const pct = (x: number) => `${Math.round(x * 100)}%`;
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function hourBucket(h: number): "night" | "morning" | "midday" | "afternoon" | "evening" {
  if (h < 6) return "night";
  if (h < 11) return "morning";
  if (h < 15) return "midday";
  if (h < 19) return "afternoon";
  return "evening";
}

const TIME_PHRASES: Record<ReturnType<typeof hourBucket>, string> = {
  night: "overnight (midnight–6 am)",
  morning: "in the morning (6–11 am)",
  midday: "around midday (11 am–3 pm)",
  afternoon: "in the late afternoon (3–7 pm)",
  evening: "in the evening (7 pm–midnight)",
};

/** Conditions we can test on both attack hours and ordinary hours. */
export const HOUR_FEATURES: HourFeature[] = [
  {
    key: "air_moderate",
    phrase: "the air was Moderate or worse (AQI 51+)",
    subject: "Moderate air",
    test: (h) => (num(h.aqi) ? h.aqi >= 51 : num(h.pm25) ? h.pm25 >= 12 : null),
  },
  {
    key: "air_usg",
    phrase: "the air was unhealthy for sensitive groups (AQI 101+)",
    subject: "Unhealthy air",
    test: (h) => (num(h.aqi) ? h.aqi >= 101 : num(h.pm25) ? h.pm25 >= 35.5 : null),
  },
  {
    key: "hot",
    phrase: "it was hot (85°F or more)",
    subject: "Heat",
    test: (h) => (num(h.tempF) ? h.tempF >= 85 : null),
  },
  {
    key: "cold",
    phrase: "it was cold (35°F or below)",
    subject: "Cold",
    test: (h) => (num(h.tempF) ? h.tempF <= 35 : null),
  },
  {
    key: "muggy",
    phrase: "the air was muggy (dew point 65°F+)",
    subject: "Humidity",
    test: (h) => (num(h.dewF) ? h.dewF >= 65 : null),
  },
  {
    key: "dry",
    phrase: "the air was dry (humidity under 30%)",
    subject: "Dry air",
    test: (h) => (num(h.rhPct) ? h.rhPct < 30 : null),
  },
  {
    key: "windy",
    phrase: "it was windy (15+ mph)",
    subject: "Wind",
    test: (h) => (num(h.windMph) ? h.windMph >= 15 : null),
  },
  ...(["night", "morning", "midday", "afternoon", "evening"] as const).map<HourFeature>((b) => ({
    key: `time_${b}`,
    phrase: TIME_PHRASES[b],
    subject: "Time of day",
    test: (h) => (h.localHour == null ? null : hourBucket(h.localHour) === b),
    standsOut: (hits, n, share) =>
      `Your inhaler use clusters ${TIME_PHRASES[b]}: ${hits} of ${n} logs (${pct(share)}), far more than that window's share of the day.`,
  })),
];

type FlagFeature = { key: keyof AttackFlags; phrase: string };

/** Conditions we only know for attack hours — reported as counts, never as lift. */
export const FLAG_FEATURES: FlagFeature[] = [
  { key: "smoke", phrase: "wildfire smoke was likely in the air" },
  { key: "fireWeather", phrase: "a fire-weather warning was in effect" },
  { key: "heatAlert", phrase: "a heat advisory was in effect" },
  { key: "coldAlert", phrase: "a cold or freeze alert was in effect" },
  { key: "airAlert", phrase: "an air-quality alert was in effect" },
  { key: "stormAlert", phrase: "a storm warning was in effect" },
  { key: "pollenHigh", phrase: "pollen was High or worse" },
  { key: "inversion", phrase: "air may have been trapped near the ground" },
];

// ---------------------------------------------------------------------------
// Attack-side extraction from the app's own enrichment
// ---------------------------------------------------------------------------

export function attackFlags(log: AttackLogDTO): AttackFlags {
  const snap = log.snapshot?.v === 2 ? log.snapshot : null;
  const storm = log.stormSummary ?? "";
  const fire = `${log.wildfireSummary ?? ""} | ${snap?.free.wildfire ?? ""} | ${snap?.ambee.wildfire ?? ""}`;
  const credibleWf = snap ? wildfireDisasterHits(snap.ambee.disasters) : [];
  const airSmoky = isLocalAirSmoky({
    pm25: snap?.free.pm25 ?? snap?.ambee.pm25 ?? null,
    aqi: log.aqi,
    nwsSmoke: /smoke/i.test(fire) || /smoke/i.test(storm),
  });
  const smoke =
    /regional smoke|smoke advisory/i.test(fire) ||
    (airSmoky && credibleWf.some((h) => h.km == null || h.km <= 80)) ||
    (log.hasWildfireNearby && /smoke/i.test(fire));

  const pollen = snap?.ambee.pollen ?? snap?.free.pollen ?? null;
  const pollenHigh = [pollen?.treeRisk, pollen?.grassRisk, pollen?.weedRisk].some((r) =>
    /high/i.test(r ?? ""),
  );

  return {
    smoke,
    fireWeather: /red flag|fire weather/i.test(fire) || /red flag|fire weather/i.test(storm),
    heatAlert: log.hasStormAlert && /heat/i.test(storm),
    coldAlert: log.hasStormAlert && /cold|freeze|frost|wind chill|winter/i.test(storm),
    airAlert: log.hasStormAlert && /air quality|air stagnation/i.test(storm),
    stormAlert: log.hasStormAlert && /thunder|tornado|severe|high wind|wind advisory|flood/i.test(storm),
    pollenHigh,
    inversion: log.possibleInversion,
  };
}

/** Nearest hourly sample to `iso`, within ±90 minutes; null otherwise. */
export function matchHour(series: HourSample[], iso: string): HourSample | null {
  const target = Date.parse(iso);
  if (!Number.isFinite(target) || !series.length) return null;
  let best: HourSample | null = null;
  let bestDelta = Infinity;
  for (const s of series) {
    const d = Math.abs(s.t + 30 * 60_000 - target);
    if (d < bestDelta) {
      bestDelta = d;
      best = s;
    }
  }
  return bestDelta <= 90 * 60_000 ? best : null;
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

function maturityFor(n: number): PatternReport["maturity"] {
  if (n < MIN_LOGS) return "locked";
  if (n < 10) return "early";
  if (n < 25) return "emerging";
  return "solid";
}

export function derivePatterns(
  attacks: AttackSample[],
  baseline: HourSample[],
  opts: { places?: number } = {},
): PatternReport {
  const totalLogs = attacks.length;
  const matched = attacks.filter((a) => a.hour != null);
  const maturity = maturityFor(totalLogs);
  const places = opts.places ?? 0;

  const base: PatternReport = {
    totalLogs,
    matchedLogs: matched.length,
    baselineHours: baseline.length,
    places,
    maturity,
    statements: [],
    note: "",
  };

  if (maturity === "locked") {
    return {
      ...base,
      note: `Patterns unlock after ${MIN_LOGS} logs. You have ${totalLogs}.`,
    };
  }

  const statements: PatternStatement[] = [];

  for (const f of HOUR_FEATURES) {
    let hits = 0;
    let n = 0;
    for (const a of matched) {
      const r = a.hour ? f.test(a.hour) : null;
      if (r == null) continue;
      n += 1;
      if (r) hits += 1;
    }
    if (n < MIN_LOGS) continue;

    let baseHits = 0;
    let baseN = 0;
    for (const h of baseline) {
      const r = f.test(h);
      if (r == null) continue;
      baseN += 1;
      if (r) baseHits += 1;
    }
    const baseShare = baseN >= 24 ? baseHits / baseN : null;
    const share = hits / n;
    const lift = baseShare != null && baseShare > 0 ? share / baseShare : null;

    if (hits >= MIN_HITS && baseShare != null && wilsonLower(hits, n) > baseShare && lift != null && lift >= 1.3) {
      statements.push({
        key: f.key,
        kind: "stands_out",
        text: f.standsOut
          ? f.standsOut(hits, n, share, baseShare)
          : `You reached for your inhaler when ${f.phrase} in ${hits} of ${n} logs — ${pct(share)} of your logs vs ${pct(baseShare)} of ordinary hours near you.`,
        count: hits,
        total: n,
        baseShare,
        lift,
      });
      continue;
    }

    if (baseShare != null && baseShare >= 0.2 && wilsonUpper(hits, n) < baseShare && !f.key.startsWith("time_")) {
      statements.push({
        key: f.key,
        kind: "no_signal",
        text: `${f.subject} doesn't seem to matter for you so far: ${hits} of ${n} logs, while ${pct(baseShare)} of ordinary hours near you were like that.`,
        count: hits,
        total: n,
        baseShare,
        lift,
      });
      continue;
    }

    if (baseShare == null && hits >= MIN_HITS && share >= 0.5) {
      statements.push({
        key: f.key,
        kind: "descriptive",
        text: `You reached for your inhaler when ${f.phrase} in ${hits} of ${n} logs. Not enough ordinary-hour data yet to say whether that's unusual.`,
        count: hits,
        total: n,
        baseShare: null,
        lift: null,
      });
    }
  }

  for (const f of FLAG_FEATURES) {
    const hits = attacks.filter((a) => a.flags[f.key]).length;
    if (hits < MIN_HITS) continue;
    statements.push({
      key: `flag_${f.key}`,
      kind: "descriptive",
      text: `You reached for your inhaler when ${f.phrase} in ${hits} of ${totalLogs} logs.`,
      count: hits,
      total: totalLogs,
      baseShare: null,
      lift: null,
    });
  }

  const rank: Record<PatternKind, number> = { stands_out: 0, descriptive: 1, no_signal: 2 };
  const isTime = (s: PatternStatement) => (s.key.startsWith("time_") ? 1 : 0);
  statements.sort((a, b) => {
    if (rank[a.kind] !== rank[b.kind]) return rank[a.kind] - rank[b.kind];
    // Environmental findings first; time of day is context, not a trigger.
    if (isTime(a) !== isTime(b)) return isTime(a) - isTime(b);
    if (a.lift != null && b.lift != null && a.lift !== b.lift) return b.lift - a.lift;
    return b.count / b.total - a.count / a.total;
  });

  const noteParts: string[] = [];
  if (statements.length === 0) {
    noteParts.push("Nothing stands out yet.");
  }
  if (maturity === "early") noteParts.push("Early — keep logging; under 10 logs is easy to fool.");
  noteParts.push(
    `Compared against ${baseline.length.toLocaleString()} ordinary hours at ${places || "your"} place${places === 1 ? "" : "s"} over the last ~3 months (Open-Meteo model values). Correlation from your own diary, not medical advice.`,
  );

  return { ...base, statements, note: cap(noteParts.join(" ")) };
}
