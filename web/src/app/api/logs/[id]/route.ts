import { NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { toDTO } from "@/lib/logs";

export const dynamic = "force-dynamic";

const patchSchema = z.object({
  feeling: z.enum(["ok", "mild", "bad"]).nullable(),
});

export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const parsed = patchSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Validation failed", details: parsed.error.flatten() },
      { status: 400 },
    );
  }

  const existing = await prisma.attackLog.findUnique({ where: { id } });
  if (!existing) {
    return NextResponse.json({ error: "Log not found" }, { status: 404 });
  }

  const row = await prisma.attackLog.update({
    where: { id },
    data: { feeling: parsed.data.feeling },
  });

  return NextResponse.json({ log: toDTO(row) });
}
