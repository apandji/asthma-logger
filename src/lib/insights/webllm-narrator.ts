"use client";

import { buildOllamaPrompt, parseNarratorJson, summarizeWithTemplate } from "./summarize";
import type { NarratorInput, NarratorOutput } from "./types";
import { checkWebLLMSupport } from "./webllm-support";

/** Prebuilt WebLLM model — Gemma 2 2B instruct, ~1.5GB first download. Desktop WebGPU only. */
export const WEBLLM_GEMMA_MODEL = "gemma-2-2b-it-q4f16_1-MLC";

type WebLLMEngine = {
  chat: {
    completions: {
      create: (opts: {
        messages: { role: string; content: string }[];
        temperature?: number;
        max_tokens?: number;
      }) => Promise<{ choices: { message?: { content?: string } }[] }>;
    };
  };
};

let enginePromise: Promise<WebLLMEngine> | null = null;
let loadProgress = "";

export function getWebLLMLoadProgress(): string {
  return loadProgress;
}

/** Clear a failed init so the next attempt can retry after the user switches browsers. */
export function resetWebLLMEngine(): void {
  enginePromise = null;
  loadProgress = "";
}

export async function getWebLLMEngine(onProgress?: (text: string) => void): Promise<WebLLMEngine> {
  if (!enginePromise) {
    enginePromise = (async () => {
      const support = await checkWebLLMSupport();
      if (!support.ok) {
        throw new Error(support.reason ?? "WebLLM is not supported in this browser");
      }

      const { CreateMLCEngine } = await import("@mlc-ai/web-llm");
      return (await CreateMLCEngine(
        WEBLLM_GEMMA_MODEL,
        {
          initProgressCallback: (report) => {
            loadProgress = report.text;
            onProgress?.(report.text);
          },
        },
        { context_window_size: 4096 },
      )) as WebLLMEngine;
    })().catch((err) => {
      // Don't cache a rejected promise forever — allow a clean retry.
      enginePromise = null;
      throw err;
    });
  } else if (onProgress && loadProgress) {
    onProgress(loadProgress);
  }
  return enginePromise;
}

export async function summarizeWithWebLLM(
  input: NarratorInput,
  onProgress?: (text: string) => void,
): Promise<NarratorOutput> {
  const started = Date.now();
  try {
    const engine = await getWebLLMEngine(onProgress);
    const prompt = buildOllamaPrompt(input);
    const reply = await engine.chat.completions.create({
      messages: [{ role: "user", content: prompt }],
      temperature: 0.15,
      max_tokens: 220,
    });
    const text = reply.choices[0]?.message?.content ?? "";
    const parsed = parseNarratorJson(
      text,
      WEBLLM_GEMMA_MODEL,
      Date.now() - started,
      "webllm",
      input,
    );
    if (parsed) return parsed;
    return {
      ...summarizeWithTemplate(input),
      source: "webllm",
      model: `${WEBLLM_GEMMA_MODEL} (parse fallback)`,
      latencyMs: Date.now() - started,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "WebLLM failed";
    return {
      ...summarizeWithTemplate(input),
      source: "template",
      model: `WebLLM error: ${message}`,
      latencyMs: Date.now() - started,
    };
  }
}
