/**
 * WebLLM + Gemma 2B (~1.5GB) is a desktop WebGPU demo path.
 * iOS Safari will often hard-crash the tab (OOM / GPU process) with
 * "A problem repeatedly occurred" — that cannot be caught in JS.
 */

export type WebLLMSupport = {
  ok: boolean;
  /** Short reason when ok is false */
  reason: string | null;
  /** True when this is iPhone/iPad Safari (or iPadOS desktop UA) */
  iosLike: boolean;
  webgpu: boolean;
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

/**
 * Cheap sync hint for UI before async WebGPU probe finishes.
 * Never treat this alone as permission to load the model.
 */
export function isLikelyWebLLMHostile(): boolean {
  return isIOSLike();
}

export async function checkWebLLMSupport(): Promise<WebLLMSupport> {
  const iosLike = isIOSLike();
  if (iosLike) {
    return {
      ok: false,
      reason:
        "iPhone/iPad Safari cannot safely load Gemma in-browser — the ~1.5GB WebGPU model often crashes the tab (memory/GPU). Use the template narrator here, or open Insights in Chrome/Edge on a desktop.",
      iosLike: true,
      webgpu: false,
    };
  }

  const webgpu = await hasUsableWebGPU();
  if (!webgpu) {
    return {
      ok: false,
      reason:
        "WebGPU is not available in this browser. Use Chrome or Edge on a desktop for the Gemma (WebLLM) demo.",
      iosLike: false,
      webgpu: false,
    };
  }

  return { ok: true, reason: null, iosLike: false, webgpu: true };
}
