/**
 * Open-Meteo hourly history (free, no key). Used as a single consistent source for
 * "attack hour" vs "ordinary hour" comparisons — mixing station PM with model PM
 * would bias the lift, so patterns use model values on both sides.
 */
import type { HourSample } from "./patterns";

/** Open-Meteo's air-quality API caps past_days at 92. */
export const OPEN_METEO_MAX_PAST_DAYS = 92;

type HourlyBlock = { time?: number[] } & Record<string, unknown>;

function numArray(block: HourlyBlock, key: string): Array<number | null> {
  const arr = block[key];
  if (!Array.isArray(arr)) return [];
  return arr.map((v) => (typeof v === "number" && Number.isFinite(v) ? v : null));
}

async function getJson(url: string): Promise<HourlyBlock | null> {
  try {
    const res = await fetch(url, { next: { revalidate: 3600 } });
    if (!res.ok) return null;
    const data = (await res.json()) as { hourly?: HourlyBlock };
    return data.hourly ?? null;
  } catch {
    return null;
  }
}

/**
 * Hourly weather + air quality for the past `pastDays` days at a point, UTC hours,
 * oldest first. Returns [] if both feeds fail.
 */
export async function fetchHourlyHistory(
  lat: number,
  lon: number,
  pastDays = OPEN_METEO_MAX_PAST_DAYS,
): Promise<HourSample[]> {
  const days = Math.max(1, Math.min(OPEN_METEO_MAX_PAST_DAYS, Math.round(pastDays)));
  const base = `latitude=${lat.toFixed(3)}&longitude=${lon.toFixed(3)}&past_days=${days}&forecast_days=1&timeformat=unixtime&timezone=UTC`;

  const [wx, aq] = await Promise.all([
    getJson(
      `https://api.open-meteo.com/v1/forecast?${base}&hourly=temperature_2m,relative_humidity_2m,dew_point_2m,wind_speed_10m&temperature_unit=fahrenheit&wind_speed_unit=mph`,
    ),
    getJson(`https://air-quality-api.open-meteo.com/v1/air-quality?${base}&hourly=pm2_5,us_aqi`),
  ]);

  const byTime = new Map<number, HourSample>();
  const now = Date.now();
  const ensure = (sec: number): HourSample => {
    const t = sec * 1000;
    let s = byTime.get(t);
    if (!s) {
      s = { t, pm25: null, aqi: null, tempF: null, dewF: null, rhPct: null, windMph: null };
      byTime.set(t, s);
    }
    return s;
  };

  if (wx?.time) {
    const temp = numArray(wx, "temperature_2m");
    const rh = numArray(wx, "relative_humidity_2m");
    const dew = numArray(wx, "dew_point_2m");
    const wind = numArray(wx, "wind_speed_10m");
    wx.time.forEach((sec, i) => {
      if (sec * 1000 > now) return;
      const s = ensure(sec);
      s.tempF = temp[i] ?? null;
      s.rhPct = rh[i] ?? null;
      s.dewF = dew[i] ?? null;
      s.windMph = wind[i] ?? null;
    });
  }

  if (aq?.time) {
    const pm = numArray(aq, "pm2_5");
    const aqi = numArray(aq, "us_aqi");
    aq.time.forEach((sec, i) => {
      if (sec * 1000 > now) return;
      const s = ensure(sec);
      s.pm25 = pm[i] ?? null;
      s.aqi = aqi[i] ?? null;
    });
  }

  return [...byTime.values()].sort((a, b) => a.t - b.t);
}
