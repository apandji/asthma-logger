"use client";

import { useCallback, useEffect, useState } from "react";
import {
  getAllLocalLogs,
  getPendingLocalLogs,
  markLocalSynced,
  markLocalSyncError,
  putLocalLog,
  updateLocalFeeling,
} from "@/lib/local-db";
import type { AttackLogDTO, Feeling, LocalLog } from "@/lib/types";
import { buildEnvBadges, severityStyle, type EnvBadge } from "@/lib/env-badges";
import { FEELING_OPTIONS, feelingDisplay } from "@/lib/feelings";

/** Demo coords for testing without GPS. Add ?demo=1 to the URL. */
const DEMO_LOCATIONS = {
  denver: {
    lat: 39.7392,
    lon: -104.9903,
    label: "Denver",
    hint: "often has storm/heat alerts",
  },
  wildfire: {
    lat: 41.7569,
    lon: -120.1561,
    label: "Northern CA",
    hint: "Red Flag / fire-weather area",
  },
} as const;

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

function EnvBadgeTag({ badge }: { badge: EnvBadge }) {
  const [showSource, setShowSource] = useState(false);
  const s = severityStyle(badge.severity);

  return (
    <span className="env-badge-wrap">
      <button
        type="button"
        className="env-badge"
        onClick={() => setShowSource((v) => !v)}
        aria-expanded={showSource}
        aria-describedby={showSource ? `tip-${badge.key}` : undefined}
        style={{
          fontSize: 11,
          padding: "2px 6px",
          background: s.bg,
          color: s.color,
          borderRadius: 3,
          border: `1px solid ${s.border}`,
          fontWeight: badge.severity === "red" || badge.severity === "orange" ? 600 : 400,
          cursor: "pointer",
        }}
      >
        {badge.emoji} {badge.label}
      </button>
      <span
        id={`tip-${badge.key}`}
        role="tooltip"
        className={`env-badge-tip${showSource ? " env-badge-tip--open" : ""}`}
      >
        {badge.source}
      </span>
    </span>
  );
}

function EnvBadges({ log }: { log: AttackLogDTO | undefined }) {
  if (!log) {
    return <span style={{ color: "#888", fontSize: 12 }}>env: —</span>;
  }

  const badges = buildEnvBadges(log);

  return (
    <div>
      <span style={{ display: "inline-flex", gap: 4, flexWrap: "wrap", alignItems: "flex-start" }}>
        {badges.map((b) => (
          <EnvBadgeTag key={b.key} badge={b} />
        ))}
      </span>
      {log.envStatus === "ready" && log.inversionNote ? (
        <div style={{ fontSize: 11, color: "#555", marginTop: 4 }} title={log.inversionNote}>
          {log.inversionNote}
        </div>
      ) : null}
      {log.envStatus === "ready" && log.aqi == null && log.temperatureF != null ? (
        <div style={{ fontSize: 11, color: "#888", marginTop: 4 }}>
          No AQI — add AIRNOW_API_KEY in Vercel for air quality.
        </div>
      ) : null}
    </div>
  );
}

function FeelingTags({
  logId,
  current,
  onSelect,
  highlight,
}: {
  logId: string;
  current: Feeling | null;
  onSelect: (id: string, feeling: Feeling | null) => void;
  highlight?: boolean;
}) {
  return (
    <div style={{ marginTop: 6 }}>
      <div style={{ fontSize: 11, color: highlight ? "#1d4ed8" : "#666", marginBottom: 4 }}>
        {highlight ? "How do you feel? (optional)" : "Feeling (optional)"}
      </div>
      <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
        {FEELING_OPTIONS.map((f) => {
          const selected = current === f.value;
          return (
            <button
              key={f.value}
              type="button"
              onClick={() => onSelect(logId, selected ? null : f.value)}
              style={{
                padding: "4px 8px",
                fontSize: 12,
                border: selected ? "2px solid #2563eb" : "1px solid #ccc",
                background: selected ? "#eff6ff" : "#fff",
                borderRadius: 12,
                cursor: "pointer",
              }}
            >
              {f.emoji} {f.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

export default function HomeClient() {
  const [logs, setLogs] = useState<LocalLog[]>([]);
  const [enriched, setEnriched] = useState<Record<string, AttackLogDTO>>({});
  const [status, setStatus] = useState<string>("");
  const [busy, setBusy] = useState(false);
  const [demoMode, setDemoMode] = useState(false);
  const [highlightLogId, setHighlightLogId] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const local = await getAllLocalLogs();
    setLogs(local);
    try {
      const res = await fetch("/api/logs", { cache: "no-store" });
      if (res.ok) {
        const data = (await res.json()) as { logs: AttackLogDTO[] };
        const map: Record<string, AttackLogDTO> = {};
        for (const row of data.logs) {
          map[row.id] = row;
        }
        setEnriched(map);
      }
    } catch {
      // fall back to serverLog stored on each local row
    }
  }, []);

  useEffect(() => {
    const t = setTimeout(() => {
      setDemoMode(new URLSearchParams(window.location.search).get("demo") === "1");
      void refresh();
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

    for (const result of data.results) {
      if (result.ok) {
        await markLocalSynced(result.id, result.log);
      } else {
        await markLocalSyncError(result.id, result.error);
      }
    }
  }, []);

  const setFeeling = useCallback(
    async (logId: string, feeling: Feeling | null) => {
      await updateLocalFeeling(logId, feeling);
      setLogs((prev) => prev.map((l) => (l.id === logId ? { ...l, feeling } : l)));
      setEnriched((prev) => {
        const row = prev[logId];
        if (!row) return prev;
        return { ...prev, [logId]: { ...row, feeling } };
      });

      try {
        const res = await fetch(`/api/logs/${logId}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ feeling }),
        });
        if (res.ok) {
          const data = (await res.json()) as { log: AttackLogDTO };
          await updateLocalFeeling(logId, feeling);
          setEnriched((prev) => ({ ...prev, [logId]: data.log }));
        }
      } catch {
        // feeling saved locally; will sync on next full sync if needed
      }
      setHighlightLogId(null);
      void refresh();
    },
    [refresh],
  );

  const logInhaler = useCallback(
    async (latitude: number, longitude: number) => {
      setBusy(true);
      setStatus("Getting location…");
      try {
        const id = crypto.randomUUID();
        const entry: LocalLog = {
          id,
          loggedAt: new Date().toISOString(),
          latitude,
          longitude,
          feeling: null,
          syncStatus: "pending",
        };
        await putLocalLog(entry);
        setStatus("Saved — syncing env…");
        await syncPending();
        await refresh();
        setHighlightLogId(id);
        setStatus("Logged. Add how you feel below (optional).");
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Log failed";
        setStatus(msg);
      } finally {
        setBusy(false);
      }
    },
    [refresh, syncPending],
  );

  function handleGeoLog() {
    if (!navigator.geolocation) {
      setStatus("Geolocation not available.");
      return;
    }
    setStatus("Getting location…");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        void logInhaler(pos.coords.latitude, pos.coords.longitude);
      },
      (err) => {
        setStatus(`Location error: ${err.message}`);
      },
      { enableHighAccuracy: true, timeout: 15000 },
    );
  }

  function handleDemoLog(location: keyof typeof DEMO_LOCATIONS) {
    const demo = DEMO_LOCATIONS[location];
    void logInhaler(demo.lat, demo.lon);
  }

  return (
    <main style={{ maxWidth: 520, margin: "0 auto", padding: 16, fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 20, marginBottom: 8 }}>Asthma trigger log</h1>
      <p style={{ fontSize: 14, color: "#555", marginBottom: 16 }}>
        Tap when you use your inhaler. Hover or tap env tags for data sources.
      </p>

      <section style={{ marginBottom: 16 }}>
        <button
          type="button"
          onClick={handleGeoLog}
          disabled={busy}
          style={{
            width: "100%",
            padding: "14px 16px",
            fontSize: 16,
            fontWeight: 600,
            cursor: busy ? "default" : "pointer",
            background: busy ? "#94a3b8" : "#2563eb",
            color: "#fff",
            border: "none",
            borderRadius: 6,
          }}
        >
          {busy ? "Logging…" : "Log inhaler use"}
        </button>
        {demoMode && (
          <div style={{ marginTop: 8, display: "flex", flexDirection: "column", gap: 6 }}>
            <span style={{ fontSize: 12, color: "#666" }}>Demo locations (?demo=1):</span>
            {(Object.entries(DEMO_LOCATIONS) as [keyof typeof DEMO_LOCATIONS, (typeof DEMO_LOCATIONS)[keyof typeof DEMO_LOCATIONS]][]).map(
              ([key, demo]) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => handleDemoLog(key)}
                  disabled={busy}
                  style={{
                    padding: "8px 12px",
                    fontSize: 13,
                    textAlign: "left",
                    cursor: busy ? "default" : "pointer",
                    background: key === "wildfire" ? "#fef2f2" : "#f3f4f6",
                    color: "#111",
                    border: key === "wildfire" ? "1px solid #fca5a5" : "1px solid #d1d5db",
                    borderRadius: 4,
                  }}
                >
                  Demo: {demo.label} — {demo.hint}
                </button>
              ),
            )}
          </div>
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
            {logs.slice(0, 20).map((log) => {
              const server = enriched[log.id] ?? log.serverLog;
              const feeling =
                (server?.feeling as Feeling | null | undefined) ?? log.feeling;
              const feelingLabel = feelingDisplay(feeling);
              return (
                <li
                  key={log.id}
                  style={{
                    borderBottom: "1px solid #ddd",
                    padding: "10px 0",
                    fontSize: 13,
                    background: highlightLogId === log.id ? "#f8fafc" : "transparent",
                    borderRadius: highlightLogId === log.id ? 4 : 0,
                    paddingLeft: highlightLogId === log.id ? 6 : 0,
                    paddingRight: highlightLogId === log.id ? 6 : 0,
                  }}
                >
                  <div style={{ marginBottom: 4 }}>
                    <strong>{formatTime(log.loggedAt)}</strong>
                    {feelingLabel ? (
                      <span style={{ marginLeft: 8, color: "#555" }}>{feelingLabel}</span>
                    ) : null}
                    <span style={{ marginLeft: 8, color: "#888", fontSize: 11 }}>
                      sync:{log.syncStatus}
                    </span>
                  </div>
                  <div style={{ color: "#666", fontSize: 12, marginBottom: 4 }}>
                    {log.latitude.toFixed(4)}, {log.longitude.toFixed(4)}
                  </div>
                  <EnvBadges log={server} />
                  <FeelingTags
                    logId={log.id}
                    current={feeling ?? null}
                    onSelect={setFeeling}
                    highlight={highlightLogId === log.id}
                  />
                  {log.lastError && (
                    <div style={{ color: "#b91c1c", fontSize: 11, marginTop: 4 }}>
                      {log.lastError}
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </main>
  );
}
