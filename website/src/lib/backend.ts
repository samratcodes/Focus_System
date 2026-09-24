import type { BootstrapDTO } from "@/lib/shared/types";

export const SESSION_COOKIE = "fs_session";
export const BACKEND_URL = process.env.BACKEND_URL ?? "http://localhost:4000";

/**
 * Server-side call to the backend's GET /api/bootstrap with the visitor's
 * session cookie. Returns null when the session is missing, expired or revoked.
 */
export async function fetchBootstrap(token: string): Promise<BootstrapDTO | null> {
  const res = await fetch(`${BACKEND_URL}/api/bootstrap`, {
    headers: { Cookie: `${SESSION_COOKIE}=${encodeURIComponent(token)}` },
    cache: "no-store",
  });
  if (res.status === 401) return null;
  if (!res.ok) throw new Error(`Backend error ${res.status} from /api/bootstrap`);
  return (await res.json()) as BootstrapDTO;
}
