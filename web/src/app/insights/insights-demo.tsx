"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { buildDemoFrames } from "@/lib/insights/demo-frames";
import { buildFramesFromLogs, type FramesBuildMeta } from "@/lib/insights/frames-from-logs";
import { DEFAULT_GATE, DEMO_GATE, computeLift, formatLift } from "@/lib/insights/lift";
import { loadDiaryLogs } from "@/lib/insights/load-logs";
import { summarizeWithTemplate, toNarratorInput } from "@/lib/insights/summarize";
import { clampStyle, styleBand, styleLabel } from "@/lib/insights/style";
import type { FeatureFrame, LiftReport, NarratorOutput } from "@/lib/insights/types";
import { summarizeWithWebLLM, WEBLLM_GEMMA_MODEL } from "@/lib/insights/webllm-narrator";

type NarratorMode = "template" | "webllm";
type DataMode = "diary" | "synthetic";

export default function InsightsDemo() {
  const searchParams = useSearchParams();
  const strict = searchParams.get("strict") === "1";

  const [dataMode, setDataMode] = useState<DataMode>("diary");
  const [frames, setFrames] = useState<FeatureFrame[]>([]);
  const [meta, setMeta] = useState<FramesBuildMeta | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [loadingLogs, setLoadingLogs] = useState(true);

  const [mode, setMode] = useState<NarratorMode>("template");
  const [styleScore, setStyleScore] = useState(35);
  const [webllmOut, setWebllmOut] = useState<NarratorOutput | null>(null);
  const [webllmBusy, setWebllmBusy] = useState(false);
  const [webllmProgress, setWebllmProgress] = useState<string | null>(null);
  const [webllmError, setWebllmError] = useState<string | null>(null);

  const band = styleBand(styleScore);

  const refreshLogs = useCallback(async () => {
    setLoadingLogs(true);
    setLoadError(null);
    try {
      const logs = await loadDiaryLogs();
      const built = buildFramesFromLogs(logs, {
        strict,
        supplementDemoBaselines: !strict,
      });

      if (built.frames.filter((f) => f.kind === "attack").length === 0) {
        setDataMode("synthetic");
        const demo = buildDemoFrames();
        setFrames(demo);
        setMeta({
          nLogs: logs.length,
          nSkippedNoEnv: logs.length,
          nAttacks: demo.filter((f) => f.kind === "attack").length,
          nBaselines: demo.filter((f) => f.kind === "baseline").length,
          supplementedDemoBaselines: 0,
          baselineNote:
            logs.length === 0
              ? "No enriched diary logs yet — showing synthetic demo data. Log attacks on the home screen, then refresh."
              : "Logs found but none have outdoor air stamped yet — showing synthetic demo until enrichment completes.",
        });
      } else {
        setDataMode("diary");
        setFrames(built.frames);
        setMeta(built.meta);
      }
    } catch (e) {
      setLoadError(e instanceof Error ? e.message : "Could not load logs");
      setDataMode("synthetic");
      setFrames(buildDemoFrames());
      setMeta(null);
    } finally {
      setLoadingLogs(false);
    }
  }, [strict]);

  useEffect(() => {
    void refreshLogs();
  }, [refreshLogs]);

  const gate = meta?.supplementedDemoBaselines ? DEMO_GATE : DEFAULT_GATE;
  const report: LiftReport = useMemo(() => computeLift(frames, gate), [frames, gate]);
  /** Template is fixed factual copy — style slider does not touch it. */
  const template = useMemo(() => summarizeWithTemplate(toNarratorInput(report)), [report]);

  const runWebLLM = useCallback(
    async (score = styleScore) => {
      setWebllmBusy(true);
      setWebllmError(null);
      setWebllmProgress("Checking WebGPU…");
      try {
        if (typeof navigator !== "undefined" && !("gpu" in navigator)) {
          setWebllmError(
            "WebGPU not available in this browser. Use Chrome/Edge on desktop for the Gemma demo.",
          );
        }
        const input = toNarratorInput(report, score);
        const out = await summarizeWithWebLLM(input, (t) => setWebllmProgress(t));
        setWebllmOut(out);
        setMode("webllm");
        if (out.model?.startsWith("WebLLM error")) {
          setWebllmError(out.model);
        }
      } catch (e) {
        setWebllmError(e instanceof Error ? e.message : "WebLLM failed");
      } finally {
        setWebllmBusy(false);
        setWebllmProgress(null);
      }
    },
    [report, styleScore],
  );

  // When style band changes under WebLLM mode, regenerate (debounced via band, not every tick).
  useEffect(() => {
    if (mode !== "webllm") return;
    if (webllmBusy) return;
    if (webllmOut?.styleBand === band) return;
    const t = window.setTimeout(() => {
      void runWebLLM(styleScore);
    }, 450);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- regenerate only when band flips
  }, [band, mode]);

  const narrative = mode === "webllm" && webllmOut ? webllmOut : template;
  const styleActive = mode === "webllm";
  const evidenceUnchanged = styleActive
    ? "Evidence unchanged — lift table is fixed; Gemma only rewrites the voice."
    : "Style slider applies to Gemma only. Switch to Gemma (WebLLM) to hear clinical → poetic.";

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-col gap-8 px-4 py-10">
      <header className="flex flex-col gap-2">
        <p className="text-sm text-neutral-500">
          <Link href="/" className="underline-offset-2 hover:underline">
            ← Diary
          </Link>
        </p>
        <h1 className="text-2xl font-semibold tracking-tight">Insights demo</h1>
        <p className="text-sm leading-relaxed text-neutral-600">
          Correlations come from your logs in TypeScript. The template stays factual; Gemma narrates
          the same table in a voice you dial from clinical to poetic.
        </p>
      </header>

      <section className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          className="rounded-lg border border-neutral-300 px-3 py-1.5 text-sm hover:bg-neutral-50"
          onClick={() => void refreshLogs()}
          disabled={loadingLogs}
        >
          {loadingLogs ? "Loading…" : "Refresh from diary"}
        </button>
        <span className="text-xs text-neutral-500">
          Data: {dataMode === "diary" ? "your logs" : "synthetic fallback"}
          {strict ? " · strict (no demo baselines)" : ""}
        </span>
      </section>

      {loadError ? <p className="text-sm text-amber-700">{loadError}</p> : null}

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium uppercase tracking-wide text-neutral-500">Samples</h2>
        <p className="text-sm text-neutral-700">
          {report.nAttacks} attack logs · {report.nBaselines} usual-day rows
          {report.seasonHint ? ` · ${report.seasonHint}` : ""}
        </p>
        {meta ? (
          <p className="text-xs leading-relaxed text-neutral-500">
            {meta.baselineNote}
            {meta.nSkippedNoEnv > 0
              ? ` Skipped ${meta.nSkippedNoEnv} log(s) without outdoor air data.`
              : ""}
          </p>
        ) : null}
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium uppercase tracking-wide text-neutral-500">
          Lift table (computed locally)
        </h2>
        <div className="overflow-x-auto rounded-lg border border-neutral-200">
          <table className="w-full min-w-[28rem] text-left text-sm">
            <thead className="border-b border-neutral-200 bg-neutral-50 text-xs uppercase text-neutral-500">
              <tr>
                <th className="px-3 py-2 font-medium">Weather / air bin</th>
                <th className="px-3 py-2 font-medium">Attacks</th>
                <th className="px-3 py-2 font-medium">Usual</th>
                <th className="px-3 py-2 font-medium">Lift</th>
                <th className="px-3 py-2 font-medium">Gate</th>
              </tr>
            </thead>
            <tbody>
              {report.rows.slice(0, 14).map((r) => (
                <tr
                  key={`${r.bin}:${r.level}`}
                  className={r.gated ? "bg-amber-50/80" : "text-neutral-500"}
                >
                  <td className="px-3 py-2 font-mono text-xs">
                    {r.bin}:{r.level}
                  </td>
                  <td className="px-3 py-2">
                    {r.attacksWith}/{r.nAttacks}
                  </td>
                  <td className="px-3 py-2">
                    {r.baselinesWith}/{r.nBaselines}
                  </td>
                  <td className="px-3 py-2">{formatLift(r.lift)}×</td>
                  <td className="px-3 py-2">{r.gated ? "yes" : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="text-xs text-neutral-500">
          Lift = how often this bin appears on attack logs vs usual-day rows. Highlighted rows pass
          the sample gate.
        </p>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="text-sm font-medium uppercase tracking-wide text-neutral-500">
            Narrator
          </h2>
          <button
            type="button"
            className={`rounded-full px-3 py-1 text-xs ${
              mode === "template" ? "bg-neutral-900 text-white" : "bg-neutral-100 text-neutral-700"
            }`}
            onClick={() => setMode("template")}
          >
            Template
          </button>
          <button
            type="button"
            className={`rounded-full px-3 py-1 text-xs ${
              mode === "webllm" ? "bg-neutral-900 text-white" : "bg-neutral-100 text-neutral-700"
            }`}
            onClick={() => {
              if (webllmOut && !webllmBusy && webllmOut.styleBand === band) setMode("webllm");
              else void runWebLLM();
            }}
            disabled={webllmBusy}
          >
            {webllmBusy ? "Loading Gemma…" : "Gemma (WebLLM)"}
          </button>
        </div>

        <div
          className={`rounded-lg border border-neutral-200 bg-neutral-50/80 px-4 py-3 ${
            styleActive ? "" : "opacity-55"
          }`}
        >
          <div className="mb-2 flex items-center justify-between gap-3 text-xs text-neutral-600">
            <span>Clinical</span>
            <span className="font-medium text-neutral-900">
              {styleActive ? `${styleLabel(band)} · ${clampStyle(styleScore)}` : "Gemma only"}
            </span>
            <span>Poetic</span>
          </div>
          <input
            type="range"
            min={0}
            max={100}
            step={1}
            value={styleScore}
            disabled={!styleActive || webllmBusy}
            aria-label="Gemma narration style from clinical to poetic"
            className="w-full accent-neutral-900 disabled:cursor-not-allowed"
            onChange={(e) => setStyleScore(Number(e.target.value))}
          />
          <div className="mt-2 flex flex-wrap gap-2">
            {(
              [
                ["clinical", 0],
                ["plain", 50],
                ["poetic", 100],
              ] as const
            ).map(([key, value]) => (
              <button
                key={key}
                type="button"
                disabled={!styleActive || webllmBusy}
                className={`rounded-full px-2.5 py-1 text-[11px] disabled:cursor-not-allowed ${
                  styleActive && band === key
                    ? "bg-neutral-900 text-white"
                    : "bg-white text-neutral-700 ring-1 ring-neutral-200"
                }`}
                onClick={() => setStyleScore(value)}
              >
                {styleLabel(key)}
              </button>
            ))}
          </div>
          <p className="mt-2 text-[11px] leading-relaxed text-neutral-500">{evidenceUnchanged}</p>
        </div>

        {webllmProgress ? (
          <p className="font-mono text-[11px] text-neutral-500">{webllmProgress}</p>
        ) : null}

        <article className="rounded-lg border border-neutral-200 bg-white p-4 shadow-sm">
          <p className="text-base leading-relaxed text-neutral-900">{narrative.headline}</p>
          <p className="mt-2 text-xs text-neutral-500">{narrative.caveat}</p>
          <p className="mt-3 font-mono text-[11px] text-neutral-400">
            source={narrative.source}
            {narrative.styleBand ? ` · ${narrative.styleBand}` : ""}
            {narrative.model ? ` · ${narrative.model}` : ""}
            {narrative.latencyMs != null ? ` · ${narrative.latencyMs}ms` : ""}
            {narrative.drivers.length > 0 ? ` · ${narrative.drivers.join(", ")}` : ""}
          </p>
        </article>

        {webllmError ? <p className="text-sm text-red-600">{webllmError}</p> : null}
        <p className="text-xs leading-relaxed text-neutral-500">
          Template is a fixed count sentence. After Gemma loads, move the slider — it re-runs when
          the band flips (clinical / plain / poetic). First load downloads {WEBLLM_GEMMA_MODEL} into
          browser cache (WebGPU).
        </p>
      </section>
    </main>
  );
}
