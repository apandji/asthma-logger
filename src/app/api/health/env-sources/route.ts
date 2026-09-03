import { NextResponse } from "next/server";
import { isAmbeeConfigured, parseAmbeeAq, parseAmbeeWeather } from "@/lib/ambee";

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
    weatherOk: boolean | null;
    weatherError: string | null;
    temperatureF: number | null;
    humidityPct: number | null;
  } = {
    configured: ambeeConfigured,
    ok: false,
    error: null,
    note: "Not configured",
    pm25: null,
    weatherOk: null,
    weatherError: null,
    temperatureF: null,
    humidityPct: null,
  };

  if (ambeeConfigured) {
    const headers = {
      "x-api-key": process.env.AMBEE_API_KEY!.trim(),
      "Content-type": "application/json",
    };
    try {
      const res = await fetch("https://api.ambeedata.com/latest/by-lat-lng?lat=39.7392&lng=-104.9903", {
        headers,
        cache: "no-store",
      });
      const text = await res.text();
      if (!res.ok && res.status !== 206) {
        ambeeProbe = {
          ...ambeeProbe,
          configured: true,
          ok: false,
          error: `HTTP ${res.status}`,
          note: "Ambee AQ request failed — check AMBEE_API_KEY / quota",
        };
      } else {
        const aq = parseAmbeeAq(JSON.parse(text) as unknown);
        ambeeProbe = {
          ...ambeeProbe,
          configured: true,
          ok: true,
          error: null,
          note: "Ambee key accepted (AQ + weather probe, Denver).",
          pm25: aq.pm25,
        };
      }
    } catch (err) {
      ambeeProbe = {
        ...ambeeProbe,
        configured: true,
        ok: false,
        error: err instanceof Error ? err.message : "fetch failed",
        note: "Ambee AQ request error",
      };
    }

    try {
      const wxRes = await fetch("https://api.ambeedata.com/weather/latest/by-lat-lng?lat=39.7392&lng=-104.9903", {
        headers,
        cache: "no-store",
      });
      const wxText = await wxRes.text();
      if (!wxRes.ok && wxRes.status !== 206) {
        ambeeProbe.weatherOk = false;
        ambeeProbe.weatherError = `HTTP ${wxRes.status}: ${wxText.slice(0, 120)}`;
      } else {
        const wxBody = JSON.parse(wxText) as unknown;
        const wx = parseAmbeeWeather(wxBody);
        ambeeProbe.weatherOk = wx.temperatureF != null || wx.humidityPct != null;
        ambeeProbe.temperatureF = wx.temperatureF;
        ambeeProbe.humidityPct = wx.humidityPct;
        if (!ambeeProbe.weatherOk) {
          const root = wxBody && typeof wxBody === "object" ? (wxBody as { data?: unknown }).data : null;
          const keys = root && typeof root === "object" ? Object.keys(root as object) : [];
          ambeeProbe.weatherError = `Parsed but no temp/humidity. data keys: ${keys.join(",") || "none"}`;
        }
      }
    } catch (err) {
      ambeeProbe.weatherOk = false;
      ambeeProbe.weatherError = err instanceof Error ? err.message : "weather fetch failed";
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
