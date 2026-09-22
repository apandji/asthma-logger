"use client";

import { buildOllamaPrompt, parseNarratorJson, summarizeWithTemplate } from "./summarize";
import type { NarratorInput, NarratorOutput } from "./types";

/** Prebuilt WebLLM model — Gemma 2 2B instruct, ~1.5GB first download. */
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

export async function getWebLLMEngine(onProgress?: (text: string) => void): Promise<WebLLMEngine> {
  if (!enginePromise) {
    enginePromise = (async () => {
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
    })();
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
