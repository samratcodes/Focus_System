import type { NextConfig } from "next";

/** The Node.js + Express + Prisma backend (see ../backend). */
const BACKEND_URL = process.env.BACKEND_URL ?? "http://localhost:4000";

const nextConfig: NextConfig = {
  // The browser calls /api/* on the website's own origin, so the httpOnly
  // session cookie set by the backend just works. Next forwards it to the backend.
  async rewrites() {
    return [{ source: "/api/:path*", destination: `${BACKEND_URL}/api/:path*` }];
  },
};

export default nextConfig;
