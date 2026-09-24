"use client";

import { useRef, useState } from "react";
import { Brain, Coffee, Maximize2, Music, Pause, Play, RotateCcw, SkipForward, Sofa, Square } from "lucide-react";
import YoutubeFrame from "@/components/YoutubeFrame";
import { tasksForDate, useStore, type FocusMode } from "@/lib/client/store";
import { useTimer } from "@/lib/client/timer";
import { useToast } from "@/lib/client/toast";
import { requestNotificationPermission } from "@/lib/client/sound";
import { fmtClock, focusModeLabel, youtubeId } from "@/lib/shared/logic";
import type { UserSettings } from "@/lib/shared/types";

const RADIUS = 115;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

const MODES: { mode: FocusMode; label: string; icon: typeof Brain }[] = [
  { mode: "work", label: "Focus", icon: Brain },
  { mode: "shortBreak", label: "Short break", icon: Coffee },
  { mode: "longBreak", label: "Long break", icon: Sofa },
];

export default function FocusPage() {
  const store = useStore();
  const { data, today, focusAction, setFocusMode, attachTask, updateSettings, overlayOpen, setOverlayOpen, musicPlaying, setMusicPlaying } =
    store;
  const { secondsLeft, progress } = useTimer();
  const toast = useToast();
  const focus = data.focus;
  const settings = data.user.settings;
  const [url, setUrl] = useState(settings.youtubeUrl);
  const [syncedUrl, setSyncedUrl] = useState(settings.youtubeUrl);
  if (syncedUrl !== settings.youtubeUrl) {
    // Saved elsewhere (e.g. the app): adopt the new value.
    setSyncedUrl(settings.youtubeUrl);
    setUrl(settings.youtubeUrl);
  }

  const openTasks = tasksForDate(data.tasks, today).filter((t) => !t.completed);
  const attached = focus.attachedTaskId ? data.tasks.find((t) => t.id === focus.attachedTaskId) : null;
  const options = attached && !openTasks.includes(attached) ? [attached, ...openTasks] : openTasks;
  const logs = data.pomoLogs.filter((l) => l.date === today);
  const isWork = focus.mode === "work";

  // Where we are in the cycle of work sessions before a long break.
  const interval = settings.pomoLongInterval;
  const doneInCycle = focus.sessionCount % interval;
  const nextIsLong = isWork && (focus.sessionCount + 1) % interval === 0;
  const nextLabel = isWork
    ? nextIsLong
      ? `Long break · ${settings.pomoLongBreak} min`
      : `Short break · ${settings.pomoShortBreak} min`
    : `Focus · ${settings.pomoWork} min`;

  const saveMusic = async (silent = false) => {
    const clean = url.trim();
    if (clean && !youtubeId(clean)) {
      toast("Paste a valid YouTube link", "error");
      return false;
    }
    if (clean !== settings.youtubeUrl) {
      if (!(await updateSettings({ youtubeUrl: clean }))) return false;
    }
    if (!silent) toast("Music saved", "success");
    return true;
  };

  const playMusic = async () => {
    if ((await saveMusic(true)) && youtubeId(url)) setMusicPlaying(true);
  };

  const start = async () => {
    requestNotificationPermission();
    await focusAction("start");
    if (youtubeId(settings.youtubeUrl)) setMusicPlaying(true);
  };
  const pause = async () => {
    await focusAction("pause");
    setMusicPlaying(false);
  };
  const reset = async () => {
    await focusAction("reset");
    setMusicPlaying(false);
  };

  return (
    <div className="focus-layout">
      <div className="focus-timer-area">
        <div className="mode-tabs" role="tablist" aria-label="Timer mode">
          {MODES.map(({ mode, label, icon: Icon }) => (
            <button
              key={mode}
              role="tab"
              aria-selected={focus.mode === mode}
              className={`${focus.mode === mode ? "active" : ""} ${mode !== "work" ? "break" : ""}`}
              onClick={() => focus.mode !== mode && setFocusMode(mode)}
              title={label}
            >
              <Icon />
              <span>{label}</span>
            </button>
          ))}
        </div>
        <div className="timer-ring">
          <svg width="260" height="260" viewBox="0 0 260 260">
            <circle className="ring-bg" cx="130" cy="130" r={RADIUS} />
            <circle
              className={`ring-progress${!isWork ? " break" : ""}`}
              cx="130"
              cy="130"
              r={RADIUS}
              strokeDasharray={CIRCUMFERENCE}
              strokeDashoffset={CIRCUMFERENCE * (1 - progress)}
            />
          </svg>
          <div className="timer-time" id="timer-display">
            {fmtClock(secondsLeft)}
          </div>
          <div className="timer-label" style={{ color: isWork ? "var(--primary)" : "var(--success)" }}>
            {focusModeLabel(focus.mode)}
          </div>
        </div>
        <div className="timer-controls" id="timer-controls">
          {focus.running ? (
            <button className="btn btn-secondary" onClick={pause}>
              <Pause /> Pause
            </button>
          ) : (
            <button className="btn btn-primary" onClick={start}>
              <Play /> Start
            </button>
          )}
          <button className="btn btn-secondary" onClick={reset}>
            <RotateCcw /> Reset
          </button>
          {!isWork && (
            <button className="btn btn-secondary" onClick={() => focusAction("skip")} title="Skip break">
              <SkipForward /> Skip
            </button>
          )}
        </div>
        <div className="cycle">
          <div className="cycle-dots" title={`${doneInCycle} of ${interval} sessions until a long break`}>
            {Array.from({ length: interval }, (_, i) => (
              <i key={i} className={i < doneInCycle ? "done" : i === doneInCycle && isWork ? "current" : ""} />
            ))}
          </div>
          <div className="cycle-next">
            <Coffee /> Next: {nextLabel}
          </div>
        </div>
        <div className="timer-sessions">
          Sessions completed: <span>{focus.sessionCount}</span>
        </div>
        <button className="btn btn-secondary" onClick={() => setOverlayOpen(true)} style={{ marginTop: 8 }}>
          <Maximize2 /> Fullscreen Focus
        </button>
      </div>

      <div className="focus-sidebar">
        <div className="focus-card">
          <h4>Attach task</h4>
          <select
            id="focus-task-select"
            value={focus.attachedTaskId ?? ""}
            onChange={(e) => attachTask(e.target.value || null)}
          >
            <option value="">None</option>
            {options.map((t) => {
              const g = t.goalId ? data.goals.find((x) => x.id === t.goalId) : null;
              return (
                <option key={t.id} value={t.id}>
                  {t.title}
                  {g ? ` [${g.title}]` : ""}
                </option>
              );
            })}
          </select>
        </div>

        <div className="focus-card music-card">
          <h4>Background music</h4>
          <div className="music-input-row">
            <input
              type="url"
              placeholder="Paste YouTube link"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && saveMusic()}
            />
            <button className="btn btn-sm btn-primary" onClick={() => saveMusic()}>
              Save
            </button>
          </div>
          <div className="music-actions">
            <button className="btn btn-sm btn-secondary" onClick={playMusic}>
              <Music /> Play
            </button>
            <button className="btn btn-sm btn-secondary" onClick={() => setMusicPlaying(false)}>
              <Square /> Stop
            </button>
            <label>
              <input
                type="checkbox"
                checked={settings.alarmEnabled}
                onChange={(e) => updateSettings({ alarmEnabled: e.target.checked })}
              />{" "}
              Alarm
            </label>
          </div>
          <div className="youtube-frame-wrap" id="youtube-frame-wrap">
            {/* The overlay plays its own copy; pause this one while it is open. */}
            <YoutubeFrame url={settings.youtubeUrl} autoplay={musicPlaying && !overlayOpen} />
          </div>
        </div>

        <div className="focus-card">
          <h4>Timer settings</h4>
          <SettingRow label="Work" field="pomoWork" max={120} />
          <SettingRow label="Short" field="pomoShortBreak" max={60} />
          <SettingRow label="Long" field="pomoLongBreak" max={60} />
          <SettingRow label="Interval" field="pomoLongInterval" max={10} />
        </div>

        <div className="focus-card">
          <h4>Today sessions</h4>
          <div className="focus-log">
            {logs.length ? (
              logs
                .slice(-10)
                .reverse()
                .map((l) => {
                  const t = l.taskId ? data.tasks.find((x) => x.id === l.taskId) : null;
                  return (
                    <div className="focus-log-entry" key={l.id}>
                      <span>{t ? t.title.slice(0, 25) : "Untracked"}</span>
                      <span>{l.sessions || 1}</span>
                    </div>
                  );
                })
            ) : (
              <div className="music-empty">No sessions yet today.</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

type NumericSetting = "pomoWork" | "pomoShortBreak" | "pomoLongBreak" | "pomoLongInterval";

/** Number input that saves shortly after the user stops typing/stepping. */
function SettingRow({ label, field, max }: { label: string; field: NumericSetting; max: number }) {
  const { data, updateSettings } = useStore();
  const saved = data.user.settings[field];
  const [value, setValue] = useState(String(saved));
  const [synced, setSynced] = useState(saved);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  if (synced !== saved) {
    setSynced(saved);
    setValue(String(saved));
  }

  const commit = (raw: string) => {
    const v = parseInt(raw, 10);
    if (isNaN(v) || v < 1 || v > max || v === saved) return;
    updateSettings({ [field]: v } as Partial<UserSettings>);
  };

  return (
    <div className="settings-row">
      <label>{label}</label>
      <input
        type="number"
        value={value}
        min={1}
        max={max}
        onChange={(e) => {
          setValue(e.target.value);
          if (timer.current) clearTimeout(timer.current);
          const raw = e.target.value;
          timer.current = setTimeout(() => commit(raw), 600);
        }}
        onBlur={(e) => commit(e.target.value)}
      />
    </div>
  );
}
