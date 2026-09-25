import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildDemoAttackLogs, shouldUseDemoLogs } from "@/lib/insights/demo-logs";
import { createLogSchema, toDTO, upsertAndEnrich } from "@/lib/logs";

export const dynamic = "force-dynamic";

export async function GET() {
  if (shouldUseDemoLogs()) {
    return NextResponse.json({
      logs: buildDemoAttackLogs(),
      demo: true,
      note: "In-memory demo diary (no DATABASE_URL). Set DEMO_SEED=0 and DATABASE_URL for real data.",
    });
  }

  try {
    const rows = await prisma.attackLog.findMany({ orderBy: { loggedAt: "desc" }, take: 100 });
    return NextResponse.json({ logs: rows.map(toDTO) });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Database unavailable";
    // Keep demos working even if DATABASE_URL is set but unreachable.
    return NextResponse.json({
      logs: buildDemoAttackLogs(),
      demo: true,
      note: `Fell back to demo diary: ${message}`,
    });
  }
}

export async function POST(request: Request) {
  if (shouldUseDemoLogs()) {
    return NextResponse.json(
      {
        error:
          "Demo mode (no DATABASE_URL). Logging is read-only here — set DATABASE_URL to persist new entries.",
      },
      { status: 503 },
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }
  const parsed = createLogSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Validation failed", details: parsed.error.flatten() }, { status: 400 });
  }
  try {
    const log = await upsertAndEnrich(parsed.data);
    return NextResponse.json({ log });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Server error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
