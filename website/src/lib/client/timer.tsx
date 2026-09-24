"use client";

import { createContext, useContext, useEffect, useMemo, useRef, type ReactNode } from "react";
import { api } from "./api";
import { useNow } from "./clock";
import { useStore } from "./store";
import { useToast } from "./toast";
import { notify, playAlarm, playChime } from "./sound";
import { fmtClock, focusModeLabel } from "@/lib/shared/logic";
import type { FocusDTO, XpEvent } from "@/lib/shared/types";

interface TimerValue {
  secondsLeft: number;
  progress: number;
}

const TimerContext = createContext<TimerValue>({ secondsLeft: 0, progress: 0 });
export const useTimer = () => useContext(TimerContext);

export function FocusTimerProvider({ children }: { children: ReactNode }) {
  const { data, serverOffset, applyFocus, handleEvents } = useStore();
  const toast = useToast();
  const focus = data.focus;
  const now = useNow(250, focus.running);
  const pending = useRef(false);
  const lastAdvance = useRef(0);

  const secondsLeft =
    focus.running && focus.endsAt && now !== null
      ? Math.max(0, Math.ceil((focus.endsAt - (now + serverOffset)) / 1000))
      : focus.secondsLeft;

  // Phase finished: ask the server to advance it (it logs the session + XP).
  useEffect(() => {
    if (!focus.running || secondsLeft > 0 || pending.current) return;
    if (Date.now() - lastAdvance.current < 3000) return;
    pending.current = true;
    lastAdvance.current = Date.now();
    const prevMode = focus.mode;
    const prevVersion = focus.version;
    api<{ focus: FocusDTO; events: XpEvent[]; serverTime: number }>("/api/focus")
      .then((res) => {
        applyFocus(res.focus, res.serverTime);
        handleEvents(res.events);
        if (res.focus.version === prevVersion) return;
        playChime();
        if (prevMode === "work") {
          if (data.user.settings.alarmEnabled) playAlarm();
          notify("Focus session complete", "Nice work — time for a break.");
        } else {
          toast("Break over! Ready to focus.", "info");
          notify("Break over", "Ready to focus.");
        }
      })
      .catch(() => {})
      .finally(() => {
        pending.current = false;
      });
  }, [secondsLeft, focus, applyFocus, handleEvents, toast, data.user.settings.alarmEnabled]);

  // Show the countdown in the browser tab while running.
  useEffect(() => {
    document.title = focus.running
      ? `${fmtClock(secondsLeft)} · ${focusModeLabel(focus.mode)} — Focus System`
      : "Focus System";
  }, [focus.running, focus.mode, secondsLeft]);

  const progress = focus.totalSeconds > 0 ? (focus.totalSeconds - secondsLeft) / focus.totalSeconds : 0;
  const value = useMemo(() => ({ secondsLeft, progress }), [secondsLeft, progress]);
  return <TimerContext.Provider value={value}>{children}</TimerContext.Provider>;
}
