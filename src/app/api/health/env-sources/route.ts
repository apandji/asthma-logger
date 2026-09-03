import { NextResponse } from "next/server";
import { isAmbeeConfigured, parseAmbeeAq } from "@/lib/ambee";

export const dynamic = "force-dynamic";

/** Quick check that optional env API keys are configured and reachable (no secrets returned). */
export async function GET() {
  const airnowConfigured = Boolean(process.env.AIRNOW_API_KEY?.trim());
  const firmsConfigured = Boolean(process.env.FIRMS_MAP_KEY?.trim());
  const ambeeConfigured = isAmbeeConfigured();

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

  let ambeeProbe: {
    configured: boolean;
    ok: boolean;
    error: string | null;
    note: string;
    pm25: number | null;
  } = {
    configured: ambeeConfigured,
    ok: false,
    error: null,
    note: "Not configured",
    pm25: null,
  };

  if (ambeeConfigured) {
    try {
      const res = await fetch("https://api.ambeedata.com/latest/by-lat-lng?lat=39.7392&lng=-104.9903", {
        headers: {
          "x-api-key": process.env.AMBEE_API_KEY!.trim(),
          "Content-type": "application/json",
        },
        cache: "no-store",
      });
      const text = await res.text();
      if (!res.ok && res.status !== 206) {
        ambeeProbe = {
          configured: true,
          ok: false,
          error: `HTTP ${res.status}`,
          note: "Ambee AQ request failed — check AMBEE_API_KEY / quota",
          pm25: null,
        };
      } else {
        const aq = parseAmbeeAq(JSON.parse(text) as unknown);
        ambeeProbe = {
          configured: true,
          ok: true,
          error: null,
          note: "Ambee key accepted (1 AQ probe, Denver). Pollen/weather/fire run on each new log.",
          pm25: aq.pm25,
        };
      }
    } catch (err) {
      ambeeProbe = {
        configured: true,
        ok: false,
        error: err instanceof Error ? err.message : "fetch failed",
        note: "Ambee request error",
        pm25: null,
      };
    }
  }

  return NextResponse.json({
    airnowConfigured,
    firmsConfigured,
    ambeeConfigured,
    firmsProbe,
    ambeeProbe,
  });
}
