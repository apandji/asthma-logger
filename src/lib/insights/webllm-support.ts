/**
 * On-device Gemma capability routing.
 *
 * - Desktop + WebGPU → WebLLM Gemma 2 2B (~1.5GB)
 * - iPhone/iPad + WebGPU → gemma-webgpu Gemma 3 270M (~300MB, streamed weights)
 * - iPhone/iPad without WebGPU → blocked (needs iOS 26+ / Safari WebGPU)
 *
 * The 2B WebLLM path is never used on iOS — it OOMs the tab.
 */

export type OnDeviceGemmaPath = "webllm" | "gemma-webgpu" | "none";

export type OnDeviceGemmaSupport = {
  path: OnDeviceGemmaPath;
  ok: boolean;
  reason: string | null;
  iosLike: boolean;
  webgpu: boolean;
  /** Short button label */
  buttonLabel: string;
  /** Model id shown in UI / metadata */
  modelId: string;
};

export type OnDeviceGemmaHints = {
  /** Force iOS-like routing (e.g. Insights `?device=ios` for demos). */
  forceIos?: boolean;
  /** Force WebGPU yes/no when probing is unavailable in a test harness. */
  forceWebgpu?: boolean;
};

function isIOSLike(): boolean {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent;
  if (/iPad|iPhone|iPod/i.test(ua)) return true;
  // iPadOS 13+ reports as MacIntel but is a touch tablet
  if (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1) return true;
  return false;
}

async function hasUsableWebGPU(): Promise<boolean> {
  if (typeof navigator === "undefined") return false;
  const gpu = (
    navigator as Navigator & {
      gpu?: { requestAdapter: () => Promise<unknown | null> };
    }
  ).gpu;
  if (!gpu) return false;
  try {
    const adapter = await gpu.requestAdapter();
    return adapter != null;
  } catch {
    return false;
  }
}

export function isIOSLikeDevice(): boolean {
  return isIOSLike();
}

/** Pure routing used by the async probe and unit tests. */
export function resolveOnDeviceGemmaSupport(
  iosLike: boolean,
  webgpu: boolean,
): OnDeviceGemmaSupport {
  if (iosLike) {
    if (!webgpu) {
      return {
        path: "none",
        ok: false,
        reason:
          "This iPhone/iPad doesn’t expose WebGPU yet (needs a recent Safari, typically iOS 26+). Template narrator still works. Or open Insights on desktop Chrome/Edge for the larger Gemma demo.",
        iosLike: true,
        webgpu: false,
        buttonLabel: "Gemma (on-device)",
        modelId: "gemma-3-270m-it",
      };
    }
    return {
      path: "gemma-webgpu",
      ok: true,
      reason: null,
      iosLike: true,
      webgpu: true,
      buttonLabel: "Gemma 270M",
      modelId: "gemma-3-270m-it-Q8_0",
    };
  }

  if (!webgpu) {
    return {
      path: "none",
      ok: false,
      reason:
        "WebGPU is not available in this browser. Use Chrome or Edge on a desktop for the Gemma demo, or a recent iPhone Safari with WebGPU for Gemma 270M.",
      iosLike: false,
      webgpu: false,
      buttonLabel: "Gemma (WebLLM)",
      modelId: "gemma-2-2b-it-q4f16_1-MLC",
    };
  }

  return {
    path: "webllm",
    ok: true,
    reason: null,
    iosLike: false,
    webgpu: true,
    buttonLabel: "Gemma (WebLLM)",
    modelId: "gemma-2-2b-it-q4f16_1-MLC",
  };
}

/** @deprecated Prefer checkOnDeviceGemmaSupport — kept for call sites that only care about WebLLM 2B. */
export type WebLLMSupport = {
  ok: boolean;
  reason: string | null;
  iosLike: boolean;
  webgpu: boolean;
};

/** Desktop WebLLM Gemma 2B only — never ok on iOS. */
export async function checkWebLLMSupport(
  hints?: OnDeviceGemmaHints,
): Promise<WebLLMSupport> {
  const full = await checkOnDeviceGemmaSupport(hints);
  if (full.path === "webllm") {
    return { ok: true, reason: null, iosLike: full.iosLike, webgpu: full.webgpu };
  }
  return {
    ok: false,
    reason:
      full.path === "gemma-webgpu"
        ? "Use the Gemma 270M path on this device instead of WebLLM 2B."
        : (full.reason ?? "WebLLM is not supported in this browser"),
    iosLike: full.iosLike,
    webgpu: full.webgpu,
  };
}

export async function checkOnDeviceGemmaSupport(
  hints?: OnDeviceGemmaHints,
): Promise<OnDeviceGemmaSupport> {
  const iosLike = hints?.forceIos === true ? true : isIOSLike();
  const webgpu =
    typeof hints?.forceWebgpu === "boolean" ? hints.forceWebgpu : await hasUsableWebGPU();
  return resolveOnDeviceGemmaSupport(iosLike, webgpu);
}
