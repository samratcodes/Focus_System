"use client";

import { useRef, useState } from "react";
import { Download, LogOut, Smartphone, Upload } from "lucide-react";
import { api, hardNavigate } from "@/lib/client/api";
import { useMounted } from "@/lib/client/clock";
import { markLegacyImported, readLegacyData } from "@/lib/client/legacy";
import { useDialogs } from "@/lib/client/dialogs";
import { useStore } from "@/lib/client/store";
import { useToast } from "@/lib/client/toast";
import type { UserDTO } from "@/lib/shared/types";

/** Public address of the Node.js backend that the app talks to. */
const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000";

export default function SettingsPage() {
  const { data, setUser, updateSettings, refresh } = useStore();
  const toast = useToast();
  const { confirm } = useDialogs();
  const user = data.user;

  const [name, setName] = useState(user.name);
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [deletePassword, setDeletePassword] = useState("");
  const [legacyImported, setLegacyImported] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const mounted = useMounted();
  const hasLegacy = mounted && !legacyImported && !!readLegacyData(user.id);

  const saveProfile = async () => {
    try {
      const res = await api<{ user: UserDTO }>("/api/auth/me", { method: "PATCH", body: { name } });
      setUser(res.user);
      toast("Profile saved", "success");
    } catch (e) {
      toast(e instanceof Error ? e.message : "Could not save", "error");
    }
  };

  const changePassword = async () => {
    if (newPassword.length < 8) return toast("New password must be at least 8 characters", "error");
    try {
      await api("/api/auth/me", { method: "PATCH", body: { currentPassword, newPassword } });
      setCurrentPassword("");
      setNewPassword("");
      toast("Password changed. Other devices were signed out.", "success");
    } catch (e) {
      toast(e instanceof Error ? e.message : "Could not change password", "error");
    }
  };

  const importPayload = async (payload: unknown) => {
    try {
      const res = await api<{ imported: { tasks: number; goals: number } }>("/api/import", {
        method: "POST",
        body: payload,
      });
      await refresh();
      toast(`Imported ${res.imported.tasks} tasks`, "success");
      return true;
    } catch (e) {
      toast(e instanceof Error ? e.message : "Import failed", "error");
      return false;
    }
  };

  const importFromBrowser = async () => {
    const legacy = readLegacyData(user.id);
    if (legacy && (await importPayload(legacy))) {
      markLegacyImported(user.id);
      setLegacyImported(true);
    }
  };

  const importFile = async (file: File) => {
    try {
      await importPayload(JSON.parse(await file.text()));
    } catch {
      toast("That file is not valid JSON", "error");
    }
  };

  // Exported in the original app's format, so it can be re-imported anywhere.
  const exportData = () => {
    const payload = {
      exportedAt: new Date().toISOString(),
      tasks: data.tasks.map((t) => ({
        id: t.id,
        title: t.title,
        goalId: t.goalId,
        description: t.description,
        completed: t.completed,
        createdAt: t.createdAt,
        dueDate: t.dueDate,
        startTime: t.startTime,
        endTime: t.endTime,
        eisenhower: t.eisenhower,
        eatTheFrog: t.isPriority,
        pomodoroCount: t.pomodoroCount,
        subtasks: t.subtasks.map((s) => ({ id: s.id, title: s.title, completed: s.completed })),
      })),
      goals: data.goals.map((g) => ({ id: g.id, title: g.title, color: g.color, icon: g.icon })),
      xp: user.xp,
      pomoLog: data.pomoLogs.map((l) => ({ date: l.date, sessions: l.sessions, taskId: l.taskId })),
      streaks: data.streakDays,
      pomoSettings: {
        work: user.settings.pomoWork,
        shortBreak: user.settings.pomoShortBreak,
        longBreak: user.settings.pomoLongBreak,
        longBreakInterval: user.settings.pomoLongInterval,
      },
      focusAudio: { youtubeUrl: user.settings.youtubeUrl, alarmEnabled: user.settings.alarmEnabled },
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `focus-system-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const logout = async (everywhere: boolean) => {
    if (everywhere) {
      const ok = await confirm({
        title: "Sign out everywhere?",
        message: "This signs you out on this browser, the mobile app and every other device.",
        confirmLabel: "Sign out everywhere",
        danger: true,
      });
      if (!ok) return;
    }
    await api("/api/auth/logout", { method: "POST", body: { everywhere } }).catch(() => {});
    hardNavigate("/login");
  };

  const deleteAccount = async () => {
    if (!deletePassword) return toast("Enter your password to confirm", "error");
    const ok = await confirm({
      title: "Delete your account?",
      message: "All tasks, goals, focus history and XP will be permanently deleted. This cannot be undone.",
      confirmLabel: "Delete forever",
      danger: true,
    });
    if (!ok) return;
    try {
      await api("/api/auth/me", { method: "DELETE", body: { password: deletePassword } });
      hardNavigate("/register");
    } catch (e) {
      toast(e instanceof Error ? e.message : "Could not delete account", "error");
    }
  };

  return (
    <>
      <section className="analytics-head">
        <div>
          <div className="daily-label">Account</div>
          <h1>Settings</h1>
        </div>
      </section>

      <div className="settings-grid">
        <div className="settings-card">
          <h4>Profile</h4>
          <div className="field">
            <label>Name</label>
            <input value={name} maxLength={80} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="field">
            <label>Email</label>
            <input value={user.email} disabled />
          </div>
          <div className="field">
            <label>Time zone</label>
            <input value={user.timezone} disabled />
            <small>Detected from your device. &quot;Today&quot; follows this time zone.</small>
          </div>
          <div className="actions">
            <button className="btn btn-primary" onClick={saveProfile} disabled={!name.trim() || name === user.name}>
              Save profile
            </button>
          </div>
        </div>

        <div className="settings-card">
          <h4>Password</h4>
          <div className="field">
            <label>Current password</label>
            <input
              type="password"
              autoComplete="current-password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
            />
          </div>
          <div className="field">
            <label>New password</label>
            <input
              type="password"
              autoComplete="new-password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
            />
            <small>At least 8 characters. Other devices will be signed out.</small>
          </div>
          <div className="actions">
            <button className="btn btn-primary" onClick={changePassword} disabled={!currentPassword || !newPassword}>
              Change password
            </button>
          </div>
        </div>

        <div className="settings-card">
          <h4>
            <Smartphone style={{ width: 13, height: 13, verticalAlign: "-2px" }} /> Mobile app
          </h4>
          <p>
            The Focus System app uses the same account and data. In the app, sign in with <strong>{user.email}</strong>{" "}
            and set the server address to the backend API:
          </p>
          <code>{API_URL}</code>
          <p>
            On a phone, use your computer&apos;s network address instead of <code>localhost</code> (for example{" "}
            <code>http://192.168.1.20:4000</code>).
          </p>
        </div>

        <div className="settings-card">
          <h4>Reminders & alarms</h4>
          <div className="toggle-row">
            <span>Focus alarm sound</span>
            <input
              type="checkbox"
              checked={user.settings.alarmEnabled}
              onChange={(e) => updateSettings({ alarmEnabled: e.target.checked })}
            />
          </div>
          <div className="field">
            <label>Task reminders (mobile app)</label>
            <select
              value={user.settings.reminderMinutes}
              onChange={(e) => updateSettings({ reminderMinutes: Number(e.target.value) })}
            >
              <option value={-1}>Off</option>
              <option value={0}>At start time</option>
              <option value={5}>5 minutes before</option>
              <option value={10}>10 minutes before</option>
              <option value={15}>15 minutes before</option>
              <option value={30}>30 minutes before</option>
              <option value={60}>1 hour before</option>
            </select>
            <small>Tasks with a start time trigger a phone notification.</small>
          </div>
        </div>

        <div className="settings-card">
          <h4>Your data</h4>
          <p>Export everything as JSON, or import data from the original Focus System.</p>
          <div className="actions">
            <button className="btn btn-secondary" onClick={exportData}>
              <Download /> Export JSON
            </button>
            <button className="btn btn-secondary" onClick={() => fileRef.current?.click()}>
              <Upload /> Import JSON
            </button>
            {hasLegacy && (
              <button className="btn btn-primary" onClick={importFromBrowser}>
                <Upload /> Import from this browser
              </button>
            )}
          </div>
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) importFile(f);
              e.target.value = "";
            }}
          />
        </div>

        <div className="settings-card">
          <h4>Session</h4>
          <p>Signed in as {user.email}.</p>
          <div className="actions">
            <button className="btn btn-secondary" onClick={() => logout(false)}>
              <LogOut /> Sign out
            </button>
            <button className="btn btn-danger" onClick={() => logout(true)}>
              Sign out everywhere
            </button>
          </div>
        </div>

        <div className="settings-card danger">
          <h4>Delete account</h4>
          <p>Permanently delete your account and all of its data.</p>
          <div className="field">
            <label>Password</label>
            <input
              type="password"
              autoComplete="current-password"
              value={deletePassword}
              onChange={(e) => setDeletePassword(e.target.value)}
            />
          </div>
          <div className="actions">
            <button className="btn btn-danger" onClick={deleteAccount}>
              Delete account
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
