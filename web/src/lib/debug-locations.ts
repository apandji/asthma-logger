/**
 * Debugger pins for `?debug=1` / `?demo=1`.
 * Chosen to exercise different outdoor signals (storms, ozone/smoke, cold/rural,
 * tropical haze, volcano/haze outside the US NWS footprint).
 */
export const DEBUG_LOCATIONS = {
  florida: {
    lat: 25.7617,
    lon: -80.1918,
    label: "Miami, FL",
    hint: "storm / tropical weather",
    alert: true,
  },
  la: {
    lat: 34.0522,
    lon: -118.2437,
    label: "Los Angeles, CA",
    hint: "ozone, traffic, wildfire smoke",
    alert: false,
  },
  northDakota: {
    lat: 46.8083,
    lon: -100.7837,
    label: "Bismarck, ND",
    hint: "cold, rural, sparse monitors",
    alert: false,
  },
  singapore: {
    lat: 1.3521,
    lon: 103.8198,
    label: "Singapore",
    hint: "tropical humidity / haze (no NWS)",
    alert: false,
  },
  indonesia: {
    // Near Yogyakarta / Merapi — volcano + tropical haze outside NWS
    lat: -7.7956,
    lon: 110.3695,
    label: "Yogyakarta, Indonesia",
    hint: "volcano / tropical haze (no NWS)",
    alert: true,
  },
} as const;

export type DebugLocationKey = keyof typeof DEBUG_LOCATIONS;

export function isDebugModeEnabled(search: string): boolean {
  const params = new URLSearchParams(search.startsWith("?") ? search.slice(1) : search);
  const debug = params.get("debug");
  const demo = params.get("demo");
  return debug === "1" || demo === "1";
}
