import { NextResponse } from "next/server";
import { SELFHOST_SESSION } from "@/lib/get-server-session";

export const dynamic = "force-dynamic";

export async function GET() {
  return NextResponse.json(SELFHOST_SESSION);
}

export async function POST() {
  return NextResponse.json(SELFHOST_SESSION);
}

export async function PUT() {
  return NextResponse.json(SELFHOST_SESSION);
}

export async function DELETE() {
  return NextResponse.json({ status: "ok" });
}