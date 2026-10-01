/** Statute miles per kilometer. */
export const KM_TO_MILES = 0.621371;

export function kmToMiles(km: number): number {
  return km * KM_TO_MILES;
}

export function milesToKm(miles: number): number {
  return miles / KM_TO_MILES;
}

/** Round like the old km labels: one decimal under 10, otherwise whole miles. */
export function formatMiles(km: number): string {
  const miles = kmToMiles(km);
  const rounded = miles < 10 ? miles.toFixed(1) : String(Math.round(miles));
  return `${rounded} mi`;
}

export function formatMilesAway(km: number): string {
  return `${formatMiles(km)} away`;
}
