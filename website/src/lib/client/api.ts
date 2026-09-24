"use client";

export class ApiClientError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

function timeZone() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch {
    return "UTC";
  }
}

/** Fetch wrapper for our own API: JSON in/out, cookie auth, sends the local time zone. */
export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  let res: Response;
  try {
    res = await fetch(path, {
      method: init.method ?? "GET",
      credentials: "same-origin",
      cache: "no-store",
      headers: {
        "Content-Type": "application/json",
        "X-Timezone": timeZone(),
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
  } catch {
    throw new ApiClientError(0, "You appear to be offline");
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    if (res.status === 401 && !path.startsWith("/api/auth/")) {
      hardNavigate("/login");
    }
    throw new ApiClientError(res.status, (data as { error?: string }).error ?? `Request failed (${res.status})`);
  }
  return data as T;
}

export { timeZone as clientTimeZone };

/**
 * Full page load (not client-side routing). Used after sign in/out so the
 * server re-renders the app with the new session cookie.
 */
export function hardNavigate(path: string) {
  window.location.assign(new URL(path, window.location.origin).toString());
}
