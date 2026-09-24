"use client";

// Data saved by the original HTML version lived in localStorage under these keys.
const KEYS = {
  tasks: "fs_tasks",
  goals: "fs_goals",
  xp: "fs_xp",
  pomoLog: "fs_pomo_log",
  streaks: "fs_streaks",
  pomoSettings: "fs_pomo_settings",
  focusAudio: "fs_focus_audio",
} as const;
const IMPORTED_FLAG = "fs_imported_to_account";

function read<T>(key: string): T | undefined {
  try {
    const v = localStorage.getItem(key);
    return v ? (JSON.parse(v) as T) : undefined;
  } catch {
    return undefined;
  }
}

export type LegacyData = Record<keyof typeof KEYS, unknown>;

/** The old app's data in this browser, or null if there is none / it was already imported. */
export function readLegacyData(userId: string): LegacyData | null {
  if (typeof localStorage === "undefined") return null;
  try {
    if (localStorage.getItem(IMPORTED_FLAG) === userId) return null;
  } catch {
    return null;
  }
  const tasks = read<unknown[]>(KEYS.tasks);
  const pomoLog = read<unknown[]>(KEYS.pomoLog);
  if (!tasks?.length && !pomoLog?.length) return null;
  return {
    tasks: tasks ?? [],
    goals: read(KEYS.goals) ?? [],
    xp: read(KEYS.xp) ?? 0,
    pomoLog: pomoLog ?? [],
    streaks: read(KEYS.streaks) ?? [],
    pomoSettings: read(KEYS.pomoSettings),
    focusAudio: read(KEYS.focusAudio),
  };
}

export function markLegacyImported(userId: string) {
  try {
    localStorage.setItem(IMPORTED_FLAG, userId);
  } catch {}
}
