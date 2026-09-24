import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { fetchBootstrap, SESSION_COOKIE } from "@/lib/backend";
import AppShell from "@/components/AppShell";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!token) redirect("/login");

  const initial = await fetchBootstrap(token);
  // Expired / revoked session (e.g. password changed elsewhere): the backend clears the cookie.
  if (!initial) redirect("/api/auth/logout");

  return <AppShell initial={initial}>{children}</AppShell>;
}
