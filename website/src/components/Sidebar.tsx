"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BarChart3, Calendar, Settings, Sun, Target, Timer, Trophy } from "lucide-react";
import { todayTasks, useStore } from "@/lib/client/store";
import { getLevelInfo, streakCount } from "@/lib/shared/logic";

export default function Sidebar() {
  const pathname = usePathname();
  const { data, today, ui, online } = useStore();

  const tasks = todayTasks(data.tasks, today, ui.activeGoalId);
  const done = tasks.filter((t) => t.completed).length;
  const total = tasks.length;
  const rate = total ? Math.round((done / total) * 100) : 0;
  const pomos = data.pomoLogs.filter((l) => l.date === today).reduce((s, l) => s + (l.sessions || 1), 0);
  const lvl = getLevelInfo(data.user.xp);
  const initials = data.user.name
    .split(/\s+/)
    .map((p) => p[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  const nav = (href: string) => `nav-item ${pathname === href ? "active" : ""}`;

  return (
    <aside className="sidebar" id="sidebar">
      <div className="sidebar-brand">
        <Target />
        <span>Focus System</span>
      </div>
      <nav className="sidebar-nav">
        <Link href="/" className={nav("/")}>
          <Sun /> <span>Today</span>
          <span className="nav-badge">{total}</span>
        </Link>
        <Link href="/calendar" className={nav("/calendar")}>
          <Calendar /> <span>Calendar</span>
        </Link>
        <Link href="/focus" className={nav("/focus")}>
          <Timer /> <span>Focus</span>
          {data.focus.running && <span className="nav-badge">On</span>}
        </Link>
        <Link href="/analytics" className={nav("/analytics")}>
          <BarChart3 /> <span>Analytics</span>
        </Link>
      </nav>

      <div className="sidebar-section">
        <div className="sidebar-label">Progress</div>
        <div className="quick-stats">
          <div className="level-badge-container">
            <div className="level-badge-title">
              <Trophy style={{ width: 14, height: 14 }} />
              <span>
                Lvl {lvl.level} ({lvl.xpInLevel}/100 XP)
              </span>
            </div>
          </div>
          <div className="stat-row">
            <span>Completed</span>
            <span className="stat-value">
              {done}/{total}
            </span>
          </div>
          <div className="stat-bar">
            <div className="stat-bar-fill" style={{ width: `${rate}%` }} />
          </div>
          <div className="stat-row" style={{ marginTop: 4 }}>
            <span>Streak</span>
            <span className="stat-value">{streakCount(data.streakDays, today)} days</span>
          </div>
          <div className="stat-row">
            <span>Focus</span>
            <span className="stat-value">{pomos}</span>
          </div>
        </div>
      </div>

      <div className="sidebar-footer">
        <Link href="/settings" className={nav("/settings")}>
          <Settings /> <span>Settings</span>
        </Link>
        <div className="sidebar-user" title={online ? "Synced" : "Offline — changes may not be saved"}>
          <div className="sidebar-avatar">{initials || "?"}</div>
          <div className="sidebar-user-meta">
            <strong>{data.user.name}</strong>
            <span>
              <i className={`sync-dot ${online ? "" : "offline"}`} />
              {online ? "Synced" : "Offline"}
            </span>
          </div>
        </div>
      </div>
    </aside>
  );
}
