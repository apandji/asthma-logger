import { NextResponse } from "next/server";
import { z } from "zod";
import { createLogSchema, upsertAndEnrich } from "@/lib/logs";

export const dynamic = "force-dynamic";

const syncSchema = z.object({ logs: z.array(createLogSchema).min(1).max(50) });

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }
  const parsed = syncSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Validation failed", details: parsed.error.flatten() }, { status: 400 });
  }
  const results = [];
  for (const item of parsed.data.logs) {
    try {
      const log = await upsertAndEnrich(item);
      results.push({ id: item.id, ok: true as const, log });
    } catch (err) {
      const message = err instanceof Error ? err.message : "sync failed";
      results.push({ id: item.id, ok: false as const, error: message });
    }
  }
  return NextResponse.json({ results });
}
