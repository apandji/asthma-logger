import { openDB, type DBSchema, type IDBPDatabase } from "idb";
import type { AttackLogDTO, LocalLog } from "./types";

interface AsthmaDB extends DBSchema {
  logs: {
    key: string;
    value: LocalLog;
    indexes: { "by-sync": string; "by-loggedAt": string };
  };
}

const DB_NAME = "asthma-log";
const DB_VERSION = 1;

let dbPromise: Promise<IDBPDatabase<AsthmaDB>> | null = null;

function getDb() {
  if (typeof window === "undefined") {
    throw new Error("IndexedDB is only available in the browser");
  }
  if (!dbPromise) {
    dbPromise = openDB<AsthmaDB>(DB_NAME, DB_VERSION, {
      upgrade(db) {
        const store = db.createObjectStore("logs", { keyPath: "id" });
        store.createIndex("by-sync", "syncStatus");
        store.createIndex("by-loggedAt", "loggedAt");
      },
    });
  }
  return dbPromise;
}

export async function putLocalLog(log: LocalLog): Promise<void> {
  const db = await getDb();
  await db.put("logs", log);
}

export async function getAllLocalLogs(): Promise<LocalLog[]> {
  const db = await getDb();
  const logs = await db.getAllFromIndex("logs", "by-loggedAt");
  return logs.reverse();
}

export async function getPendingLocalLogs(): Promise<LocalLog[]> {
  const db = await getDb();
  return db.getAllFromIndex("logs", "by-sync", "pending");
}

export async function markLocalSynced(id: string, serverLog: AttackLogDTO): Promise<void> {
  const db = await getDb();
  const existing = await db.get("logs", id);
  if (!existing) return;
  await db.put("logs", {
    ...existing,
    syncStatus: "synced",
    lastError: undefined,
    serverEnvStatus: serverLog.envStatus,
    serverLog,
  });
}

export async function markLocalSyncError(id: string, error: string): Promise<void> {
  const db = await getDb();
  const existing = await db.get("logs", id);
  if (!existing) return;
  await db.put("logs", {
    ...existing,
    syncStatus: "pending",
    lastError: error,
  });
}

export async function updateLocalFeeling(
  id: string,
  feeling: LocalLog["feeling"],
): Promise<void> {
  const db = await getDb();
  const existing = await db.get("logs", id);
  if (!existing) return;
  const next: LocalLog = { ...existing, feeling };
  if (existing.serverLog) {
    next.serverLog = { ...existing.serverLog, feeling };
  }
  await db.put("logs", next);
}
