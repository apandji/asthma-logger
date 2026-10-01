import type { FeatureFrame } from "./types";

function frame(
  partial: Omit<FeatureFrame, "id"> & { id?: string },
  i: number,
): FeatureFrame {
  return {
    id: partial.id ?? `demo-${i}`,
    kind: partial.kind,
    hourOfDay: partial.hourOfDay,
    season: partial.season,
    tempBand: partial.tempBand,
    humidityBand: partial.humidityBand,
    pm25Band: partial.pm25Band,
    ozoneBand: partial.ozoneBand,
    pollenWeed: partial.pollenWeed,
    smokeAtPoint: partial.smokeAtPoint,
    heatAlert: partial.heatAlert,
  };
}

/**
 * Synthetic late-summer diary for talk demos.
 * Story: ozone + afternoon cluster on attacks; baselines are milder mornings.
 */
export function buildDemoFrames(): FeatureFrame[] {
  const out: FeatureFrame[] = [];
  let i = 0;

  // 10 attacks — mostly high ozone, afternoon/evening, some weed pollen
  const attackSpecs: Array<Partial<FeatureFrame> & { kind: "attack" }> = [
    { kind: "attack", hourOfDay: 15, ozoneBand: "high", pm25Band: "moderate", pollenWeed: "moderate", tempBand: "hot", humidityBand: "ok", smokeAtPoint: false, heatAlert: true },
    { kind: "attack", hourOfDay: 16, ozoneBand: "high", pm25Band: "low", pollenWeed: "high", tempBand: "hot", humidityBand: "dry", smokeAtPoint: false, heatAlert: true },
    { kind: "attack", hourOfDay: 14, ozoneBand: "high", pm25Band: "moderate", pollenWeed: "moderate", tempBand: "hot", humidityBand: "ok", smokeAtPoint: false, heatAlert: false },
    { kind: "attack", hourOfDay: 18, ozoneBand: "high", pm25Band: "low", pollenWeed: "low", tempBand: "mild", humidityBand: "ok", smokeAtPoint: false, heatAlert: false },
    { kind: "attack", hourOfDay: 17, ozoneBand: "high", pm25Band: "high", pollenWeed: "high", tempBand: "hot", humidityBand: "humid", smokeAtPoint: true, heatAlert: true },
    { kind: "attack", hourOfDay: 15, ozoneBand: "moderate", pm25Band: "low", pollenWeed: "high", tempBand: "hot", humidityBand: "ok", smokeAtPoint: false, heatAlert: false },
    { kind: "attack", hourOfDay: 19, ozoneBand: "high", pm25Band: "moderate", pollenWeed: "moderate", tempBand: "mild", humidityBand: "ok", smokeAtPoint: false, heatAlert: false },
    { kind: "attack", hourOfDay: 13, ozoneBand: "high", pm25Band: "low", pollenWeed: "moderate", tempBand: "hot", humidityBand: "dry", smokeAtPoint: false, heatAlert: true },
    { kind: "attack", hourOfDay: 16, ozoneBand: "high", pm25Band: "moderate", pollenWeed: "low", tempBand: "hot", humidityBand: "ok", smokeAtPoint: false, heatAlert: false },
    { kind: "attack", hourOfDay: 20, ozoneBand: "moderate", pm25Band: "low", pollenWeed: "moderate", tempBand: "mild", humidityBand: "humid", smokeAtPoint: false, heatAlert: false },
  ];

  for (const a of attackSpecs) {
    out.push(
      frame(
        {
          ...a,
          season: "summer",
          tempBand: a.tempBand ?? "mild",
          humidityBand: a.humidityBand ?? "ok",
          pm25Band: a.pm25Band ?? "low",
          ozoneBand: a.ozoneBand ?? "low",
          pollenWeed: a.pollenWeed ?? "none",
          smokeAtPoint: a.smokeAtPoint ?? false,
          heatAlert: a.heatAlert ?? false,
          hourOfDay: a.hourOfDay ?? 12,
        },
        i++,
      ),
    );
  }

  // 24 baselines — mostly low ozone mornings, little pollen
  for (let d = 0; d < 24; d++) {
    const morning = d % 3 !== 0;
    out.push(
      frame(
        {
          kind: "baseline",
          season: "summer",
          hourOfDay: morning ? 8 + (d % 3) : 12 + (d % 4),
          tempBand: morning ? "mild" : d % 5 === 0 ? "hot" : "mild",
          humidityBand: d % 4 === 0 ? "humid" : "ok",
          pm25Band: d % 7 === 0 ? "moderate" : "low",
          ozoneBand: morning ? "low" : d % 6 === 0 ? "moderate" : "low",
          pollenWeed: d % 5 === 0 ? "low" : "none",
          smokeAtPoint: false,
          heatAlert: !morning && d % 8 === 0,
        },
        i++,
      ),
    );
  }

  return out;
}
