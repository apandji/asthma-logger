import { NextResponse } from "next/server";
import { lookupPlaceName } from "@/lib/place";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const lat = Number(url.searchParams.get("lat"));
  const lon = Number(url.searchParams.get("lon"));
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return NextResponse.json({ error: "lat and lon required" }, { status: 400 });
  }
  if (lat < 18 || lat > 72 || lon < -180 || lon > -65) {
    return NextResponse.json({ placeName: null });
  }
  try {
    const placeName = await lookupPlaceName(lat, lon);
    return NextResponse.json({ placeName });
  } catch {
    return NextResponse.json({ placeName: null });
  }
}
