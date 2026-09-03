import type { Severity } from "./env-colors";
import type { EnvDisasterHit, EnvDisasterType } from "./types";

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

export function formatKmAway(km: number): string {
  const rounded = km < 10 ? km.toFixed(1) : String(Math.round(km));
  return `${rounded} km away`;
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
      detail: place ? `Closest report: ${place} · ${formatKmAway(km)}` : `Closest report ${formatKmAway(km)}`,
      nearby: false,
      km,
    };
  }

  const where = place ? `Near ${place}` : noun === "storm" ? "Storm reported" : "Wildfire reported";
  const alsoNear = matched.filter((h, i) => i > 0 && h.km != null && h.km <= NEARBY_KM);
  if (alsoNear.length === 0 || km == null) {
    return { text: where, detail: km != null ? formatKmAway(km) : undefined, nearby, km };
  }

  const extra = alsoNear[0];
  const extraPlace = placePhrase(extra.place);
  const extraBit = extraPlace
    ? `also ${extraPlace} · ${formatKmAway(extra.km!)}`
    : `+${alsoNear.length} more nearby`;
  return {
    text: where,
    detail: [formatKmAway(km), extraBit].filter(Boolean).join(" · "),
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
      detail: loc ? `Closest hotspot: ${loc} · ${formatKmAway(km)}` : `Closest hotspot ${formatKmAway(km)}`,
      nearby: false,
      km,
    };
  }
  const text = count > 1 ? `${count} satellite hotspots` : loc ? `Near ${loc}` : "Satellite hotspot";
  const detail =
    count > 1
      ? loc
        ? `Closest ${formatKmAway(km)} · ${loc}`
        : `Closest ${formatKmAway(km)}`
      : formatKmAway(km);
  return { text, detail, nearby, km };
}

/** Rewrite stacked “Storm · place · km” strings from older logs. */
export function rewriteStormLabel(raw: string | null | undefined): HazardCopy | null {
  if (!raw) return null;
  const hits: { place: string | null; km: number }[] = [];
  const re = /(?:Storm|Cyclone)\s*·\s*([^·]+?)\s*·\s*([\d.]+)\s*km/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(raw))) {
    const km = Number(m[2]);
    if (!Number.isFinite(km)) continue;
    hits.push({ place: m[1].trim(), km });
  }
  if (!hits.length) {
    const simple = raw.match(/([\d.]+)\s*km/i);
    if (!simple) return { text: raw.replace(/\s*·\s*/g, " · ").trim(), nearby: true, km: null };
    const km = Number(simple[1]);
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
    const kmMatch = raw.match(/closest\s+([\d.]+)\s*km/i);
    const km = kmMatch ? Number(kmMatch[1]) : null;
    const place = raw.match(/\bnear\s+([^·]+?)(?:\s*·|$)/i)?.[1]?.trim() ?? null;
    const hot =
      km != null && Number.isFinite(km)
        ? hotspotCopy(km, place, count)
        : {
            text: count > 1 ? `${count} satellite hotspots` : "Satellite hotspot",
            detail: place ? `Near ${place}` : "Last 24 hours",
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
    /(?:hotspot|detected fire|fire)\s+([\d.]+)\s*km(?:[^·]*·\s*FRP[^·]+)?(?:[^·]*·\s*nominal)?(?:\s*·\s*near\s+([^·]+))?/i,
  );
  if (hot) {
    const km = Number(hot[1]);
    if (Number.isFinite(km)) return hotspotCopy(km, hot[2]?.trim() ?? null);
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

export function mergeFireCopy(hotspot: HazardCopy | null, reported: HazardCopy | null): HazardCopy | null {
  if (hotspot && reported) {
    const hotKm = hotspot.km ?? 1e9;
    const repKm = reported.km ?? 1e9;
    const lead = hotKm <= repKm ? hotspot : reported;
    const other = lead === hotspot ? reported : hotspot;
    if (other.km != null && other.km <= NEARBY_KM && other.km !== lead.km) {
      const otherPlace = other.text.replace(/^Near\s+/i, "").trim();
      const extra = otherPlace && !lead.text.includes(otherPlace)
        ? `also ${otherPlace} · ${formatKmAway(other.km)}`
        : formatKmAway(other.km);
      return {
        ...lead,
        detail: [lead.detail, extra].filter(Boolean).join(" · ") || lead.detail,
      };
    }
    return lead;
  }
  return hotspot ?? reported;
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
