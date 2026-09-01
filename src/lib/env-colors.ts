/** Severity palette for env badges */
export type Severity = "info" | "green" | "yellow" | "orange" | "red" | "neutral";

const STYLES: Record<Severity, { bg: string; border: string; color: string }> = {
  info: { bg: "#dbeafe", border: "#93c5fd", color: "#1e40af" },
  green: { bg: "#dcfce7", border: "#86efac", color: "#166534" },
  yellow: { bg: "#fef9c3", border: "#fde047", color: "#854d0e" },
  orange: { bg: "#ffedd5", border: "#fdba74", color: "#c2410c" },
  red: { bg: "#fee2e2", border: "#fca5a5", color: "#b91c1c" },
  neutral: { bg: "#f3f4f6", border: "#d1d5db", color: "#4b5563" },
};

export function severityStyle(severity: Severity) {
  return STYLES[severity];
}

/** Sync / fetch status — informational, not a health signal */
export function envStatusSeverity(status: string): Severity {
  if (status === "ready") return "info";
  if (status === "failed") return "red";
  return "neutral"; // pending, skipped
}

/** EPA AQI breakpoints */
export function aqiSeverity(aqi: number): Severity {
  if (aqi <= 50) return "green";
  if (aqi <= 100) return "yellow";
  if (aqi <= 150) return "orange";
  return "red";
}

/** Temp bands relevant to asthma triggers */
export function temperatureSeverity(tempF: number, isExtreme: boolean): Severity {
  if (isExtreme || tempF >= 95 || tempF <= 20) return "red";
  if (tempF >= 85 || tempF <= 32) return "orange";
  if (tempF >= 75 || tempF <= 40) return "yellow";
  return "green";
}

/** NWS-style alerts — keyword severity on event/summary text */
export function weatherAlertSeverity(summary: string | null): Severity {
  if (!summary) return "orange";
  const hay = summary.toLowerCase();
  if (
    hay.includes("tornado") ||
    hay.includes("hurricane") ||
    hay.includes("extreme") ||
    hay.includes("emergency") ||
    hay.includes("warning") && (hay.includes("thunder") || hay.includes("severe"))
  ) {
    return "red";
  }
  if (
    hay.includes("advisory") ||
    hay.includes("watch") ||
    hay.includes("heat") ||
    hay.includes("cold") ||
    hay.includes("air quality") ||
    hay.includes("smoke")
  ) {
    return "orange";
  }
  return "yellow";
}

export function wildfireSeverity(): Severity {
  return "red";
}

/** Heuristic only — caution, not confirmed */
export function inversionSeverity(): Severity {
  return "yellow";
}
