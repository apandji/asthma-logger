import {
  aqiSeverity,
  envStatusSeverity,
  inversionSeverity,
  severityStyle,
  temperatureSeverity,
  weatherAlertSeverity,
  wildfireSeverity,
  type Severity,
} from "./env-colors";
import type { AttackLogDTO } from "./types";

export type EnvBadge = {
  key: string;
  label: string;
  severity: Severity;
  emoji: string;
  /** Shown on hover / long-press */
  source: string;
};

export { severityStyle };

const SOURCES = {
  status: "App — sync & enrichment status",
  temp: "NWS forecast — api.weather.gov",
  aqi: "EPA AirNow — airnowapi.org",
  weather: "NWS active alerts — api.weather.gov",
  wildfireNws: "NWS fire/smoke alerts — api.weather.gov",
  wildfireFirms: "NASA FIRMS satellite hotspots — firms.modaps.eosdis.nasa.gov",
  inversion: "Heuristic from NWS forecast (not a direct measurement)",
} as const;

function splitAlerts(summary: string | null): string[] {
  if (!summary) return [];
  return summary
    .split(";")
    .map((s) => s.trim())
    .filter(Boolean);
}

function parseWildfireLabels(summary: string | null): string[] {
  if (!summary) return [];
  const labels: string[] = [];
  for (const chunk of summary.split("|")) {
    const part = chunk.trim();
    if (!part) continue;
    labels.push(part);
  }
  return labels;
}

function statusEmoji(status: string): string {
  if (status === "ready") return "✅";
  if (status === "failed") return "❌";
  if (status === "pending") return "⏳";
  return "📡";
}

export function buildEnvBadges(log: AttackLogDTO): EnvBadge[] {
  const badges: EnvBadge[] = [
    {
      key: "status",
      label: `env:${log.envStatus}`,
      severity: envStatusSeverity(log.envStatus),
      emoji: statusEmoji(log.envStatus),
      source: SOURCES.status,
    },
  ];

  if (log.envStatus !== "ready") return badges;

  if (log.temperatureF != null) {
    badges.push({
      key: "temp",
      label: `${Math.round(log.temperatureF)}°F${log.isExtremeTemp ? " extreme" : ""}`,
      severity: temperatureSeverity(log.temperatureF, log.isExtremeTemp),
      emoji: "🌡️",
      source: SOURCES.temp,
    });
  }

  if (log.aqi != null) {
    badges.push({
      key: "aqi",
      label: `AQI ${log.aqi}${log.aqiCategory ? ` (${log.aqiCategory})` : ""}`,
      severity: aqiSeverity(log.aqi),
      emoji: "💨",
      source: SOURCES.aqi,
    });
  }

  if (log.hasStormAlert) {
    const alerts = splitAlerts(log.stormSummary);
    if (alerts.length === 0) {
      badges.push({
        key: "weather-0",
        label: "Weather alert",
        severity: weatherAlertSeverity(null),
        emoji: "⚠️",
        source: SOURCES.weather,
      });
    } else {
      alerts.forEach((name, i) => {
        badges.push({
          key: `weather-${i}-${name}`,
          label: name,
          severity: weatherAlertSeverity(name),
          emoji: "⚠️",
          source: SOURCES.weather,
        });
      });
    }
  }

  if (log.hasWildfireNearby) {
    const fireLabels = parseWildfireLabels(log.wildfireSummary);
    if (fireLabels.length === 0) {
      badges.push({
        key: "wildfire-0",
        label: "Wildfire/smoke",
        severity: wildfireSeverity(),
        emoji: "🔥",
        source: SOURCES.wildfireNws,
      });
    } else {
      fireLabels.forEach((name, i) => {
        const isFirms = /FIRMS hotspot/i.test(name);
        badges.push({
          key: `wildfire-${i}-${name}`,
          label: name,
          severity: wildfireSeverity(),
          emoji: isFirms ? "🛰️" : "🔥",
          source: isFirms ? SOURCES.wildfireFirms : SOURCES.wildfireNws,
        });
      });
    }
  }

  if (log.possibleInversion) {
    badges.push({
      key: "inversion",
      label: "Inversion?",
      severity: inversionSeverity(),
      emoji: "🌫️",
      source: SOURCES.inversion,
    });
  }

  return badges;
}
