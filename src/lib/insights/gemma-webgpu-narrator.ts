"use client";

import { buildOllamaPrompt, parseNarratorJson, summarizeWithTemplate } from "./summarize";
import type { NarratorInput, NarratorOutput } from "./types";
import { checkOnDeviceGemmaSupport, type OnDeviceGemmaHints } from "./webllm-support";

/** Gemma 3 270M instruct Q8_0 via gemma-webgpu — sized for capable iPhones (~300MB). */
export const GEMMA_WEBGPU_MODEL = "270m";
export const GEMMA_WEBGPU_MODEL_ID = "gemma-3-270m-it-Q8_0";

type GemmaWebGpuEngine = {
  addUserMessage: (text: string) => void;
  generate: (opts?: {
    temperature?: number;
    topP?: number;
    maxTokens?: number;
  }) => AsyncGenerator<string, void, undefined>;
  resetConversation: () => void;
  dispose: () => void;
};

let enginePromise: Promise<GemmaWebGpuEngine> | null = null;
let loadProgress = "";

export function getGemmaWebGpuLoadProgress(): string {
  return loadProgress;
}

export function resetGemmaWebGpuEngine(): void {
  enginePromise = null;
  loadProgress = "";
}

export async function getGemmaWebGpuEngine(
  onProgress?: (text: string) => void,
  hints?: OnDeviceGemmaHints,
): Promise<GemmaWebGpuEngine> {
  if (!enginePromise) {
    enginePromise = (async () => {
      const support = await checkOnDeviceGemmaSupport(hints);
      if (support.path !== "gemma-webgpu") {
        throw new Error(
          support.reason ?? "Gemma 270M WebGPU path is not available in this browser",
        );
      }

      const { createGemmaEngine } = await import("gemma-webgpu");
      const engine = await createGemmaEngine({
        model: GEMMA_WEBGPU_MODEL,
        contextLength: 2048,
        onProgress: (p) => {
          const pct =
            p.total > 0 ? ` ${Math.min(100, Math.round((p.loaded / p.total) * 100))}%` : "";
          loadProgress = `${p.status}${pct}`.trim();
          onProgress?.(loadProgress);
        },
      });
      return engine as GemmaWebGpuEngine;
    })().catch((err) => {
      enginePromise = null;
      throw err;
    });
  } else if (onProgress && loadProgress) {
    onProgress(loadProgress);
  }
  return enginePromise;
}

export async function summarizeWithGemmaWebGpu(
  input: NarratorInput,
  onProgress?: (text: string) => void,
  hints?: OnDeviceGemmaHints,
): Promise<NarratorOutput> {
  const started = Date.now();
  try {
    const engine = await getGemmaWebGpuEngine(onProgress, hints);
    engine.resetConversation();
    const prompt = buildOllamaPrompt(input);
    engine.addUserMessage(prompt);

    onProgress?.("Generating…");
    let text = "";
    for await (const token of engine.generate({
      temperature: 0.15,
      topP: 0.9,
      maxTokens: 220,
    })) {
      text += token;
    }

    const parsed = parseNarratorJson(
      text,
      GEMMA_WEBGPU_MODEL_ID,
      Date.now() - started,
      "gemma-webgpu",
      input,
    );
    if (parsed) return parsed;
    return {
      ...summarizeWithTemplate(input),
      source: "gemma-webgpu",
      model: `${GEMMA_WEBGPU_MODEL_ID} (parse fallback)`,
      latencyMs: Date.now() - started,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Gemma WebGPU failed";
    return {
      ...summarizeWithTemplate(input),
      source: "template",
      model: `Gemma WebGPU error: ${message}`,
      latencyMs: Date.now() - started,
    };
  }
}
