const NWS_USER_AGENT =
  process.env.NWS_USER_AGENT ?? "(asthma-log-prototype, local-dev@example.com)";

export function formatPlaceName(city?: string | null, state?: string | null): string | null {
  const c = city?.trim();
  const s = state?.trim();
  if (c && s) return `${c}, ${s}`;
  return c || s || null;
}

/** Nearest named place from NWS /points — e.g. "St. Louis, MO". */
export async function lookupPlaceName(lat: number, lon: number): Promise<string | null> {
  const url = `https://api.weather.gov/points/${lat.toFixed(4)},${lon.toFixed(4)}`;
  const res = await fetch(url, {
    headers: {
      Accept: "application/geo+json",
      "User-Agent": NWS_USER_AGENT,
    },
    cache: "no-store",
  });
  if (!res.ok) return null;
  const body = (await res.json()) as {
    properties?: { relativeLocation?: { properties?: { city?: string; state?: string } } };
  };
  const loc = body.properties?.relativeLocation?.properties;
  return formatPlaceName(loc?.city, loc?.state);
}
