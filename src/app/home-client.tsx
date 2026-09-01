"use client";

import { useCallback, useEffect, useState } from "react";
import {
  getAllLocalLogs,
  getPendingLocalLogs,
  markLocalSynced,
  markLocalSyncError,
  putLocalLog,
} from "@/lib/local-db";
import type { AttackLogDTO, Feeling, LocalLog } from "@/lib/types";
import {
  aqiSeverity,
  envStatusSeverity,
  inversionSeverity,
  severityStyle,
  temperatureSeverity,
  weatherAlertSeverity,
  wildfireSeverity,
  type Severity,
} from "@/lib/env-colors";

const FEELINGS: Feeling[] = ["skip", "ok", "mild", "bad"];
const DEMO_LAT = 39.7392;
const DEMO_LON = -104.9903;

type Badge = { key: string; label: string; severity: Severity };

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

function buildEnvBadges(log: AttackLogDTO): Badge[] {
  const badges: Badge[] = [
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
    badges.push({
      key: "weather",
      label: "weather alert",
      severity: weatherAlertSeverity(log.stormSummary),
    });
  }

  if (log.hasWildfireNearby) {
    badges.push({
      key: "wildfire",
      label: "wildfire/smoke",
      severity: wildfireSeverity(),
    });
  }

  if (log.possibleInversion) {
    badges.push({
      key: "inversion",
      label: "inversion?",
      severity: inversionSeverity(),
    });
  }

  return badges;
}

function EnvBadges({ log }: { log: AttackLogDTO | undefined }) {
  if (!log) {
    return <span style={{ color: "#888", fontSize: 12 }}>env: —</span>;
  }

  const badges = buildEnvBadges(log);

  return (
    <div>
      <span style={{ display: "inline-flex", gap: 4, flexWrap: "wrap" }}>
        {badges.map((b) => {
          const s = severityStyle(b.severity);
          return (
            <span
              key={b.key}
              style={{
                fontSize: 11,
                padding: "2px 6px",
                background: s.bg,
                color: s.color,
                borderRadius: 3,
                border: `1px solid ${s.border}`,
                fontWeight: b.severity === "red" || b.severity === "orange" ? 600 : 400,
              }}
            >
              {b.label}
            </span>
          );
        })}
      </span>
      {log.envStatus === "ready" && log.stormSummary ? (
        <div style={{ fontSize: 11, color: "#555", marginTop: 4 }}>Alert: {log.stormSummary}</div>
      ) : null}
      {log.envStatus === "ready" && log.wildfireSummary ? (
        <div style={{ fontSize: 11, color: "#555", marginTop: 2 }}>{log.wildfireSummary}</div>
      ) : null}
      {log.envStatus === "ready" && log.inversionNote ? (
        <div style={{ fontSize: 11, color: "#555", marginTop: 2 }}>{log.inversionNote}</div>
      ) : null}
      {log.envStatus === "ready" && log.aqi == null && log.temperatureF != null ? (
        <div style={{ fontSize: 11, color: "#888", marginTop: 4 }}>
          No AQI yet — add AIRNOW_API_KEY in Vercel for air quality.
        </div>
      ) : null}
    </div>
  );
}

export default function HomeClient() {
  const [feeling, setFeeling] = useState<Feeling>("ok");
  const [logs, setLogs] = useState<LocalLog[]>([]);
  const [enriched, setEnriched] = useState<Record<string, AttackLogDTO>>({});
  const [status, setStatus] = useState<string>("");
  const [busy, setBusy] = useState(false);
  const [demoMode, setDemoMode] = useState(false);

  const refresh = useCallback(async () => {
    const local = await getAllLocalLogs();
    setLogs(local);
    try {
      const res = await fetch("/api/logs");
      if (res.ok) {
        const data = (await res.json()) as { logs: AttackLogDTO[] };
        const map: Record<string, AttackLogDTO> = {};
        for (const row of data.logs) {
          map[row.id] = row;
        }
        setEnriched(map);
      }
    } catch {
      // server logs optional for display
    }
  }, []);

  useEffect(() => {
    const t = setTimeout(() => {
      setDemoMode(new URLSearchParams(window.location.search).get("demo") === "1");
      refresh();
    }, 0);
    return () => clearTimeout(t);
  }, [refresh]);

  const syncPending = useCallback(async () => {
    const pending = await getPendingLocalLogs();
    if (!pending.length) return;

    const res = await fetch("/api/logs/sync", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        logs: pending.map((l) => ({
          id: l.id,
          loggedAt: l.loggedAt,
          latitude: l.latitude,
          longitude: l.longitude,
          feeling: l.feeling,
        })),
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      for (const l of pending) {
        await markLocalSyncError(l.id, errText.slice(0, 200));
      }
      throw new Error(`Sync failed: ${res.status}`);
    }

    const data = (await res.json()) as {
      results: Array<
        | { id: string; ok: true; log: AttackLogDTO }
        | { id: string; ok: false; error: string }
      >;
    };

    const nextEnriched = { ...enriched };
    for (const result of data.results) {
      if (result.ok) {
        await markLocalSynced(result.id, result.log.envStatus);
        nextEnriched[result.id] = result.log;
      } else {
        await markLocalSyncError(result.id, result.error);
      }
    }
    setEnriched(nextEnriched);
  }, [enriched]);

  const logInhaler = useCallback(
    async (latitude: number, longitude: number) => {
      setBusy(true);
      setStatus("Saving…");
      try {
        const entry: LocalLog = {
          id: crypto.randomUUID(),
          loggedAt: new Date().toISOString(),
          latitude,
          longitude,
          feeling,
          syncStatus: "pending",
        };
        await putLocalLog(entry);
        setStatus("Saved locally, syncing…");
        await syncPending();
        await refresh();
        setStatus("Logged.");
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Log failed";
        setStatus(msg);
      } finally {
        setBusy(false);
      }
    },
    [feeling, refresh, syncPending],
  );

  function handleGeoLog() {
    if (!navigator.geolocation) {
      setStatus("Geolocation not available.");
      return;
    }
    setStatus("Getting location…");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        logInhaler(pos.coords.latitude, pos.coords.longitude);
      },
      (err) => {
        setStatus(`Location error: ${err.message}`);
      },
      { enableHighAccuracy: true, timeout: 15000 },
    );
  }

  function handleDemoLog() {
    logInhaler(DEMO_LAT, DEMO_LON);
  }

  return (
    <main style={{ maxWidth: 520, margin: "0 auto", padding: 16, fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 20, marginBottom: 8 }}>Asthma trigger log</h1>
      <p style={{ fontSize: 14, color: "#555", marginBottom: 16 }}>
        Log inhaler use with location; env data syncs in the background.
      </p>

      <section style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 13, marginBottom: 6 }}>How are you feeling?</div>
        <div style={{ display: "flex", gap: 6 }}>
          {FEELINGS.map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setFeeling(f)}
              style={{
                padding: "6px 12px",
                border: feeling === f ? "2px solid #333" : "1px solid #ccc",
                background: feeling === f ? "#eee" : "#fff",
                cursor: "pointer",
              }}
            >
              {f}
            </button>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: 16 }}>
        <button
          type="button"
          onClick={handleGeoLog}
          disabled={busy}
          style={{
            padding: "10px 16px",
            fontSize: 15,
            cursor: busy ? "default" : "pointer",
            background: "#2563eb",
            color: "#fff",
            border: "none",
            borderRadius: 4,
          }}
        >
          Log inhaler use
        </button>
        {demoMode && (
          <button
            type="button"
            onClick={handleDemoLog}
            disabled={busy}
            style={{
              marginLeft: 8,
              padding: "10px 16px",
              fontSize: 14,
              cursor: busy ? "default" : "pointer",
              background: "#6b7280",
              color: "#fff",
              border: "none",
              borderRadius: 4,
            }}
          >
            Demo log (Denver coords)
          </button>
        )}
      </section>

      {status && (
        <p style={{ fontSize: 13, color: "#444", marginBottom: 16 }}>{status}</p>
      )}

      <section>
        <h2 style={{ fontSize: 16, marginBottom: 8 }}>Recent logs</h2>
        {logs.length === 0 ? (
          <p style={{ fontSize: 13, color: "#888" }}>No logs yet.</p>
        ) : (
          <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
            {logs.slice(0, 20).map((log) => (
              <li
                key={log.id}
                style={{
                  borderBottom: "1px solid #ddd",
                  padding: "8px 0",
                  fontSize: 13,
                }}
              >
                <div style={{ marginBottom: 4 }}>
                  <strong>{formatTime(log.loggedAt)}</strong>
                  {log.feeling && (
                    <span style={{ marginLeft: 8, color: "#555" }}>feeling: {log.feeling}</span>
                  )}
                  <span style={{ marginLeft: 8, color: "#888", fontSize: 11 }}>
                    sync:{log.syncStatus}
                  </span>
                </div>
                <div style={{ color: "#666", fontSize: 12, marginBottom: 4 }}>
                  {log.latitude.toFixed(4)}, {log.longitude.toFixed(4)}
                </div>
                <EnvBadges log={enriched[log.id]} />
                {log.lastError && (
                  <div style={{ color: "#b91c1c", fontSize: 11, marginTop: 4 }}>{log.lastError}</div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  );
}
