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
import { buildEnvSignals, type EnvSignalValue } from "@/lib/env-badges";
import { canAttributeRegionalSmoke, wildfireDisasterHits } from "@/lib/ambee";
import { formatWildfireLabel, isLocalAirSmoky } from "@/lib/hazard-copy";
import { FEELING_OPTIONS, feelingDisplay } from "@/lib/feelings";
import type { PatternReport } from "@/lib/patterns";

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

/** Render PM2.5 with a subscript 2.5 so it doesn't read as "PM 25". */
function EnvText({ children }: { children: string }) {
  const parts = children.split(/(PM2\.5)/g);
  return (
    <>
      {parts.map((part, i) =>
        part === "PM2.5" ? (
          <span key={i}>
            PM<sub>2.5</sub>
          </span>
        ) : (
          part
        ),
      )}
    </>
  );
}

function formatWhen(iso: string): { date: string; time: string } {
  try {
    const d = new Date(iso);
    const now = new Date();
    const time = d.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
    const startOfDay = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
    const delta = (startOfDay(now) - startOfDay(d)) / 86400000;
    if (delta === 0) return { date: "Today", time };
    if (delta === 1) return { date: "Yesterday", time };
    return {
      date: d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" }),
      time,
    };
  } catch {
    return { date: iso, time: "" };
  }
}

function syncLabel(status: LocalLog["syncStatus"]): { text: string; kind: "busy" | "err" } | null {
  if (status === "pending") return { text: "Saving…", kind: "busy" };
  if (status === "error") return { text: "Couldn’t save", kind: "err" };
  return null;
}

function envStatusCopy(status: string): string | null {
  if (status === "pending") return "Fetching outdoor air…";
  if (status === "failed") return "Couldn’t fetch outdoor air";
  if (status === "skipped") return "Outdoor air skipped";
  return null;
}

function SignalValue({ value, id }: { value: EnvSignalValue; id: string }) {
  const [open, setOpen] = useState(false);
  const sev = value.unavailable ? "neutral" : value.severity;
  const alert = !value.unavailable && (value.severity === "red" || value.severity === "orange");

  return (
    <span className="env-badge-wrap">
      <button
        type="button"
        className={`env-badge sev-${sev}${value.unavailable ? " env-badge--muted" : ""}${alert ? " env-badge--alert" : ""}`}
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-controls={`src-${id}`}
      >
        <EnvText>{value.text}</EnvText>
        {value.detail ? (
          <span className={`env-badge-detail${value.unavailable ? " env-badge-detail--muted" : ""}`}>
            <EnvText>{value.detail}</EnvText>
          </span>
        ) : null}
      </button>
      {open ? (
        <span id={`src-${id}`} className="env-source-note">
          <EnvText>{value.source}</EnvText>
        </span>
      ) : null}
    </span>
  );
}

/** Honest collapsed fire line — local WF, regional smoke (PM-gated), or NWS. */
function collapsedFireHint(log: AttackLogDTO): string | null {
  const summary = log.wildfireSummary ?? "";
  const snapWild =
    log.snapshot?.v === 2 ? (log.snapshot.free.wildfire ?? log.snapshot.ambee.wildfire ?? "") : "";
  const hay = `${summary} | ${snapWild}`;
  const credibleWf =
    log.snapshot?.v === 2 ? wildfireDisasterHits(log.snapshot.ambee.disasters) : [];
  const hasCredibleLocalWf = credibleWf.some((h) => h.km == null || h.km <= 80);
  const airSmoky = isLocalAirSmoky({
    pm25: log.snapshot?.v === 2 ? (log.snapshot.free.pm25 ?? log.snapshot.ambee.pm25) : null,
    aqi: log.aqi,
    nwsSmoke: /smoke/i.test(hay),
  });
  const hasRegional =
    /regional smoke/i.test(hay) ||
    (() => {
      if (!airSmoky && !/smoke/i.test(hay)) return false;
      return credibleWf.some(
        (h) =>
          h.km != null &&
          h.km > 80 &&
          canAttributeRegionalSmoke(h, {
            airSmoky,
            nwsSmoke: /smoke/i.test(hay),
            aqi: log.aqi,
            pm25: log.snapshot?.v === 2 ? (log.snapshot.free.pm25 ?? log.snapshot.ambee.pm25) : null,
          }),
      );
    })();

  if (!log.hasWildfireNearby && !hasCredibleLocalWf && !hasRegional) return null;

  if (hasCredibleLocalWf) {
    const local = credibleWf.find((h) => h.km == null || h.km <= 80);
    return local ? formatWildfireLabel(local.name, local.place) : "Wildfire reported";
  }
  if (hasRegional) {
    const distant = credibleWf
      .filter((h) => h.km != null && h.km > 80)
      .sort((a, b) => (a.km ?? 1e9) - (b.km ?? 1e9))[0];
    if (distant) {
      const label = formatWildfireLabel(distant.name, distant.place);
      return label.length <= 42 ? label : "Regional smoke";
    }
    return "Regional smoke";
  }
  // Stale Ambee WF that was a prescribed burn (… RX) — ignore.
  if (/Ambee WF/i.test(hay) && !hasCredibleLocalWf) {
    // fall through
  }
  if (/red flag|fire weather watch|fire weather warning/i.test(hay)) {
    const named = hay.match(/(Red Flag Warning|Fire Weather Watch|Fire Weather Warning)/i)?.[1];
    return named ?? "Fire weather";
  }
  if (/smoke/i.test(hay) && !/\bRX\b|prescribed|regional smoke/i.test(hay)) return "Smoke advisory";
  const nws = summary.split(/[|;]/)[0]?.trim();
  if (nws && !/FIRMS|Ambee|satellite heat|\bRX\b|Regional smoke/i.test(nws) && nws.length <= 42) {
    return nws;
  }
  if (/Ambee reported/i.test(hay) && hasCredibleLocalWf) return "Wildfire reported";
  if (log.hasWildfireNearby && hasCredibleLocalWf) return "Fire signal nearby";
  return null;
}

function collapsedEnvLine(log: AttackLogDTO | undefined): string {
  if (!log) return "Outdoor air not saved yet";
  if (log.envStatus !== "ready") return envStatusCopy(log.envStatus) ?? "Outdoor air pending";
  const parts: string[] = [];
  if (log.temperatureF != null) parts.push(`${Math.round(log.temperatureF)}°F`);
  if (log.aqi != null) parts.push(`AQI ${log.aqi}${log.aqiCategory ? ` ${log.aqiCategory}` : ""}`);
  if (log.hasStormAlert && log.stormSummary) {
    const first = log.stormSummary.split(";")[0]?.trim();
    if (first && !/heat|cold|freeze|frost|wind chill/i.test(first)) parts.push(first);
  }
  const fire = collapsedFireHint(log);
  if (fire) parts.push(fire);
  return parts.join(" · ") || "Outdoor context saved";
}

function EnvBadges({ log }: { log: AttackLogDTO | undefined }) {
  if (!log) {
    return <p className="env-status env-status--info">Outdoor air will appear after this log syncs.</p>;
  }

  const { status, rows, compare } = buildEnvSignals(log);
  const statusCopy = envStatusCopy(log.envStatus);

  return (
    <div>
      {statusCopy ? (
        <div className={`env-status env-status--${status.severity}`}>{statusCopy}</div>
      ) : null}
      {rows.length > 0 && (
        <table className="env-signal-table">
          <thead>
            <tr>
              <th></th>
              <th>{compare ? "Free" : "Outdoor"}</th>
              {compare ? <th>Ambee</th> : null}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.key}>
                <td className="env-signal-q">
                  {row.emoji} {row.question}
                </td>
                <td className="env-signal-v">
                  <SignalValue value={row.free} id={`${log.id}-${row.key}-free`} />
                </td>
                {compare ? (
                  <td className="env-signal-v">
                    <SignalValue value={row.ambee} id={`${log.id}-${row.key}-ambee`} />
                  </td>
                ) : null}
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {log.envStatus === "ready" &&
      log.aqi == null &&
      (log.snapshot?.v !== 2 || (!log.snapshot.free.aqi && !log.snapshot.ambee.pm25)) &&
      log.temperatureF != null ? (
        <p className="env-hint">No air reading yet — add an OpenAQ or AirNow key on Vercel.</p>
      ) : null}
    </div>
  );
}

const MATURITY_LABEL: Record<PatternReport["maturity"], string | null> = {
  locked: null,
  early: "Early",
  emerging: "Emerging",
  solid: "Solid",
};

function PatternsPanel({ report, loading }: { report: PatternReport | null; loading: boolean }) {
  if (!report && !loading) return null;

  const tag = report ? MATURITY_LABEL[report.maturity] : null;

  return (
    <section>
      <div className="logs-head">
        <h2>What we’re noticing</h2>
        {tag ? <span className={`pattern-tag pattern-tag--${report?.maturity}`}>{tag}</span> : null}
      </div>
      {!report ? (
        <p className="empty-card">Looking for patterns…</p>
      ) : report.maturity === "locked" || report.statements.length === 0 ? (
        <p className="empty-card">{report.note}</p>
      ) : (
        <div className="pattern-card">
          <ul className="pattern-list">
            {report.statements.map((s) => (
              <li key={s.key} className={`pattern-item pattern-item--${s.kind}`}>
                <span className="pattern-mark" aria-hidden />
                <span className="pattern-text">
                  <EnvText>{s.text}</EnvText>
                </span>
              </li>
            ))}
          </ul>
          <p className="pattern-note">{report.note}</p>
        </div>
      )}
    </section>
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
    <div className="feeling">
      <p className={`feeling-label${highlight ? " feeling-label--ask" : ""}`}>
        {highlight ? "How do you feel?" : "Feeling"}
        <span className="feeling-optional"> · optional</span>
      </p>
      <div className="feeling-row">
        {FEELING_OPTIONS.map((f) => {
          const selected = current === f.value;
          return (
            <button
              key={f.value}
              type="button"
              className={`feeling-btn${selected ? " feeling-btn--on" : ""}`}
              onClick={() => onSelect(logId, selected ? null : f.value)}
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
  const [openLogIds, setOpenLogIds] = useState<Record<string, boolean>>({});
  const [patterns, setPatterns] = useState<PatternReport | null>(null);
  const [patternsLoading, setPatternsLoading] = useState(false);

  const refreshPatterns = useCallback(async () => {
    setPatternsLoading(true);
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone ?? "UTC";
      const res = await fetch(`/api/patterns?tz=${encodeURIComponent(tz)}`, { cache: "no-store" });
      if (res.ok) {
        const data = (await res.json()) as { report: PatternReport };
        setPatterns(data.report);
      }
    } catch {
      // patterns are optional; the log list still works
    } finally {
      setPatternsLoading(false);
    }
  }, []);

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
    void refreshPatterns();
  }, [refreshPatterns]);

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
      setStatus("Finding your location…");
      try {
        const id = crypto.randomUUID();
        let placeName: string | null = null;
        try {
          const placeRes = await fetch(`/api/place?lat=${latitude}&lon=${longitude}`, { cache: "no-store" });
          if (placeRes.ok) {
            const data = (await placeRes.json()) as { placeName?: string | null };
            placeName = data.placeName ?? null;
          }
        } catch {
          // coords still work if the name lookup fails
        }

        const entry: LocalLog = {
          id,
          loggedAt: new Date().toISOString(),
          latitude,
          longitude,
          feeling: null,
          syncStatus: "pending",
          placeName,
        };
        await putLocalLog(entry);
        setLogs((prev) => [entry, ...prev.filter((l) => l.id !== id)]);
        setStatus(placeName ? `Logging in ${placeName}…` : "Saved — syncing env…");
        await syncPending();
        await refresh();
        setHighlightLogId(id);
        setOpenLogIds((prev) => ({ ...prev, [id]: true }));
        setStatus(
          placeName
            ? `Logged in ${placeName}. Add how you feel below (optional).`
            : "Logged. Add how you feel below (optional).",
        );
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

  const bannerKind = /error|fail|denied|not available/i.test(status)
    ? "err"
    : busy
      ? "busy"
      : status
        ? "ok"
        : null;

  return (
    <main className="app">
      <header className="app-header">
        <h1>Asthma trigger log</h1>
        <p className="app-lede">
          Tap when you use your inhaler. Open a log for outdoor air; tap a number to see where it came from.
        </p>
      </header>

      <section>
        <button type="button" className="log-cta" onClick={handleGeoLog} disabled={busy}>
          {busy ? "Logging…" : "Log inhaler use"}
        </button>
        {demoMode && (
          <div className="demo-stack">
            <span className="demo-label">Demo locations</span>
            {(Object.entries(DEMO_LOCATIONS) as [keyof typeof DEMO_LOCATIONS, (typeof DEMO_LOCATIONS)[keyof typeof DEMO_LOCATIONS]][]).map(
              ([key, demo]) => (
                <button
                  key={key}
                  type="button"
                  className={`demo-btn${key === "wildfire" ? " demo-btn--alert" : ""}`}
                  onClick={() => handleDemoLog(key)}
                  disabled={busy}
                >
                  {demo.label} — {demo.hint}
                </button>
              ),
            )}
          </div>
        )}
        {status && bannerKind ? <p className={`banner banner--${bannerKind}`}>{status}</p> : null}
      </section>

      <PatternsPanel report={patterns} loading={patternsLoading} />

      <section>
        <div className="logs-head">
          <h2>Recent</h2>
          {logs.length > 0 ? <span className="logs-count">{Math.min(logs.length, 20)}</span> : null}
        </div>
        {logs.length === 0 ? (
          <p className="empty-card">No logs yet. The first tap is enough — you can add how you felt afterward.</p>
        ) : (
          <ul className="log-list">
            {logs.slice(0, 20).map((log) => {
              const server = enriched[log.id] ?? log.serverLog;
              const feeling =
                (server?.feeling as Feeling | null | undefined) ?? log.feeling;
              const feelingLabel = feelingDisplay(feeling);
              const open = openLogIds[log.id] === true;
              const detailsId = `log-details-${log.id}`;
              const when = formatWhen(log.loggedAt);
              const sync = syncLabel(log.syncStatus);
              const place =
                server?.placeName ?? log.placeName ?? `${log.latitude.toFixed(4)}, ${log.longitude.toFixed(4)}`;
              return (
                <li key={log.id} className={`log-card${highlightLogId === log.id ? " log-card--fresh" : ""}`}>
                  <button
                    type="button"
                    className="log-row-toggle"
                    aria-expanded={open}
                    aria-controls={detailsId}
                    onClick={() => setOpenLogIds((prev) => ({ ...prev, [log.id]: !prev[log.id] }))}
                  >
                    <svg
                      className={`log-row-chevron${open ? " log-row-chevron--open" : ""}`}
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      aria-hidden
                    >
                      <path d="M7.3 4.7a1 1 0 0 1 1.4 0l5 5a1 1 0 0 1 0 1.4l-5 5a1 1 0 1 1-1.4-1.4L11.58 10 7.3 5.7a1 1 0 0 1 0-1z" />
                    </svg>
                    <span className="log-row-main">
                      <span className="log-row-top">
                        <span className="log-when">
                          <span className="log-when-date">{when.date}</span>
                          {when.time ? <span className="log-when-time">{when.time}</span> : null}
                        </span>
                        {feelingLabel ? <span className="log-feeling-chip">{feelingLabel}</span> : null}
                      </span>
                      <span className="log-place">{place}</span>
                      {!open ? <span className="log-row-summary">{collapsedEnvLine(server)}</span> : null}
                      {sync ? <span className="log-meta"><span className={`pill pill--${sync.kind}`}>{sync.text}</span></span> : null}
                    </span>
                  </button>
                  {open ? (
                    <div id={detailsId} className="log-row-details">
                      {(server?.placeName || log.placeName) ? (
                        <p className="log-coords">
                          {log.latitude.toFixed(4)}, {log.longitude.toFixed(4)}
                        </p>
                      ) : null}
                      <EnvBadges log={server} />
                      <FeelingTags
                        logId={log.id}
                        current={feeling ?? null}
                        onSelect={setFeeling}
                        highlight={highlightLogId === log.id}
                      />
                      {log.lastError ? <p className="log-error">{log.lastError}</p> : null}
                    </div>
                  ) : log.lastError ? (
                    <p className="log-error log-error--collapsed">{log.lastError}</p>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </main>
  );
}
