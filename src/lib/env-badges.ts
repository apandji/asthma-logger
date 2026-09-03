import {
  aqiSeverity,
  envStatusSeverity,
  humiditySeverity,
  inversionSeverity,
  ozoneSeverity,
  pm25Severity,
  pollenRiskSeverity,
  severityStyle,
  temperatureSeverity,
  weatherAlertSeverity,
  wildfireSeverity,
  type Severity,
} from "./env-colors";
import type { AttackLogDTO } from "./types";

export type EnvBadgeGroup = "free" | "ambee" | "meta";

export type EnvBadge = {
  key: string;
  label: string;
  severity: Severity;
  emoji: string;
  /** Shown on hover / long-press */
  source: string;
  group: EnvBadgeGroup;
};

export { severityStyle };

const SOURCES = {
  status: "App — sync & enrichment status",
  tempNws: "NWS forecast period — api.weather.gov (not a station reading)",
  tempAmbee: "Ambee weather — outdoor model/obs blend (~hourly). Not indoor air.",
  aqiAirnow: "EPA AirNow official monitor — regional, often 5–25+ miles away",
  aqiAmbee: "Ambee outdoor AQ model (~500 m claimed). Not indoor air.",
  pm25: "Ambee PM2.5 — outdoor ambient, modeled. Not the air indoors.",
  ozone: "Ambee ground-level ozone (AQ API). Not weather column ozone.",
  humidity: "Ambee weather humidity / dewpoint — outdoor.",
  pollen: "Ambee pollen model (NAB-style risk). Outdoor; not a backyard trap.",
  weather: "NWS active alerts — api.weather.gov",
  wildfireNws: "NWS fire/smoke alerts — api.weather.gov",
  wildfireFirms: "NASA FIRMS satellite hotspots — firms.modaps.eosdis.nasa.gov",
  wildfireAmbee: "Ambee fire detection — nearest hotspot distance, not smoke at this pin. Smoke ≈ PM2.5.",
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
      group: "meta",
    },
  ];

  if (log.envStatus !== "ready") return badges;

  const snap = log.snapshot;

  // --- Free API badges (NWS / AirNow) ---

  if (log.temperatureF != null && snap?.tempSource !== "ambee_weather") {
    badges.push({
      key: "temp",
      label: `${Math.round(log.temperatureF)}°F${log.isExtremeTemp ? " extreme" : ""}`,
      severity: temperatureSeverity(log.temperatureF, log.isExtremeTemp),
      emoji: "🌡️",
      source: SOURCES.tempNws,
      group: "free",
    });
  }

  if (log.aqi != null && snap?.aqiSource !== "ambee") {
    badges.push({
      key: "aqi",
      label: `AQI ${log.aqi}${log.aqiCategory ? ` (${log.aqiCategory})` : ""}`,
      severity: aqiSeverity(log.aqi),
      emoji: "💨",
      source: SOURCES.aqiAirnow,
      group: "free",
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
        group: "free",
      });
    } else {
      alerts.forEach((name, i) => {
        badges.push({
          key: `weather-${i}-${name}`,
          label: name,
          severity: weatherAlertSeverity(name),
          emoji: "⚠️",
          source: SOURCES.weather,
          group: "free",
        });
      });
    }
  }

  {
    const fireLabels = parseWildfireLabels(log.wildfireSummary);
    fireLabels.forEach((name, i) => {
      const isFirms = /FIRMS hotspot/i.test(name);
      const isAmbee = /^Ambee /i.test(name);
      if (!isAmbee) {
        badges.push({
          key: `wildfire-${i}-${name}`,
          label: name,
          severity: wildfireSeverity(),
          emoji: isFirms ? "🛰️" : "🔥",
          source: isFirms ? SOURCES.wildfireFirms : SOURCES.wildfireNws,
          group: "free",
        });
      }
    });
  }

  if (log.possibleInversion) {
    badges.push({
      key: "inversion",
      label: "Inversion?",
      severity: inversionSeverity(),
      emoji: "🌫️",
      source: SOURCES.inversion,
      group: "free",
    });
  }

  // --- Ambee badges (trial) ---

  if (log.temperatureF != null && snap?.tempSource === "ambee_weather") {
    badges.push({
      key: "ambee-temp",
      label: `${Math.round(log.temperatureF)}°F${log.isExtremeTemp ? " extreme" : ""}`,
      severity: temperatureSeverity(log.temperatureF, log.isExtremeTemp),
      emoji: "🌡️",
      source: SOURCES.tempAmbee,
      group: "ambee",
    });
  }

  if (snap?.humidityPct != null) {
    const dew = snap.dewpointF != null ? ` · dew ${Math.round(snap.dewpointF)}°F` : "";
    badges.push({
      key: "ambee-humidity",
      label: `${Math.round(snap.humidityPct)}% humidity${dew}`,
      severity: humiditySeverity(snap.humidityPct),
      emoji: "💧",
      source: SOURCES.humidity,
      group: "ambee",
    });
  }

  if (log.aqi != null && snap?.aqiSource === "ambee") {
    const driver = snap.aqiPollutant ? ` ${snap.aqiPollutant}` : "";
    badges.push({
      key: "ambee-aqi",
      label: `AQI ${log.aqi}${log.aqiCategory ? ` (${log.aqiCategory})` : ""}${driver}`,
      severity: aqiSeverity(log.aqi),
      emoji: "💨",
      source: SOURCES.aqiAmbee,
      group: "ambee",
    });
  }

  if (snap?.pm25 != null) {
    badges.push({
      key: "ambee-pm25",
      label: `PM2.5 ${Math.round(snap.pm25)}`,
      severity: pm25Severity(snap.pm25),
      emoji: "🌫️",
      source: SOURCES.pm25,
      group: "ambee",
    });
  }

  if (snap?.ozonePpb != null) {
    badges.push({
      key: "ambee-ozone",
      label: `O₃ ${Math.round(snap.ozonePpb)} ppb`,
      severity: ozoneSeverity(snap.ozonePpb),
      emoji: "☀️",
      source: SOURCES.ozone,
      group: "ambee",
    });
  }

  if (snap?.pollen) {
    const risks = [
      { key: "tree", label: "Tree", risk: snap.pollen.treeRisk, count: snap.pollen.treeCount },
      { key: "grass", label: "Grass", risk: snap.pollen.grassRisk, count: snap.pollen.grassCount },
      { key: "weed", label: "Weed", risk: snap.pollen.weedRisk, count: snap.pollen.weedCount },
    ];
    const rank = (r: string | null) => {
      const x = (r ?? "").toLowerCase();
      if (x.includes("very")) return 4;
      if (x === "high") return 3;
      if (x === "moderate") return 2;
      if (x === "low") return 1;
      return 0;
    };
    const notable = risks.filter((r) => rank(r.risk) >= 2);
    const toShow = notable.length ? notable : risks.filter((r) => r.risk).slice(0, 1);
    toShow.forEach((r) => {
      const count = r.count != null ? ` ${r.count}` : "";
      badges.push({
        key: `ambee-pollen-${r.key}`,
        label: `${r.label} pollen ${r.risk ?? ""}${count}`.trim(),
        severity: pollenRiskSeverity(r.risk),
        emoji: "🌿",
        source: snap.pollen?.topSpecies
          ? `${SOURCES.pollen} Top species: ${snap.pollen.topSpecies}.`
          : SOURCES.pollen,
        group: "ambee",
      });
    });
  }

  {
    const fireLabels = parseWildfireLabels(log.wildfireSummary);
    fireLabels.forEach((name, i) => {
      const isAmbee = /^Ambee /i.test(name);
      if (isAmbee) {
        badges.push({
          key: `ambee-wildfire-${i}-${name}`,
          label: name,
          severity: wildfireSeverity(),
          emoji: "📍",
          source: SOURCES.wildfireAmbee,
          group: "ambee",
        });
      }
    });
  }

  return badges;
}
