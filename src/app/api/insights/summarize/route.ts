import { NextResponse } from "next/server";
import {
  buildOllamaPrompt,
  parseNarratorJson,
  summarizeWithTemplate,
  toNarratorInput,
} from "@/lib/insights/summarize";
import type { LiftReport, NarratorOutput } from "@/lib/insights/types";

export const runtime = "nodejs";

type Body = {
  report?: LiftReport;
  /** Force template even if Ollama is up */
  narrator?: "template" | "ollama";
};

/**
 * Optional laptop proxy for Ollama. Health data never leaves the request body
 * except as the already-gated lift table in the prompt.
 *
 * Env: OLLAMA_HOST (default http://127.0.0.1:11434), OLLAMA_MODEL (e.g. gemma2:2b)
 */
export async function POST(req: Request) {
  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return NextResponse.json({ error: "invalid json" }, { status: 400 });
  }

  if (!body.report || typeof body.report.nAttacks !== "number") {
    return NextResponse.json({ error: "report required" }, { status: 400 });
  }

  const input = toNarratorInput(body.report);
  const want = body.narrator ?? "ollama";

  if (want === "template") {
    const out: NarratorOutput = summarizeWithTemplate(input);
    return NextResponse.json(out);
  }

  const host = (process.env.OLLAMA_HOST ?? "http://127.0.0.1:11434").replace(/\/$/, "");
  const model = process.env.OLLAMA_MODEL ?? "gemma2:2b";
  const prompt = buildOllamaPrompt(input);
  const started = Date.now();

  try {
    const res = await fetch(`${host}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model,
        prompt,
        stream: false,
        format: "json",
        options: { temperature: 0.2, num_predict: 180 },
      }),
      signal: AbortSignal.timeout(60_000),
    });

    if (!res.ok) {
      const text = await res.text().catch(() => "");
      return NextResponse.json(
        {
          error: "ollama_failed",
          detail: text.slice(0, 400),
          fallback: summarizeWithTemplate(input),
        },
        { status: 502 },
      );
    }

    const data = (await res.json()) as { response?: string };
    const latencyMs = Date.now() - started;
    const parsed = parseNarratorJson(data.response ?? "", model, latencyMs);
    if (!parsed) {
      return NextResponse.json({
        ...summarizeWithTemplate(input),
        source: "template" as const,
        model: `${model} (parse fallback)`,
        latencyMs,
      });
    }
    return NextResponse.json(parsed);
  } catch (err) {
    const message = err instanceof Error ? err.message : "ollama unreachable";
    return NextResponse.json(
      {
        error: "ollama_unreachable",
        detail: message,
        fallback: summarizeWithTemplate(input),
      },
      { status: 503 },
    );
  }
}
