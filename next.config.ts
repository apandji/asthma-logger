import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Cloudflare quick tunnels (and similar) hit the dev server from a non-localhost host.
  allowedDevOrigins: [
    "*.trycloudflare.com",
    "*.loca.lt",
    "meaningful-trips-modification-generated.trycloudflare.com",
  ],
  transpilePackages: ["@mlc-ai/web-llm", "gemma-webgpu"],
  headers: async () => [
    {
      source: "/((?!_next/static|_next/image|favicon.ico).*)",
      headers: [{ key: "Cache-Control", value: "no-cache, must-revalidate" }],
    },
  ],
};

export default nextConfig;
