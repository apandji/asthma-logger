/**
 * Writes ../fixtures/*.json from the prototype's own code so the iOS port
 * can be checked against it. Run from web/: `npx tsx scripts/export-fixtures.ts`
 */
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { buildDemoFrames } from "../src/lib/insights/demo-frames";
import { attackLogToFrame } from "../src/lib/insights/frames-from-logs";
import { DEFAULT_GATE, DEMO_GATE, computeLift, type LiftGate } from "../src/lib/insights/lift";
import { summarizeWithTemplate, toNarratorInput } from "../src/lib/insights/summarize";
import type { FeatureFrame, LiftReport } from "../src/lib/insights/types";
import type { AttackLogDTO } from "../src/lib/types";

const OUT = join(__dirname, "..", "..", "fixtures");
const BIN_SPEC_VERSION = 1;

/** JSON has no Infinity: encode infinite lift as null. */
function encodeReport(r: LiftReport) {
  const row = (x: LiftReport["rows"][number]) => ({ ...x, lift: Number.isFinite(x.lift) ? x.lift : null });
  return { ...r, rows: r.rows.map(row), gatedRows: r.gatedRows.map(row) };
}

function writeLift(name: string, frames: FeatureFrame[], gate: LiftGate) {
  const report = computeLift(frames, gate);
  const narration = summarizeWithTemplate(toNarratorInput(report));
  const body = {
    binSpecVersion: BIN_SPEC_VERSION,
    gate,
    frames,
    expected: encodeReport(report),
    expectedTemplate: { headline: narration.headline, caveat: narration.caveat, drivers: narration.drivers },
  };
  writeFileSync(join(OUT, `lift-${name}.json`), JSON.stringify(body, null, 2) + "\n");
}

const demo = buildDemoFrames();
writeLift("demo-gate", demo, DEMO_GATE);
writeLift("demo-default-gate", demo, DEFAULT_GATE);

// Edge cases: infinite lift (level never seen on usual days), unknown bands, too few samples.
const edge: FeatureFrame[] = [
  ...demo.filter((f) => f.kind === "attack").slice(0, 4),
  ...demo.filter((f) => f.kind === "baseline").slice(0, 5),
  { ...demo[0], id: "edge-unknown", ozoneBand: "unknown", pm25Band: "unknown", tempBand: "unknown", humidityBand: "unknown", pollenWeed: "unknown" },
];
writeLift("edge-small", edge, DEFAULT_GATE);

// Raw value → band cases, run through the prototype's real banding.
function dto(p: Partial<AttackLogDTO> & { pm25?: number | null; ozone?: number | null; humidity?: number | null; weed?: string | null }): AttackLogDTO {
  return {
    id: "b", loggedAt: p.loggedAt ?? "2026-07-15T15:30:00", latitude: 0, longitude: 0, feeling: null,
    envStatus: "ready", envFetchedAt: null, envError: null, aqi: p.aqi ?? null, aqiCategory: null,
    temperatureF: p.temperatureF ?? null, isExtremeTemp: p.isExtremeTemp ?? false, hasStormAlert: false,
    stormSummary: p.stormSummary ?? null, hasWildfireNearby: false, wildfireSummary: null,
    possibleInversion: false, inversionNote: null,
    snapshot: {
      v: 2, aqiSource: null, tempSource: null,
      free: { temperatureF: null, humidityPct: p.humidity ?? null, dewpointF: null, aqi: null, aqiCategory: null, aqiPollutant: null,
        pm25: p.pm25 ?? null, ozonePpb: p.ozone ?? null, pollen: p.weed ? { weedRisk: p.weed, treeRisk: null, grassRisk: null, treeCount: null, grassCount: null, weedCount: null, topSpecies: null, asOf: null } : null,
        wildfire: null, storms: null, extremeTempEvent: null, volcano: null, disasters: null },
      ambee: { temperatureF: null, humidityPct: null, dewpointF: null, aqi: null, aqiCategory: null, aqiPollutant: null, pm25: null, ozonePpb: null, pollen: null, wildfire: null, storms: null, extremeTempEvent: null, volcano: null, disasters: null },
    },
  };
}

const bandCases = [
  { pm25: 11.9 }, { pm25: 12 }, { pm25: 34.9 }, { pm25: 35 },
  { ozone: 54.9 }, { ozone: 55 }, { ozone: 69.9 }, { ozone: 70 },
  { temperatureF: 32 }, { temperatureF: 32.1 }, { temperatureF: 89.9 }, { temperatureF: 90 }, { temperatureF: 70, isExtremeTemp: true },
  { humidity: 34.9 }, { humidity: 35 }, { humidity: 65 }, { humidity: 65.1 },
  { weed: "Very High" }, { weed: "High" }, { weed: "Moderate" }, { weed: "Low" }, { weed: "None" }, { weed: "???" },
  { aqi: 50, temperatureF: 70 }, { aqi: 51, temperatureF: 70 },
  { temperatureF: 70, stormSummary: "Excessive Heat Warning" },
  { temperatureF: 70, loggedAt: "2026-01-10T03:00:00" }, { temperatureF: 70, loggedAt: "2026-04-10T23:00:00" },
  { temperatureF: 70, loggedAt: "2026-10-10T12:00:00" },
].map((input) => {
  const f = attackLogToFrame(dto(input))!;
  const bands: Partial<FeatureFrame> = { ...f };
  delete bands.id;
  delete bands.kind;
  return { input, expected: bands };
});
writeFileSync(join(OUT, "bands-v1.json"), JSON.stringify({ binSpecVersion: BIN_SPEC_VERSION, cases: bandCases }, null, 2) + "\n");

console.log("wrote fixtures to", OUT);
