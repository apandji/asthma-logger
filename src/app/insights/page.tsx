import { Suspense } from "react";
import InsightsDemo from "./insights-demo";

export default function InsightsPage() {
  return (
    <Suspense
      fallback={
        <main className="mx-auto max-w-2xl px-4 py-10 text-sm text-neutral-500">Loading insights…</main>
      }
    >
      <InsightsDemo />
    </Suspense>
  );
}
