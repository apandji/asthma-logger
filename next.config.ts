import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@mlc-ai/web-llm", "gemma-webgpu"],
  headers: async () => [
    {
      source: "/((?!_next/static|_next/image|favicon.ico).*)",
      headers: [{ key: "Cache-Control", value: "no-cache, must-revalidate" }],
    },
  ],
};

export default nextConfig;
