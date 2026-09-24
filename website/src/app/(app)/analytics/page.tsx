"use client";

import { tasksForDate, useStore, type AnalyticsPeriod } from "@/lib/client/store";
import { fmtDateShort, getLevelInfo, shiftDate, streakCount } from "@/lib/shared/logic";
import type { TaskDTO } from "@/lib/shared/types";

function periodDays(today: string, period: AnalyticsPeriod) {
  const count = period === "day" ? 1 : period === "month" ? 30 : 7;
  return Array.from({ length: count }, (_, i) => shiftDate(today, i - count + 1));
}

export default function AnalyticsPage() {
  const { data, today, ui, setUi } = useStore();
  const period = ui.analyticsPeriod;
  const days = periodDays(today, period);
  const daySet = new Set(days);
  const tasks = data.tasks.filter((t) => daySet.has(t.dueDate));
  const done = tasks.filter((t) => t.completed);
  const rate = tasks.length ? Math.round((done.length / tasks.length) * 100) : 0;
  const periodLogs = data.pomoLogs.filter((l) => daySet.has(l.date));
  const sessions = periodLogs.reduce((s, l) => s + (l.sessions || 1), 0);
  const minutes = periodLogs.reduce((s, l) => s + (l.minutes || (l.sessions || 1) * data.user.settings.pomoWork), 0);
  const bestDay =
    days
      .map((ds) => {
        const list = tasksForDate(data.tasks, ds);
        return { date: ds, done: list.filter((x) => x.completed).length };
      })
      .sort((a, b) => b.done - a.done)[0] ?? { date: today, done: 0 };
  const avg = days.length ? Math.round((done.length / days.length) * 10) / 10 : 0;
  const periodLabel = period === "day" ? "Today" : period === "week" ? "Last 7 days" : "Last 30 days";

  return (
    <>
      <section className="analytics-head">
        <div>
          <div className="daily-label">{periodLabel}</div>
          <h1>Performance dashboard</h1>
        </div>
        <div className="period-tabs">
          {(["day", "week", "month"] as const).map((p) => (
            <button key={p} className={period === p ? "active" : ""} onClick={() => setUi({ analyticsPeriod: p })}>
              {p[0].toUpperCase() + p.slice(1)}
            </button>
          ))}
        </div>
      </section>

      <section className="analytics-summary-grid">
        <div className="metric-card">
          <span>Completion</span>
          <strong>{rate}%</strong>
          <em>
            {done.length} of {tasks.length} tasks
          </em>
        </div>
        <div className="metric-card">
          <span>Daily average</span>
          <strong>{avg}</strong>
          <em>completed tasks</em>
        </div>
        <div className="metric-card">
          <span>Focus time</span>
          <strong>{minutes}m</strong>
          <em>{sessions} sessions</em>
        </div>
        <div className="metric-card">
          <span>Best day</span>
          <strong>{bestDay.done}</strong>
          <em>{fmtDateShort(bestDay.date)}</em>
        </div>
      </section>

      <section className="analytics-card full-width">
        <h4>Day by day results</h4>
        <div className="performance-bars">
          {days.map((ds) => {
            const list = tasksForDate(data.tasks, ds);
            const d = list.filter((t) => t.completed).length;
            const r = list.length ? Math.round((d / list.length) * 100) : 0;
            const color = r >= 80 ? "var(--success)" : r >= 40 ? "var(--primary)" : "var(--warning)";
            return (
              <div className="perf-day" key={ds}>
                <div className="perf-bar">
                  <i style={{ height: `${Math.max(6, r)}%`, background: color }} />
                </div>
                <strong>{r}%</strong>
                <span>{fmtDateShort(ds)}</span>
                <em>
                  {d}/{list.length}
                </em>
              </div>
            );
          })}
        </div>
      </section>

      <section className="analytics-two-col">
        <div className="analytics-card">
          <h4>By goal/category</h4>
          <GoalBreakdown tasks={tasks} />
        </div>
        <div className="analytics-card">
          <h4>Task type</h4>
          <Matrix tasks={tasks} />
        </div>
      </section>

      <section className="analytics-extra">
        <div className="analytics-card">
          <h4>Streak</h4>
          <div className="streak-display">
            <div className="streak-number">{streakCount(data.streakDays, today)}</div>
            <div className="streak-label">
              days in a row
              <br />
              with activity
            </div>
          </div>
          <div className="streak-days">
            {periodDays(today, "month").map((ds) => (
              <div
                key={ds}
                title={fmtDateShort(ds)}
                className={`streak-day ${data.streakDays.includes(ds) ? "active" : ""} ${ds === today ? "today" : ""}`}
              />
            ))}
          </div>
        </div>
        <LevelCard xp={data.user.xp} />
      </section>
    </>
  );
}

function GoalBreakdown({ tasks }: { tasks: TaskDTO[] }) {
  const { data } = useStore();
  const rows = data.goals
    .map((g) => {
      const gt = tasks.filter((t) => t.goalId === g.id);
      return { key: g.id, title: g.title, color: g.color, total: gt.length, done: gt.filter((t) => t.completed).length };
    })
    .filter((r) => r.total > 0);
  const none = tasks.filter((t) => !t.goalId);
  if (none.length) {
    rows.push({
      key: "none",
      title: "No goal",
      color: "var(--text-muted)",
      total: none.length,
      done: none.filter((t) => t.completed).length,
    });
  }
  if (!rows.length) return <div className="empty-state compact-empty">No category data yet.</div>;
  return (
    <div className="breakdown-list">
      {rows.map((r) => {
        const pct = r.total ? Math.round((r.done / r.total) * 100) : 0;
        return (
          <div className="breakdown-row" key={r.key}>
            <div>
              <span className="goal-dot" style={{ background: r.color }} />
              <strong>{r.title}</strong>
              <small>
                {r.done}/{r.total} complete
              </small>
            </div>
            <div className="mini-track">
              <i style={{ width: `${pct}%`, background: r.color }} />
            </div>
            <b>{pct}%</b>
          </div>
        );
      })}
    </div>
  );
}

function Matrix({ tasks }: { tasks: TaskDTO[] }) {
  const open = tasks.filter((t) => !t.completed);
  const keys = [
    ["do-first", "Do First"],
    ["schedule", "Schedule"],
    ["delegate", "Delegate"],
    ["eliminate", "Eliminate"],
  ] as const;
  return (
    <div className="matrix-grid">
      {keys.map(([k, label]) => (
        <div className="matrix-cell" key={k}>
          <div className="matrix-count">{open.filter((t) => t.eisenhower === k).length}</div>
          <div className="matrix-label">{label}</div>
        </div>
      ))}
    </div>
  );
}

function LevelCard({ xp }: { xp: number }) {
  const lvl = getLevelInfo(xp);
  return (
    <div className="analytics-card">
      <h4>Level</h4>
      <div className="level-display">
        <div className="level-number">{lvl.level}</div>
        <div className="streak-label">
          {xp} XP total
          <br />
          {100 - lvl.xpInLevel} XP to level {lvl.level + 1}
        </div>
      </div>
      <div className="mini-track" style={{ marginTop: 14 }}>
        <i style={{ width: `${lvl.xpInLevel}%`, background: "var(--xp-gold)" }} />
      </div>
    </div>
  );
}
