import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { createLogSchema, toDTO, upsertAndEnrich } from "@/lib/logs";

export const dynamic = "force-dynamic";

export async function GET() {
  const rows = await prisma.attackLog.findMany({ orderBy: { loggedAt: "desc" }, take: 100 });
  return NextResponse.json({ logs: rows.map(toDTO) });
}

export async function POST(request: Request) {
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
