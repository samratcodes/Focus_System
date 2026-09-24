"use client";

import { useStore } from "@/lib/client/store";
import { useTimer } from "@/lib/client/timer";
import { fmtClock, focusModeLabel } from "@/lib/shared/logic";
import YoutubeFrame from "./YoutubeFrame";

export default function FocusOverlay() {
  const { data, overlayOpen, setOverlayOpen } = useStore();
  const { secondsLeft } = useTimer();
  if (!overlayOpen) return null;

  const task = data.focus.attachedTaskId ? data.tasks.find((t) => t.id === data.focus.attachedTaskId) : null;
  const url = data.user.settings.youtubeUrl;

  return (
    <div
      className="focus-overlay active"
      id="focus-overlay"
      onClick={(e) => e.target === e.currentTarget && setOverlayOpen(false)}
    >
      <button className="overlay-exit" onClick={() => setOverlayOpen(false)}>
        Exit Focus Mode
      </button>
      <div className="overlay-task">{task ? task.title : "Deep Work Focus Session"}</div>
      <div className="overlay-timer">{fmtClock(secondsLeft)}</div>
      <div className="overlay-label">{focusModeLabel(data.focus.mode)}</div>
      {url && (
        <div className="overlay-music">
          <YoutubeFrame url={url} autoplay />
        </div>
      )}
    </div>
  );
}
