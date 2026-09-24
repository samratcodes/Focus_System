"use client";

import { useMemo, useSyncExternalStore } from "react";

const noopSubscribe = () => () => {};

/**
 * Current time (epoch ms) rounded down to `quantumMs`, re-rendering only when it
 * changes. Returns null during SSR and hydration so markup always matches.
 */
export function useNow(quantumMs: number, active = true): number | null {
  const subscribe = useMemo(
    () =>
      active
        ? (onChange: () => void) => {
            const id = setInterval(onChange, Math.min(quantumMs, 1000));
            return () => clearInterval(id);
          }
        : noopSubscribe,
    [quantumMs, active],
  );
  return useSyncExternalStore(
    subscribe,
    () => Math.floor(Date.now() / quantumMs) * quantumMs,
    () => null,
  );
}

/** False on the server and during hydration, true afterwards. */
export function useMounted() {
  return useSyncExternalStore(
    noopSubscribe,
    () => true,
    () => false,
  );
}
