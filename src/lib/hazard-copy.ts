import type { Severity } from "./env-colors";
import type { EnvDisasterHit, EnvDisasterType } from "./types";
import { formatMilesAway, milesToKm } from "./units";

/** Within this, a storm or fire can reasonably affect this pin. */
export const NEARBY_KM = 80;
/** Beyond this, do not present the event as local. */
export const DISTANT_KM = 250;

export type HazardCopy = {
  text: string;
  detail?: string;
  nearby: boolean;
  km: number | null;
};

/** @deprecated Prefer formatMilesAway from units — kept for existing imports. */
export function formatKmAway(km: number): string {
  return formatMilesAway(km);
}

/** Parse a distance token that may be stored as km (legacy) or mi (current). */
function parseDistanceToken(value: string, unit: string): number | null {
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  const u = unit.toLowerCase();
  if (u.startsWith("mi")) return milesToKm(n);
  return n;
}

function placePhrase(place: string | null | undefined): string | null {
  if (!place) return null;
  return place.replace(/^near\s+/i, "").trim() || null;
}

function nearestHits(hits: EnvDisasterHit[], types: EnvDisasterType[]): EnvDisasterHit[] {
  return hits
    .filter((h) => types.includes(h.type))
    .slice()
    .sort((a, b) => (a.km ?? 1e9) - (b.km ?? 1e9));
}

/**
 * One headline + optional extra line. Distant events are "none nearby"
 * with the closest report in the detail, not a stacked "Storm · place · km" list.
 */
export function summarizeHazards(
  hits: EnvDisasterHit[] | null | undefined,
  types: EnvDisasterType[],
  noun: "storm" | "wildfire",
): HazardCopy | null {
  const matched = nearestHits(hits ?? [], types);
  if (!matched.length) return null;
  const nearest = matched[0];
  const km = nearest.km;
  const place = placePhrase(nearest.place);
  const nearby = km == null || km <= NEARBY_KM;

  if (km != null && km > DISTANT_KM) {
    return {
      text: "None nearby",
      detail: place ? `Closest report: ${place} · ${formatMilesAway(km)}` : `Closest report ${formatMilesAway(km)}`,
      nearby: false,
      km,
    };
  }

  const where = place ? `Near ${place}` : noun === "storm" ? "Storm reported" : "Wildfire reported";
  const alsoNear = matched.filter((h, i) => i > 0 && h.km != null && h.km <= NEARBY_KM);
  if (alsoNear.length === 0 || km == null) {
    return { text: where, detail: km != null ? formatMilesAway(km) : undefined, nearby, km };
  }

  const extra = alsoNear[0];
  const extraPlace = placePhrase(extra.place);
  const extraBit = extraPlace
    ? `also ${extraPlace} · ${formatMilesAway(extra.km!)}`
    : `+${alsoNear.length} more nearby`;
  return {
    text: where,
    detail: [formatMilesAway(km), extraBit].filter(Boolean).join(" · "),
    nearby,
    km,
  };
}

export function hotspotCopy(km: number, place: string | null | undefined, count = 1): HazardCopy {
  const loc = placePhrase(place);
  const nearby = km <= NEARBY_KM;
  if (!nearby && km > DISTANT_KM) {
    return {
      text: "None nearby",
      detail: loc ? `Closest hotspot: ${loc} · ${formatMilesAway(km)}` : `Closest hotspot ${formatMilesAway(km)}`,
      nearby: false,
      km,
    };
  }
  // FIRMS/Ambee fire pixels are thermal anomalies — industrial heat, ag burns,
  // campfires — not confirmed wildfires. Name the place; do not say "wildfire".
  const text =
    count > 1
      ? `${count} satellite heat spots`
      : loc
        ? `Satellite heat near ${loc}`
        : "Satellite heat nearby";
  const detail =
    count > 1
      ? loc
        ? `Closest ${formatMilesAway(km)} · ${loc}`
        : `Closest ${formatMilesAway(km)}`
      : formatMilesAway(km);
  return { text, detail, nearby, km };
}

/** Rewrite stacked “Storm · place · km|mi” strings from older logs. */
export function rewriteStormLabel(raw: string | null | undefined): HazardCopy | null {
  if (!raw) return null;
  const hits: { place: string | null; km: number }[] = [];
  const re = /(?:Storm|Cyclone)\s*·\s*([^·]+?)\s*·\s*([\d.]+)\s*(km|mi(?:les)?)/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(raw))) {
    const km = parseDistanceToken(m[2], m[3]);
    if (km == null) continue;
    hits.push({ place: m[1].trim(), km });
  }
  if (!hits.length) {
    const simple = raw.match(/([\d.]+)\s*(km|mi(?:les)?)/i);
    if (!simple) return { text: raw.replace(/\s*·\s*/g, " · ").trim(), nearby: true, km: null };
    const km = parseDistanceToken(simple[1], simple[2]);
    if (km == null) return { text: raw.replace(/\s*·\s*/g, " · ").trim(), nearby: true, km: null };
    return summarizeHazards([{ type: "SW", name: raw, km, place: null }], ["SW"], "storm");
  }
  hits.sort((a, b) => a.km - b.km);
  return summarizeHazards(
    hits.map((h) => ({ type: "SW" as const, name: "Storm", km: h.km, place: h.place })),
    ["SW"],
    "storm",
  );
}

/** Rewrite stored FIRMS / Ambee fire strings from older logs. */
export function rewriteFireLabel(raw: string | null | undefined): HazardCopy | null {
  if (!raw) return null;
  const nwsAlert = raw.match(/^(.*?(?:Warning|Watch|Advisory|Alert))\s*[;·]/i);
  const firmsCount = raw.match(/(\d+)\s+FIRMS hotspot/i);
  if (firmsCount) {
    const count = Number(firmsCount[1]);
    const kmMatch = raw.match(/closest\s+([\d.]+)\s*(km|mi(?:les)?)/i);
    const km = kmMatch ? parseDistanceToken(kmMatch[1], kmMatch[2]) : null;
    const place = raw.match(/\bnear\s+([^·]+?)(?:\s*·|$)/i)?.[1]?.trim() ?? null;
    const hot =
      km != null
        ? hotspotCopy(km, place, count)
        : {
            text: count > 1 ? `${count} satellite heat spots` : "Satellite heat nearby",
            detail: place ? `Near ${place}` : "Thermal pixel · not a confirmed wildfire",
            nearby: true,
            km: null,
          };
    if (nwsAlert?.[1]) {
      return {
        text: nwsAlert[1].trim(),
        detail: [hot.text, hot.detail].filter(Boolean).join(" · "),
        nearby: hot.nearby,
        km: hot.km,
      };
    }
    return hot;
  }

  const hot = raw.match(
    /(?:hotspot|detected fire|fire)\s+([\d.]+)\s*(km|mi(?:les)?)(?:[^·]*·\s*FRP[^·]+)?(?:[^·]*·\s*nominal)?(?:\s*·\s*near\s+([^·]+))?/i,
  );
  if (hot) {
    const km = parseDistanceToken(hot[1], hot[2]);
    if (km != null) return hotspotCopy(km, hot[3]?.trim() ?? null);
  }

  const away = raw.match(/([\d.]+)\s*(km|mi(?:les)?)\s+away/i);
  if (away) {
    const km = parseDistanceToken(away[1], away[2]);
    if (km != null) {
      const place =
        raw.match(/satellite heat near\s+([^·]+)/i)?.[1]?.trim() ??
        raw.match(/\bNear\s+([^·]+)/i)?.[1]?.trim() ??
        null;
      const countMatch =
        raw.match(/(\d+)\s+satellite heat spots/i) ?? raw.match(/(\d+)\s+satellite hotspots/i);
      return hotspotCopy(km, place, countMatch ? Number(countMatch[1]) : 1);
    }
  }

  const cleaned = raw
    .replace(/\s*·\s*FRP\s+[\d.]+\s*/gi, "")
    .replace(/\s*·\s*nominal\s*/gi, "")
    .replace(/\bFIRMS\b/gi, "satellite")
    .replace(/\s{2,}/g, " ")
    .replace(/^[·\s]+|[·\s]+$/g, "")
    .trim();
  if (!cleaned) return null;
  return { text: cleaned, nearby: true, km: null };
}

/**
 * Prefer Ambee WF / reported wildfire as the lead. Satellite heat (FIRMS / Ambee
 * detected) is secondary detail only — not interchangeable with a wildfire claim.
 */
export function mergeFireCopy(hotspot: HazardCopy | null, reported: HazardCopy | null): HazardCopy | null {
  if (reported && hotspot) {
    if (!reported.nearby && hotspot.nearby) {
      // Distant WF report + nearby heat: lead with heat honesty, keep WF as context.
      const wfBit =
        reported.text === "None nearby"
          ? reported.detail
          : [reported.text, reported.detail].filter(Boolean).join(" · ");
      return {
        ...hotspot,
        detail: [hotspot.detail, wfBit ? `report: ${wfBit}` : null].filter(Boolean).join(" · ") || hotspot.detail,
      };
    }
    const heatBit = [hotspot.text, hotspot.detail].filter(Boolean).join(" · ");
    return {
      ...reported,
      detail: [reported.detail, heatBit ? `also ${heatBit}` : null].filter(Boolean).join(" · ") || reported.detail,
    };
  }
  return reported ?? hotspot;
}

export function hazardSeverity(copy: HazardCopy | null, kind: "storm" | "wildfire"): Severity {
  if (!copy) return "green";
  if (!copy.nearby) return "green";
  if (kind === "wildfire") {
    if (copy.km != null && copy.km <= 25) return "red";
    return "orange";
  }
  if (copy.km != null && copy.km <= 25) return "orange";
  return "yellow";
}
