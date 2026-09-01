import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

/** Quick check that optional env API keys are configured and reachable (no secrets returned). */
export async function GET() {
  const airnowConfigured = Boolean(process.env.AIRNOW_API_KEY?.trim());
  const firmsConfigured = Boolean(process.env.FIRMS_MAP_KEY?.trim());

  let firmsProbe: {
    configured: boolean;
    ok: boolean;
    hotspotCount: number;
    error: string | null;
    note: string;
  } = {
    configured: firmsConfigured,
    ok: false,
    hotspotCount: 0,
    error: null,
    note: "Not configured",
  };

  if (firmsConfigured) {
    const mapKey = process.env.FIRMS_MAP_KEY!.trim();
    // Northern CA demo area — may have 0 hotspots if none nearby; key validity still checked
    const lat = 41.7569;
    const lon = -120.1561;
    const delta = 0.45;
    const url = `https://firms.modaps.eosdis.nasa.gov/api/area/csv/${mapKey}/VIIRS_SNPP_NRT/${lon - delta},${lat - delta},${lon + delta},${lat + delta}/1`;
    try {
      const res = await fetch(url, { cache: "no-store" });
      const text = await res.text();
      if (!res.ok) {
        firmsProbe = {
          configured: true,
          ok: false,
          hotspotCount: 0,
          error: `HTTP ${res.status}`,
          note: "FIRMS request failed",
        };
      } else if (/invalid map_key/i.test(text)) {
        firmsProbe = {
          configured: true,
          ok: false,
          hotspotCount: 0,
          error: "Invalid MAP_KEY",
          note: "Key is set but rejected by NASA FIRMS — re-copy from firms.modaps.eosdis.nasa.gov",
        };
      } else {
        const lines = text.trim().split("\n").filter(Boolean);
        const count = lines.length > 1 ? lines.length - 1 : 0;
        firmsProbe = {
          configured: true,
          ok: true,
          hotspotCount: count,
          error: null,
          note:
            count > 0
              ? "FIRMS working — hotspots found in probe area"
              : "FIRMS key accepted; no satellite hotspots in probe area right now (normal)",
        };
      }
    } catch (err) {
      firmsProbe = {
        configured: true,
        ok: false,
        hotspotCount: 0,
        error: err instanceof Error ? err.message : "fetch failed",
        note: "FIRMS request error",
      };
    }
  }

  return NextResponse.json({
    airnowConfigured,
    firmsConfigured,
    firmsProbe,
  });
}
