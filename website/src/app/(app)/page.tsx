"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Check, ClipboardList, Pencil, Plus, Trash2 } from "lucide-react";
import TaskCard from "@/components/TaskCard";
import LegacyImportBanner from "@/components/LegacyImportBanner";
import { frogTask, tasksForDate, todayTasks, useStore } from "@/lib/client/store";
import { useToast } from "@/lib/client/toast";
import { fmtDate, shiftDate, timeToMinutes } from "@/lib/shared/logic";

export default function TodayPage() {
  const store = useStore();
  const { data, today, ui, setUi, createGoal, editGoal, deleteGoal, toggleComplete } = store;
  const router = useRouter();
  const toast = useToast();

  const [title, setTitle] = useState("");
  const [goalId, setGoalId] = useState<string>(ui.activeGoalId ?? "");
  const [time, setTime] = useState("");
  const [date, setDate] = useState(ui.selectedDate < today ? today : ui.selectedDate || today);
  const [priority, setPriority] = useState(false);
  const [adding, setAdding] = useState(false);

  let tasks = todayTasks(data.tasks, today, ui.activeGoalId);
  if (ui.searchQuery) {
    const q = ui.searchQuery.toLowerCase();
    tasks = tasks.filter((t) => t.title.toLowerCase().includes(q));
  }
  const openTasks = tasks.filter((t) => !t.completed);
  const doneTasks = tasks.filter((t) => t.completed);
  const allToday = tasksForDate(data.tasks, today);
  const done = allToday.filter((t) => t.completed).length;
  const total = allToday.length;
  const rate = total ? Math.round((done / total) * 100) : 0;
  const frog = frogTask(data.tasks, today);

  const quickAdd = async () => {
    if (!title.trim() || adding) return;
    const dueDate = date || today;
    if (dueDate < today) return toast("Cannot schedule tasks in the past", "error");
    if (time && dueDate === today) {
      const now = new Date();
      if ((timeToMinutes(time) ?? 0) <= now.getHours() * 60 + now.getMinutes()) {
        return toast("Cannot schedule a past time for today", "error");
      }
    }
    setAdding(true);
    const created = await store.createTask({
      title: title.trim(),
      goalId: goalId || null,
      dueDate,
      startTime: time || null,
      isPriority: priority,
    });
    setAdding(false);
    if (created) {
      setTitle("");
      setPriority(false);
      toast("Task added", "success");
    }
  };

  return (
    <>
      <LegacyImportBanner />

      <section className="daily-board">
        <div className="daily-hero">
          <div>
            <div className="daily-label">{fmtDate(today)}</div>
            <h1>Plan today. Do one thing at a time.</h1>
          </div>
          <div className="daily-score">
            <strong>
              {done}/{total}
            </strong>
            <span>done</span>
          </div>
        </div>
        <div className="daily-progress">
          <div style={{ width: `${rate}%` }} />
        </div>
      </section>

      <section className="week-strip">
        {Array.from({ length: 7 }, (_, i) => {
          const ds = shiftDate(today, i);
          const d = new Date(ds + "T00:00:00");
          const list = tasksForDate(data.tasks, ds);
          const dayDone = list.filter((t) => t.completed).length;
          const dayRate = list.length ? Math.round((dayDone / list.length) * 100) : 0;
          return (
            <button
              key={ds}
              className={`week-day ${ds === today ? "today" : ""}`}
              onClick={() => {
                setUi({ selectedDate: ds, calendarMonth: d.getMonth(), calendarYear: d.getFullYear() });
                router.push("/calendar");
              }}
            >
              <span>{d.toLocaleDateString("en-US", { weekday: "short" })}</span>
              <strong>{d.getDate()}</strong>
              <em>
                {dayDone}/{list.length}
              </em>
              <i style={{ height: `${Math.max(4, dayRate)}%` }} />
            </button>
          );
        })}
      </section>

      <section className="workflow-grid">
        <div className="workflow-panel priority-panel">
          <div className="panel-kicker">Step 1</div>
          <h2>Pick the main task</h2>
          {frog ? (
            <div className="priority-task">
              <div>
                <span>Priority</span>
                <strong>{frog.title}</strong>
              </div>
              <div className="priority-actions">
                <button className="btn btn-primary" onClick={() => toggleComplete(frog.id)}>
                  <Check /> Done
                </button>
                <button className="btn btn-secondary" onClick={store.clearFrog}>
                  Clear
                </button>
              </div>
            </div>
          ) : (
            <p className="panel-note">Choose one task with the bolt button. This keeps today clear and focused.</p>
          )}
        </div>
        <div className="workflow-panel add-panel">
          <div className="panel-kicker">Step 2</div>
          <h2>Add the next action</h2>
          <div className="quick-entry">
            <input
              type="text"
              placeholder="Write one clear action..."
              id="quick-add-input"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && quickAdd()}
            />
            <button className="btn btn-primary" onClick={quickAdd} disabled={adding}>
              <Plus /> Add
            </button>
          </div>
          <div className="quick-options">
            <select value={goalId} onChange={(e) => setGoalId(e.target.value)}>
              <option value="">No goal</option>
              {data.goals.map((g) => (
                <option key={g.id} value={g.id}>
                  {g.title}
                </option>
              ))}
            </select>
            <input type="time" title="Start time" value={time} onChange={(e) => setTime(e.target.value)} />
            <input
              type="date"
              value={date}
              min={today}
              onChange={(e) => {
                setDate(e.target.value);
                setUi({ selectedDate: e.target.value });
              }}
            />
            <label>
              <input type="checkbox" checked={priority} onChange={(e) => setPriority(e.target.checked)} /> Priority
            </label>
          </div>
        </div>
      </section>

      <section className="goal-section simple-goals">
        <div className="goal-section-header">
          <div className="sidebar-label" style={{ padding: 0 }}>
            View
          </div>
          <button className="btn btn-sm btn-secondary" onClick={createGoal}>
            <Plus /> Goal
          </button>
        </div>
        <div className="goal-pills">
          <button
            className={`goal-pill ${ui.activeGoalId === null ? "active" : ""}`}
            onClick={() => setUi({ activeGoalId: null })}
          >
            All
          </button>
          {data.goals.map((g) => {
            const sel = ui.activeGoalId === g.id;
            return (
              <span
                key={g.id}
                className={`goal-manage-pill ${sel ? "active" : ""}`}
                style={sel ? { background: `${g.color}22`, borderColor: g.color, color: g.color } : undefined}
              >
                <button
                  className="goal-name-btn"
                  onClick={() => {
                    setUi({ activeGoalId: g.id });
                    setGoalId(g.id);
                  }}
                >
                  <span className="goal-dot" style={{ background: g.color }} />
                  {g.title}
                </button>
                <button className="goal-mini-btn" onClick={() => editGoal(g.id)} title="Edit goal">
                  <Pencil />
                </button>
                <button className="goal-mini-btn" onClick={() => deleteGoal(g.id)} title="Delete goal">
                  <Trash2 />
                </button>
              </span>
            );
          })}
        </div>
      </section>

      <section className="task-section">
        <div className="section-title">
          <span>Step 3</span>
          <h2>Do these today</h2>
        </div>
        <div className="task-list" id="today-task-list">
          {openTasks.length === 0 ? (
            <div className="empty-state">
              <ClipboardList />
              <h3>{ui.searchQuery ? "No matching tasks" : "Your list is clear"}</h3>
              <p>{ui.searchQuery ? "Try a different search." : "Add one action above, or enjoy the clean slate."}</p>
            </div>
          ) : (
            openTasks.map((t) => <TaskCard key={t.id} task={t} />)
          )}
        </div>
      </section>

      {doneTasks.length > 0 && (
        <section className="task-section completed-section">
          <div className="section-title">
            <span>Done</span>
            <h2>Completed today</h2>
          </div>
          <div className="task-list">
            {doneTasks.map((t) => (
              <TaskCard key={t.id} task={t} />
            ))}
          </div>
        </section>
      )}
    </>
  );
}
