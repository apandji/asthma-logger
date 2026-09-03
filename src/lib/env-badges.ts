import {
  aqiSeverity,
  envStatusSeverity,
  humiditySeverity,
  ozoneSeverity,
  pm25Severity,
  pollenRiskSeverity,
  severityStyle,
  temperatureSeverity,
  weatherAlertSeverity,
  wildfireSeverity,
  type Severity,
} from "./env-colors";
import type { AttackLogDTO, EnvPollenSnapshot, EnvSnapshot, EnvSourceValues } from "./types";

export type EnvBadgeGroup = "free" | "ambee" | "meta" | "extra";

export type EnvBadge = {
  key: string;
  label: string;
  severity: Severity;
  emoji: string;
  /** Shown on hover / long-press */
  source: string;
  group: EnvBadgeGroup;
  unavailable?: boolean;
};

export { severityStyle };

const SOURCES = {
  status: "App — sync & enrichment status",
  tempNws: "NWS forecast period — api.weather.gov (not a station reading)",
  tempAmbee: "Ambee weather — outdoor model/obs blend (~hourly). Not indoor air.",
  humidityNone: "No free humidity API — NWS forecast does not include relative humidity at this endpoint.",
  humidityAmbee: "Ambee weather humidity / dewpoint — outdoor.",
  aqiAirnow: "EPA AirNow official monitor — regional, often 5–25+ miles away",
  aqiAmbee: "Ambee outdoor AQ model (~500 m claimed). Not indoor air.",
  pm25Airnow: "AirNow PM2.5 monitor reading — regional station, not hyperlocal.",
  pm25Ambee: "Ambee PM2.5 — outdoor ambient, modeled. Not the air indoors.",
  ozoneAirnow: "AirNow ozone monitor — regional station.",
  ozoneAmbee: "Ambee ground-level ozone (AQ API). Not weather column ozone.",
  pollenNone: "No free pollen API in this app.",
  pollenAmbee: "Ambee pollen model (NAB-style risk). Outdoor; not a backyard trap.",
  wildfireNws: "NWS fire/smoke alerts — api.weather.gov",
  wildfireFirms: "NASA FIRMS satellite hotspots — firms.modaps.eosdis.nasa.gov",
  wildfireAmbee: "Ambee fire detection — nearest hotspot distance, not smoke at this pin. Smoke ≈ PM2.5.",
  weather: "NWS active alerts — api.weather.gov",
  stormsAmbee: "Ambee natural disasters (SW severe storm, TC cyclone) — includes distant events. Distance is from this pin.",
  wildfireDisaster: "Ambee disasters WF. Distant wildfires can move smoke; pair with PM2.5. Not a volcano.",
  volcanoAmbee: "Ambee disasters VO — volcanic ash can travel far. This is an air-quality signal, not a wildfire.",
  extremeTempAmbee: "Ambee disasters ET — heat/cold wave, not a thermometer reading.",
} as const;

const EMPTY_SOURCES: EnvSourceValues = {
  temperatureF: null,
  humidityPct: null,
  dewpointF: null,
  aqi: null,
  aqiCategory: null,
  aqiPollutant: null,
  pm25: null,
  ozonePpb: null,
  pollen: null,
  wildfire: null,
  storms: null,
  extremeTempEvent: null,
  volcano: null,
  disasters: null,
};

function splitAlerts(summary: string | null): string[] {
  if (!summary) return [];
  return summary
    .split(";")
    .map((s) => s.trim())
    .filter(Boolean);
}

/** NWS heat/cold/freeze — belongs on Temp, not Storms. */
function isExtremeWeatherAlert(name: string): boolean {
  const hay = name.toLowerCase();
  return (
    hay.includes("heat") ||
    hay.includes("cold") ||
    hay.includes("freeze") ||
    hay.includes("frost") ||
    hay.includes("wind chill")
  );
}

function statusEmoji(status: string): string {
  if (status === "ready") return "✅";
  if (status === "failed") return "❌";
  if (status === "pending") return "⏳";
  return "📡";
}

function pollenSummary(pollen: EnvPollenSnapshot | null): { label: string; risk: string | null } | null {
  if (!pollen) return null;
  const risks = [
    { label: "Tree", risk: pollen.treeRisk, count: pollen.treeCount },
    { label: "Grass", risk: pollen.grassRisk, count: pollen.grassCount },
    { label: "Weed", risk: pollen.weedRisk, count: pollen.weedCount },
  ];
  const rank = (r: string | null) => {
    const x = (r ?? "").toLowerCase();
    if (x.includes("very")) return 4;
    if (x === "high") return 3;
    if (x === "moderate") return 2;
    if (x === "low") return 1;
    return 0;
  };
  const sorted = [...risks].sort((a, b) => rank(b.risk) - rank(a.risk));
  const top = sorted.find((r) => r.risk);
  if (!top) return null;
  const count = top.count != null ? ` ${top.count}` : "";
  return { label: `${top.label} ${top.risk ?? ""}${count}`.trim(), risk: top.risk };
}

function hasAnyValue(src: EnvSourceValues): boolean {
  return (
    src.temperatureF != null ||
    src.humidityPct != null ||
    src.aqi != null ||
    src.pm25 != null ||
    src.ozonePpb != null ||
    src.pollen != null ||
    src.wildfire != null ||
    src.storms != null ||
    src.extremeTempEvent != null ||
    src.volcano != null
  );
}

function unavailableBadge(
  key: string,
  emoji: string,
  metric: string,
  source: string,
  group: EnvBadgeGroup,
): EnvBadge {
  return { key, label: `${metric} —`, severity: "neutral", emoji, source, group, unavailable: true };
}

function buildSourceBadges(
  src: EnvSourceValues,
  group: "free" | "ambee",
  isExtremeTemp: boolean,
): EnvBadge[] {
  const prefix = group;
  const badges: EnvBadge[] = [];

  // Temperature
  if (src.temperatureF != null) {
    badges.push({
      key: `${prefix}-temp`,
      label: `${Math.round(src.temperatureF)}°F${isExtremeTemp ? " extreme" : ""}`,
      severity: temperatureSeverity(src.temperatureF, isExtremeTemp),
      emoji: "🌡️",
      source: group === "free" ? SOURCES.tempNws : SOURCES.tempAmbee,
      group,
    });
  } else {
    badges.push(unavailableBadge(`${prefix}-temp`, "🌡️", "Temp", group === "free" ? SOURCES.tempNws : SOURCES.tempAmbee, group));
  }

  // Humidity
  if (src.humidityPct != null) {
    const dew = src.dewpointF != null ? ` · dew ${Math.round(src.dewpointF)}°F` : "";
    badges.push({
      key: `${prefix}-humidity`,
      label: `${Math.round(src.humidityPct)}%${dew}`,
      severity: humiditySeverity(src.humidityPct),
      emoji: "💧",
      source: group === "free" ? SOURCES.humidityNone : SOURCES.humidityAmbee,
      group,
    });
  } else {
    badges.push(
      unavailableBadge(
        `${prefix}-humidity`,
        "💧",
        "Humidity",
        group === "free" ? SOURCES.humidityNone : SOURCES.humidityAmbee,
        group,
      ),
    );
  }

  // AQI
  if (src.aqi != null) {
    const driver = src.aqiPollutant ? ` · ${src.aqiPollutant}` : "";
    badges.push({
      key: `${prefix}-aqi`,
      label: `AQI ${src.aqi}${src.aqiCategory ? ` (${src.aqiCategory})` : ""}${driver}`,
      severity: aqiSeverity(src.aqi),
      emoji: "💨",
      source: group === "free" ? SOURCES.aqiAirnow : SOURCES.aqiAmbee,
      group,
    });
  } else {
    badges.push(
      unavailableBadge(`${prefix}-aqi`, "💨", "AQI", group === "free" ? SOURCES.aqiAirnow : SOURCES.aqiAmbee, group),
    );
  }

  // PM2.5
  if (src.pm25 != null) {
    badges.push({
      key: `${prefix}-pm25`,
      label: `PM2.5 ${Math.round(src.pm25)}`,
      severity: pm25Severity(src.pm25),
      emoji: "🌫️",
      source: group === "free" ? SOURCES.pm25Airnow : SOURCES.pm25Ambee,
      group,
    });
  } else {
    badges.push(
      unavailableBadge(
        `${prefix}-pm25`,
        "🌫️",
        "PM2.5",
        group === "free" ? SOURCES.pm25Airnow : SOURCES.pm25Ambee,
        group,
      ),
    );
  }

  // Ozone
  if (src.ozonePpb != null) {
    badges.push({
      key: `${prefix}-ozone`,
      label: `O₃ ${Math.round(src.ozonePpb)} ppb`,
      severity: ozoneSeverity(src.ozonePpb),
      emoji: "☀️",
      source: group === "free" ? SOURCES.ozoneAirnow : SOURCES.ozoneAmbee,
      group,
    });
  } else {
    badges.push(
      unavailableBadge(
        `${prefix}-ozone`,
        "☀️",
        "O₃",
        group === "free" ? SOURCES.ozoneAirnow : SOURCES.ozoneAmbee,
        group,
      ),
    );
  }

  // Pollen
  const pollen = pollenSummary(src.pollen);
  if (pollen) {
    badges.push({
      key: `${prefix}-pollen`,
      label: pollen.label,
      severity: pollenRiskSeverity(pollen.risk),
      emoji: "🌿",
      source:
        group === "free"
          ? SOURCES.pollenNone
          : src.pollen?.topSpecies
            ? `${SOURCES.pollenAmbee} Top species: ${src.pollen.topSpecies}.`
            : SOURCES.pollenAmbee,
      group,
    });
  } else {
    badges.push(
      unavailableBadge(
        `${prefix}-pollen`,
        "🌿",
        "Pollen",
        group === "free" ? SOURCES.pollenNone : SOURCES.pollenAmbee,
        group,
      ),
    );
  }

  // Wildfire
  if (src.wildfire) {
    const isFirms = /FIRMS/i.test(src.wildfire);
    badges.push({
      key: `${prefix}-wildfire`,
      label: src.wildfire,
      severity: wildfireSeverity(),
      emoji: group === "ambee" ? "📍" : isFirms ? "🛰️" : "🔥",
      source: group === "free" ? (isFirms ? SOURCES.wildfireFirms : SOURCES.wildfireNws) : SOURCES.wildfireAmbee,
      group,
    });
  } else {
    badges.push(
      unavailableBadge(
        `${prefix}-wildfire`,
        "🔥",
        "Fire",
        group === "free" ? SOURCES.wildfireFirms : SOURCES.wildfireAmbee,
        group,
      ),
    );
  }

  return badges;
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
  const free = snap?.v === 2 ? snap.free : EMPTY_SOURCES;
  const ambee = snap?.v === 2 ? snap.ambee : EMPTY_SOURCES;
  const hasAmbee = hasAnyValue(ambee);
  const weatherError = snap?.v === 2 ? snap.ambeeErrors?.find((e) => /^weather:/i.test(e)) : undefined;

  badges.push(...buildSourceBadges(free, "free", log.isExtremeTemp));

  if (hasAmbee) {
    const ambeeBadges = buildSourceBadges(ambee, "ambee", log.isExtremeTemp);
    if (weatherError) {
      for (const b of ambeeBadges) {
        if (b.key === "ambee-temp" || b.key === "ambee-humidity") {
          b.source = `${b.source} Fetch error: ${weatherError}`;
        }
      }
    }
    badges.push(...ambeeBadges);
  }

  // Free-only extras (alerts, inversion) — not part of the comparison grid
  if (log.hasStormAlert) {
    const alerts = splitAlerts(log.stormSummary).filter((name) => !isExtremeWeatherAlert(name));
    if (alerts.length === 0) {
      badges.push({
        key: "extra-weather-0",
        label: "Weather alert",
        severity: weatherAlertSeverity(null),
        emoji: "⚠️",
        source: SOURCES.weather,
        group: "extra",
      });
    } else {
      alerts.forEach((name, i) => {
        badges.push({
          key: `extra-weather-${i}-${name}`,
          label: name,
          severity: weatherAlertSeverity(name),
          emoji: "⚠️",
          source: SOURCES.weather,
          group: "extra",
        });
      });
    }
  }

  return badges;
}

/** Whether the log has a v2 snapshot with Ambee comparison data */
export function hasAmbeeComparison(snap: EnvSnapshot | null | undefined): boolean {
  if (!snap || snap.v !== 2) return false;
  return hasAnyValue(snap.ambee);
}

export type EnvSignalValue = {
  text: string;
  detail?: string;
  severity: Severity;
  source: string;
  unavailable?: boolean;
};

export type EnvSignalRow = {
  key: string;
  question: string;
  emoji: string;
  free: EnvSignalValue;
  ambee: EnvSignalValue;
};

function missing(source: string): EnvSignalValue {
  return { text: "—", severity: "neutral", source, unavailable: true };
}

function shortenFire(label: string, group: "free" | "ambee"): string {
  const firms = label.match(/(\d+)\s+FIRMS hotspot/i);
  if (firms) return `${firms[1]} nearby (~50 km)`;
  const km = label.match(/(\d+(?:\.\d+)?)\s*km/i);
  if (group === "ambee" && km) return `${km[1]} km away`;
  return label.replace(/^Ambee\s+/i, "").replace(/^detected\s+/i, "");
}

function airText(src: EnvSourceValues): { text: string; detail?: string } | null {
  if (src.aqi == null && src.pm25 == null && src.ozonePpb == null) return null;
  const parts: string[] = [];
  if (src.aqi != null) {
    parts.push(`AQI ${src.aqi}${src.aqiCategory ? ` ${src.aqiCategory}` : ""}`);
  }
  const extras: string[] = [];
  if (src.pm25 != null) extras.push(`PM2.5 ${Math.round(src.pm25)}`);
  if (src.ozonePpb != null) extras.push(`O₃ ${Math.round(src.ozonePpb)}`);
  return { text: parts.join(" · ") || extras.join(" · "), detail: parts.length ? extras.join(" · ") || undefined : undefined };
}

/** User-facing questions, with Free vs Ambee answers side by side. */
export function buildEnvSignals(log: AttackLogDTO): {
  status: EnvSignalValue;
  rows: EnvSignalRow[];
  compare: boolean;
} {
  const snap = log.snapshot;
  const free = snap?.v === 2 ? snap.free : EMPTY_SOURCES;
  const ambee = snap?.v === 2 ? snap.ambee : EMPTY_SOURCES;
  const compare = hasAnyValue(ambee);
  const weatherError = snap?.v === 2 ? snap.ambeeErrors?.find((e) => /^weather:/i.test(e)) : undefined;

  const status: EnvSignalValue = {
    text: `env:${log.envStatus}`,
    severity: envStatusSeverity(log.envStatus),
    source: SOURCES.status,
  };

  if (log.envStatus !== "ready") {
    return { status, rows: [], compare: false };
  }

  const freeTemp = free.temperatureF ?? (snap?.v === 2 ? null : log.temperatureF);
  const ambeeTemp = ambee.temperatureF;
  const freeAir = airText(free);
  const ambeeAir = airText(ambee);
  const freePollen = pollenSummary(free.pollen);
  const ambeePollen = pollenSummary(ambee.pollen);
  const stormsFromSnap = free.storms;
  const storms = splitAlerts(stormsFromSnap ?? log.stormSummary).filter((name) => !isExtremeWeatherAlert(name));
  const stormLabel = storms.length ? storms.join(", ") : null;

  const rows: EnvSignalRow[] = [
    {
      key: "temp",
      question: "Temp",
      emoji: "🌡️",
      free:
        freeTemp != null
          ? {
              text: `${Math.round(freeTemp)}°F`,
              detail: free.extremeTempEvent ?? undefined,
              severity: temperatureSeverity(freeTemp, log.isExtremeTemp),
              source: SOURCES.tempNws,
            }
          : missing(SOURCES.tempNws),
      ambee:
        ambeeTemp != null || ambee.extremeTempEvent
          ? {
              text: ambeeTemp != null ? `${Math.round(ambeeTemp)}°F` : "—",
              detail: ambee.extremeTempEvent ?? undefined,
              severity:
                ambeeTemp != null
                  ? temperatureSeverity(ambeeTemp, log.isExtremeTemp)
                  : ambee.extremeTempEvent
                    ? "orange"
                    : "neutral",
              source: ambee.extremeTempEvent ? `${SOURCES.tempAmbee} ${SOURCES.extremeTempAmbee}` : SOURCES.tempAmbee,
            }
          : missing(weatherError ? `${SOURCES.tempAmbee} ${weatherError}` : SOURCES.tempAmbee),
    },
    {
      key: "humidity",
      question: "Humidity",
      emoji: "💧",
      free:
        free.humidityPct != null
          ? {
              text: `${Math.round(free.humidityPct)}%`,
              severity: humiditySeverity(free.humidityPct),
              source: SOURCES.humidityNone,
            }
          : missing(SOURCES.humidityNone),
      ambee:
        ambee.humidityPct != null
          ? {
              text: `${Math.round(ambee.humidityPct)}%`,
              detail: ambee.dewpointF != null ? `dew ${Math.round(ambee.dewpointF)}°F` : undefined,
              severity: humiditySeverity(ambee.humidityPct),
              source: SOURCES.humidityAmbee,
            }
          : missing(weatherError ? `${SOURCES.humidityAmbee} ${weatherError}` : SOURCES.humidityAmbee),
    },
    {
      key: "air",
      question: "Air",
      emoji: "💨",
      free: freeAir
        ? {
            text: freeAir.text,
            detail: freeAir.detail,
            severity: free.aqi != null ? aqiSeverity(free.aqi) : free.pm25 != null ? pm25Severity(free.pm25) : "neutral",
            source: SOURCES.aqiAirnow,
          }
        : missing(SOURCES.aqiAirnow),
      ambee: ambeeAir || ambee.volcano
        ? {
            text: ambeeAir?.text ?? "—",
            detail: [ambeeAir?.detail, ambee.volcano].filter(Boolean).join(" · ") || undefined,
            severity: ambee.aqi != null ? aqiSeverity(ambee.aqi) : ambee.pm25 != null ? pm25Severity(ambee.pm25) : ambee.volcano ? "yellow" : "neutral",
            source: ambee.volcano ? `${SOURCES.aqiAmbee} ${SOURCES.volcanoAmbee}` : SOURCES.aqiAmbee,
          }
        : missing(SOURCES.aqiAmbee),
    },
    {
      key: "pollen",
      question: "Pollen",
      emoji: "🌿",
      free: freePollen
        ? { text: freePollen.label, severity: pollenRiskSeverity(freePollen.risk), source: SOURCES.pollenNone }
        : missing(SOURCES.pollenNone),
      ambee: ambeePollen
        ? {
            text: ambeePollen.label,
            detail: ambee.pollen?.topSpecies ?? undefined,
            severity: pollenRiskSeverity(ambeePollen.risk),
            source: ambee.pollen?.topSpecies
              ? `${SOURCES.pollenAmbee} Top species: ${ambee.pollen.topSpecies}.`
              : SOURCES.pollenAmbee,
          }
        : missing(SOURCES.pollenAmbee),
    },
    {
      key: "storms",
      question: "Storms?",
      emoji: "⚠️",
      free: stormLabel
        ? { text: stormLabel, severity: weatherAlertSeverity(stormLabel), source: SOURCES.weather }
        : { text: "None", severity: "green", source: SOURCES.weather },
      ambee: ambee.storms
        ? { text: ambee.storms, severity: weatherAlertSeverity(ambee.storms), source: SOURCES.stormsAmbee }
        : { text: "None in region", severity: "green", source: SOURCES.stormsAmbee },
    },
    {
      key: "wildfire",
      question: "Wildfires?",
      emoji: "🔥",
      free: free.wildfire
        ? {
            text: shortenFire(free.wildfire, "free"),
            severity: wildfireSeverity(),
            source: /FIRMS/i.test(free.wildfire) ? SOURCES.wildfireFirms : SOURCES.wildfireNws,
          }
        : { text: "None nearby", severity: "green", source: SOURCES.wildfireFirms },
      ambee: ambee.wildfire
        ? {
            text: shortenFire(ambee.wildfire, "ambee"),
            severity: wildfireSeverity(),
            source: `${SOURCES.wildfireAmbee} ${SOURCES.wildfireDisaster}`,
          }
        : { text: "None in region", severity: "green", source: SOURCES.wildfireDisaster },
    },
  ];

  return { status, rows, compare };
}
