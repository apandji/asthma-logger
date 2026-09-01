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

export type EnvBadge = { key: string; label: string; severity: Severity };

export { severityStyle };

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
    if (/FIRMS hotspot/i.test(part)) {
      labels.push(part);
    } else {
      labels.push(...splitAlerts(part));
    }
  }
  return labels;
}

export function buildEnvBadges(log: AttackLogDTO): EnvBadge[] {
  const badges: EnvBadge[] = [
    {
      key: "status",
      label: `env:${log.envStatus}`,
      severity: envStatusSeverity(log.envStatus),
    },
  ];

  if (log.envStatus !== "ready") return badges;

  if (log.temperatureF != null) {
    badges.push({
      key: "temp",
      label: `${Math.round(log.temperatureF)}°F${log.isExtremeTemp ? " extreme" : ""}`,
      severity: temperatureSeverity(log.temperatureF, log.isExtremeTemp),
    });
  }

  if (log.aqi != null) {
    badges.push({
      key: "aqi",
      label: `AQI ${log.aqi}${log.aqiCategory ? ` (${log.aqiCategory})` : ""}`,
      severity: aqiSeverity(log.aqi),
    });
  }

  if (log.hasStormAlert) {
    const alerts = splitAlerts(log.stormSummary);
    if (alerts.length === 0) {
      badges.push({
        key: "weather-0",
        label: "Weather alert",
        severity: weatherAlertSeverity(null),
      });
    } else {
      alerts.forEach((name, i) => {
        badges.push({
          key: `weather-${i}-${name}`,
          label: name,
          severity: weatherAlertSeverity(name),
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
      });
    } else {
      fireLabels.forEach((name, i) => {
        badges.push({
          key: `wildfire-${i}-${name}`,
          label: name,
          severity: wildfireSeverity(),
        });
      });
    }
  }

  if (log.possibleInversion) {
    badges.push({
      key: "inversion",
      label: "Inversion?",
      severity: inversionSeverity(),
    });
  }

  return badges;
}
