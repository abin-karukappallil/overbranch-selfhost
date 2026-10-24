import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  devIndicators: false,
  compress: true,
  poweredByHeader: false,
  turbopack: {
    root: __dirname,
  },
  env: {
    PORT: "3000",
    NEXT_PUBLIC_APP_URL: "http://localhost:3000",
    NEXT_PUBLIC_BACKEND_URL: "http://localhost:8000",
    BACKEND_URL: "http://localhost:8000",
    DATABASE_URL: "file:./overbranch.db",
  },
  images: {
    formats: ["image/avif", "image/webp"],
    remotePatterns: [
      {
        protocol: "https",
        hostname: "**",
      },
    ],
  },
  experimental: {
    optimizePackageImports: [
      "lucide-react",
      "@hugeicons/react",
      "@hugeicons/core-free-icons",
      "framer-motion",
      "@radix-ui/react-accordion",
      "@radix-ui/react-context-menu",
      "@radix-ui/react-dropdown-menu",
      "@radix-ui/react-tabs",
      "@radix-ui/react-tooltip",
      "sonner",
    ],
  },
  outputFileTracingExcludes: {
    "*": [
      "uploads/**",
      "uploads/**/*",
      "backend/**",
      "backend/**/*",
      "**/*.pyc",
      "**/__pycache__/**",
    ],
  },
};

export default nextConfig;
