import React from "react";
import { LandingHeader } from "@/components/landing/Header";
import { LandingHero } from "@/components/landing/Hero";
import { getServerSession } from "@/lib/get-server-session";

export default async function HomePage() {
  const session = await getServerSession();
  const isAuthenticated = Boolean(session?.user);

  return (
    <div className="min-h-screen bg-[#00CC68] text-black selection:bg-black selection:text-[#00CC68] overflow-x-clip max-w-full font-sans antialiased">
      <LandingHeader initialIsAuthenticated={isAuthenticated} />

      <main>
        <LandingHero initialIsAuthenticated={isAuthenticated} />
      </main>
    </div>
  );
}