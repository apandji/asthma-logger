"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { buildDemoFrames } from "@/lib/insights/demo-frames";
import { buildFramesFromLogs, type FramesBuildMeta } from "@/lib/insights/frames-from-logs";
import { summarizeWithGemmaWebGpu } from "@/lib/insights/gemma-webgpu-narrator";
import { DEFAULT_GATE, DEMO_GATE, computeLift, formatLift } from "@/lib/insights/lift";
import { loadDiaryLogs } from "@/lib/insights/load-logs";
import { summarizeWithTemplate, toNarratorInput } from "@/lib/insights/summarize";
import type { FeatureFrame, LiftReport, NarratorOutput } from "@/lib/insights/types";
import { summarizeWithWebLLM } from "@/lib/insights/webllm-narrator";
import {
  checkOnDeviceGemmaSupport,
  type OnDeviceGemmaSupport,
} from "@/lib/insights/webllm-support";

type NarratorMode = "template" | "gemma";
type DataMode = "diary" | "synthetic";

export default function InsightsDemo() {
  const searchParams = useSearchParams();
  const strict = searchParams.get("strict") === "1";
  const forceIos = searchParams.get("device") === "ios";
  /** Demo/test override: `?device=ios&webgpu=1` pretends capable iPhone WebGPU. */
  const forceWebgpuParam = searchParams.get("webgpu");
  const forceWebgpu =
    forceWebgpuParam === "1" ? true : forceWebgpuParam === "0" ? false : undefined;

  const [dataMode, setDataMode] = useState<DataMode>("diary");
  const [frames, setFrames] = useState<FeatureFrame[]>([]);
  const [meta, setMeta] = useState<FramesBuildMeta | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [loadingLogs, setLoadingLogs] = useState(true);

  const [mode, setMode] = useState<NarratorMode>("template");
  const [gemmaOut, setGemmaOut] = useState<NarratorOutput | null>(null);
  const [gemmaBusy, setGemmaBusy] = useState(false);
  const [gemmaProgress, setGemmaProgress] = useState<string | null>(null);
  const [gemmaError, setGemmaError] = useState<string | null>(null);
  const [gemmaSupport, setGemmaSupport] = useState<OnDeviceGemmaSupport | null>(null);

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

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const support = await checkOnDeviceGemmaSupport({
        forceIos: forceIos || undefined,
        forceWebgpu,
      });
      if (!cancelled) setGemmaSupport(support);
    })();
    return () => {
      cancelled = true;
    };
  }, [forceIos, forceWebgpu]);

  const baselineCount = frames.filter((f) => f.kind === "baseline").length;
  const gate =
    meta?.supplementedDemoBaselines || baselineCount < DEFAULT_GATE.minBaselines
      ? DEMO_GATE
      : DEFAULT_GATE;
  const report: LiftReport = useMemo(() => computeLift(frames, gate), [frames, gate]);
  const template = useMemo(() => summarizeWithTemplate(toNarratorInput(report)), [report]);

  const gemmaBlocked = gemmaSupport && !gemmaSupport.ok ? gemmaSupport.reason : null;
  const gemmaButtonLabel = gemmaSupport?.buttonLabel ?? "Gemma (on-device)";

  async function runGemma() {
    setGemmaBusy(true);
    setGemmaError(null);
    setGemmaProgress("Checking WebGPU…");
    try {
      const support = await checkOnDeviceGemmaSupport({
        forceIos: forceIos || undefined,
        forceWebgpu,
      });
      setGemmaSupport(support);
      if (!support.ok || support.path === "none") {
        setGemmaError(support.reason);
        setMode("template");
        return;
      }

      const hints = { forceIos: forceIos || undefined, forceWebgpu };
      const input = toNarratorInput(report);
      const out =
        support.path === "gemma-webgpu"
          ? await summarizeWithGemmaWebGpu(input, (t) => setGemmaProgress(t), hints)
          : await summarizeWithWebLLM(input, (t) => setGemmaProgress(t));

      setGemmaOut(out);
      setMode("gemma");
      if (out.model?.includes("error")) {
        setGemmaError(out.model);
        setMode("template");
      }
    } catch (e) {
      setGemmaError(e instanceof Error ? e.message : "Gemma failed");
      setMode("template");
    } finally {
      setGemmaBusy(false);
      setGemmaProgress(null);
    }
  }

  const narrative = mode === "gemma" && gemmaOut ? gemmaOut : template;

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
          Correlations come from your logs in TypeScript. Gemma only narrates the lift table —
          desktop uses WebLLM (2B); capable iPhones use Gemma 3 270M over WebGPU.
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
              mode === "gemma" ? "bg-neutral-900 text-white" : "bg-neutral-100 text-neutral-700"
            } disabled:cursor-not-allowed disabled:opacity-50`}
            onClick={() => {
              if (gemmaBlocked) return;
              if (gemmaOut && !gemmaBusy) setMode("gemma");
              else void runGemma();
            }}
            disabled={gemmaBusy || Boolean(gemmaBlocked) || !gemmaSupport}
            title={gemmaBlocked ?? undefined}
          >
            {gemmaBusy ? "Loading Gemma…" : gemmaButtonLabel}
          </button>
        </div>

        {gemmaProgress ? (
          <p className="font-mono text-[11px] text-neutral-500">{gemmaProgress}</p>
        ) : null}

        {gemmaBlocked ? (
          <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm leading-relaxed text-amber-950">
            {gemmaBlocked}
          </p>
        ) : null}

        {gemmaSupport?.path === "gemma-webgpu" && !gemmaBusy && !gemmaOut ? (
          <p className="rounded-lg border border-sky-200 bg-sky-50 px-3 py-2 text-sm leading-relaxed text-sky-950">
            Capable iPhone/iPad detected. Gemma 3 270M (~300MB) will stream into WebGPU — first load
            downloads weights; later visits reuse cache when the browser allows.
          </p>
        ) : null}

        <article className="rounded-lg border border-neutral-200 bg-white p-4 shadow-sm">
          <p className="text-base leading-relaxed text-neutral-900">{narrative.headline}</p>
          <p className="mt-2 text-xs text-neutral-500">{narrative.caveat}</p>
          <p className="mt-3 font-mono text-[11px] text-neutral-400">
            source={narrative.source}
            {narrative.model ? ` · ${narrative.model}` : ""}
            {narrative.latencyMs != null ? ` · ${narrative.latencyMs}ms` : ""}
            {narrative.drivers.length > 0 ? ` · ${narrative.drivers.join(", ")}` : ""}
          </p>
        </article>

        {gemmaError && !gemmaBlocked ? <p className="text-sm text-red-600">{gemmaError}</p> : null}
        <p className="text-xs leading-relaxed text-neutral-500">
          On-device paths: desktop Chrome/Edge → WebLLM Gemma 2 2B (~1.5GB); iPhone/iPad with WebGPU
          → Gemma 3 270M (~300MB via <code className="rounded bg-neutral-100 px-1">gemma-webgpu</code>
          ). Without WebGPU, template narrator still works. Demo routing:{" "}
          <code className="rounded bg-neutral-100 px-1">?device=ios&amp;webgpu=1</code>. Mark feeling{" "}
          <strong>ok</strong> on quiet days for real usual-day rows; add{" "}
          <code className="rounded bg-neutral-100 px-1">?strict=1</code> to disable demo baselines.
        </p>
      </section>
    </main>
  );
}
