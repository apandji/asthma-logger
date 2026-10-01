import { getAllLocalLogs } from "@/lib/local-db";
import type { AttackLogDTO } from "@/lib/types";

/** Merge server diary with IndexedDB copies (prefer server row when synced). */
export async function loadDiaryLogs(): Promise<AttackLogDTO[]> {
  const byId = new Map<string, AttackLogDTO>();

  try {
    const res = await fetch("/api/logs", { cache: "no-store" });
    if (res.ok) {
      const data = (await res.json()) as { logs?: AttackLogDTO[] };
      for (const log of data.logs ?? []) {
        byId.set(log.id, log);
      }
    }
  } catch {
    /* offline — local only */
  }

  try {
    const local = await getAllLocalLogs();
    for (const row of local) {
      if (row.serverLog) {
        byId.set(row.id, row.serverLog);
      }
    }
  } catch {
    /* SSR or private mode */
  }

  return [...byId.values()].sort(
    (a, b) => new Date(b.loggedAt).getTime() - new Date(a.loggedAt).getTime(),
  );
}
