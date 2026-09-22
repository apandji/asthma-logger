"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { buildDemoFrames } from "@/lib/insights/demo-frames";
import { DEMO_GATE, computeLift, formatLift } from "@/lib/insights/lift";
import { summarizeWithTemplate, toNarratorInput } from "@/lib/insights/summarize";
import type { NarratorOutput } from "@/lib/insights/types";

type NarratorMode = "template" | "ollama";

export default function InsightsPrototypePage() {
  const frames = useMemo(() => buildDemoFrames(), []);
  const report = useMemo(() => computeLift(frames, DEMO_GATE), [frames]);
  const template = useMemo(() => summarizeWithTemplate(toNarratorInput(report)), [report]);

  const [mode, setMode] = useState<NarratorMode>("template");
  const [ollamaOut, setOllamaOut] = useState<NarratorOutput | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function runOllama() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/insights/summarize", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ report, narrator: "ollama" }),
      });
      const data = (await res.json()) as NarratorOutput & {
        error?: string;
        detail?: string;
        fallback?: NarratorOutput;
      };
      if (!res.ok) {
        setError(data.detail ?? data.error ?? "Ollama failed");
        if (data.fallback) setOllamaOut(data.fallback);
        return;
      }
      setOllamaOut(data);
      setMode("ollama");
    } catch (e) {
      setError(e instanceof Error ? e.message : "request failed");
    } finally {
      setBusy(false);
    }
  }

  const narrative = mode === "ollama" && ollamaOut ? ollamaOut : template;

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-col gap-8 px-4 py-10">
      <header className="flex flex-col gap-2">
        <p className="text-sm text-neutral-500">
          <Link href="/" className="underline-offset-2 hover:underline">
            ← Diary
          </Link>
        </p>
        <h1 className="text-2xl font-semibold tracking-tight">Insights prototype</h1>
        <p className="text-sm leading-relaxed text-neutral-600">
          Lift is computed in TypeScript. The narrator only sees the table. Template works offline;
          Gemma via Ollama is optional for the talk.
        </p>
      </header>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium uppercase tracking-wide text-neutral-500">Samples</h2>
        <p className="text-sm text-neutral-700">
          {report.nAttacks} attacks · {report.nBaselines} usual days
          {report.seasonHint ? ` · ${report.seasonHint}` : ""} (synthetic demo frames)
        </p>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium uppercase tracking-wide text-neutral-500">
          Lift table (code)
        </h2>
        <div className="overflow-x-auto rounded-lg border border-neutral-200">
          <table className="w-full min-w-[28rem] text-left text-sm">
            <thead className="border-b border-neutral-200 bg-neutral-50 text-xs uppercase text-neutral-500">
              <tr>
                <th className="px-3 py-2 font-medium">Bin</th>
                <th className="px-3 py-2 font-medium">Attacks</th>
                <th className="px-3 py-2 font-medium">Usual</th>
                <th className="px-3 py-2 font-medium">Lift</th>
                <th className="px-3 py-2 font-medium">Gate</th>
              </tr>
            </thead>
            <tbody>
              {report.rows.slice(0, 12).map((r) => (
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
        <p className="text-xs text-neutral-500">Highlighted rows clear the demo count gate.</p>
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
              mode === "ollama" ? "bg-neutral-900 text-white" : "bg-neutral-100 text-neutral-700"
            }`}
            onClick={() => {
              if (ollamaOut) setMode("ollama");
              else void runOllama();
            }}
            disabled={busy}
          >
            {busy ? "Calling Ollama…" : "Gemma (Ollama)"}
          </button>
        </div>

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

        {error ? <p className="text-sm text-red-600">{error}</p> : null}
        <p className="text-xs leading-relaxed text-neutral-500">
          Ollama: install locally,{" "}
          <code className="rounded bg-neutral-100 px-1">ollama pull gemma2:2b</code>, optional{" "}
          <code className="rounded bg-neutral-100 px-1">OLLAMA_MODEL</code>. See{" "}
          <code className="rounded bg-neutral-100 px-1">docs/on-device-insights.md</code>.
        </p>
      </section>
    </main>
  );
}
