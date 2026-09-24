"use client";

import { useState } from "react";
import { CalendarPlus, ChevronLeft, ChevronRight, Lock, Plus, Zap } from "lucide-react";
import TaskCard from "@/components/TaskCard";
import { tasksForDate, useStore } from "@/lib/client/store";
import { useToast } from "@/lib/client/toast";
import { fmtDate, fmtDateShort, timeToMinutes, toDateStr } from "@/lib/shared/logic";
import type { TaskDTO } from "@/lib/shared/types";

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];
const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export default function CalendarPage() {
  const { data, today, ui, setUi } = useStore();
  const cm = ui.calendarMonth;
  const cy = ui.calendarYear;
  const selected = ui.selectedDate || today;

  let selectedTasks = tasksForDate(data.tasks, selected);
  if (ui.searchQuery) {
    const q = ui.searchQuery.toLowerCase();
    selectedTasks = selectedTasks.filter((t) => t.title.toLowerCase().includes(q));
  }
  const active = selectedTasks.filter((t) => !t.completed);
  const completed = selectedTasks.filter((t) => t.completed);
  const done = completed.length;
  const total = selectedTasks.length;
  const rate = total ? Math.round((done / total) * 100) : 0;

  const selectDate = (ds: string) => {
    const d = new Date(ds + "T00:00:00");
    setUi({ selectedDate: ds, calendarMonth: d.getMonth(), calendarYear: d.getFullYear() });
  };
  const navMonth = (dir: number) => {
    let m = cm + dir;
    let y = cy;
    if (m < 0) {
      m = 11;
      y--;
    }
    if (m > 11) {
      m = 0;
      y++;
    }
    setUi({ calendarMonth: m, calendarYear: y });
  };

  // Month grid: leading days of the previous month, the month, trailing days to 42 cells.
  const firstDay = new Date(cy, cm, 1).getDay();
  const daysInMonth = new Date(cy, cm + 1, 0).getDate();
  const prevMonthDays = new Date(cy, cm, 0).getDate();
  const cells: { day: number; date: string; other: boolean }[] = [];
  for (let i = firstDay - 1; i >= 0; i--) {
    const day = prevMonthDays - i;
    cells.push({ day, date: toDateStr(new Date(cy, cm - 1, day)), other: true });
  }
  for (let d = 1; d <= daysInMonth; d++) cells.push({ day: d, date: toDateStr(new Date(cy, cm, d)), other: false });
  for (let next = 1; cells.length < 42; next++) {
    cells.push({ day: next, date: toDateStr(new Date(cy, cm + 1, next)), other: true });
  }

  return (
    <section className="calendar-page">
      <div className="calendar-first">
        <div className="calendar-page-head">
          <div>
            <div className="daily-label">Calendar</div>
            <h1>
              {MONTHS[cm]} {cy}
            </h1>
          </div>
          <div className="calendar-actions">
            <button className="btn btn-secondary" onClick={() => navMonth(-1)} title="Previous month">
              <ChevronLeft />
            </button>
            <button className="btn btn-secondary" onClick={() => selectDate(today)}>
              Today
            </button>
            <button className="btn btn-secondary" onClick={() => navMonth(1)} title="Next month">
              <ChevronRight />
            </button>
          </div>
        </div>
        <div className="calendar-grid simple-calendar-grid">
          {DAY_NAMES.map((n) => (
            <div className="day-header" key={n}>
              {n}
            </div>
          ))}
          {cells.map((c) => (
            <DayCell
              key={c.date + (c.other ? "o" : "")}
              day={c.day}
              date={c.date}
              other={c.other}
              tasks={tasksForDate(data.tasks, c.date)}
              today={today}
              selected={selected}
              onSelect={selectDate}
            />
          ))}
        </div>
      </div>

      <aside className="selected-day-panel">
        <div className="selected-day-head">
          <div>
            <div className="daily-label">Selected date</div>
            <h2>{fmtDate(selected)}</h2>
          </div>
          <div className="daily-score small">
            <strong>
              {done}/{total}
            </strong>
            <span>done</span>
          </div>
        </div>
        <div className="daily-progress">
          <div style={{ width: `${rate}%` }} />
        </div>
        {selected < today ? (
          <div className="calendar-note">
            <Lock />
            <span>Past dates are read-only. Pick today or a future date to add tasks.</span>
          </div>
        ) : (
          <DayComposer date={selected} key={selected} />
        )}
        <div className="section-title">
          <span>Tasks</span>
          <h2>{active.length} active</h2>
        </div>
        {active.length ? (
          <div className="task-list">
            {active.map((t) => (
              <TaskCard key={t.id} task={t} />
            ))}
          </div>
        ) : (
          <div className="empty-state compact-empty">
            <CalendarPlus />
            <h3>{total === 0 ? "Nothing planned" : "All clear"}</h3>
            <p>{total === 0 ? "Add one task above for this date." : "Every task for this date is completed."}</p>
          </div>
        )}
        {completed.length > 0 && (
          <>
            <div className="section-title completed-title">
              <span>Done</span>
              <h2>{completed.length} completed</h2>
            </div>
            <div className="task-list">
              {completed.map((t) => (
                <TaskCard key={t.id} task={t} />
              ))}
            </div>
          </>
        )}
      </aside>
    </section>
  );
}

function DayCell(props: {
  day: number;
  date: string;
  other: boolean;
  tasks: TaskDTO[];
  today: string;
  selected: string;
  onSelect: (d: string) => void;
}) {
  const { day, date, other, tasks, today, selected, onSelect } = props;
  const done = tasks.filter((t) => t.completed).length;
  const priority = tasks.some((t) => t.isPriority && !t.completed);
  const cls = ["day-cell"];
  if (other) cls.push("other-month");
  if (date === today) cls.push("today");
  if (date === selected) cls.push("selected");
  if (date < today && !other) cls.push("past-day");

  return (
    <button className={cls.join(" ")} onClick={() => onSelect(date)}>
      <span className="day-num">{day}</span>
      {tasks.length > 0 && <span className="day-count">{tasks.length}</span>}
      {priority && (
        <span className="priority-corner">
          <Zap />
        </span>
      )}
      <span className="day-dots">
        {tasks.slice(0, 4).map((t) => (
          <span key={t.id} className={`day-dot ${t.completed ? "completed" : t.isPriority ? "frog" : "normal"}`} />
        ))}
      </span>
      {tasks.length > 0 && (
        <span className="day-summary">
          {done}/{tasks.length}
        </span>
      )}
    </button>
  );
}

function DayComposer({ date }: { date: string }) {
  const { data, today, createTask } = useStore();
  const toast = useToast();
  const [title, setTitle] = useState("");
  const [goalId, setGoalId] = useState("");
  const [time, setTime] = useState("");
  const [priority, setPriority] = useState(false);
  const [busy, setBusy] = useState(false);

  const add = async () => {
    if (!title.trim() || busy) return;
    if (date < today) return toast("Cannot add tasks to past dates", "error");
    if (time && date === today) {
      const now = new Date();
      if ((timeToMinutes(time) ?? 0) <= now.getHours() * 60 + now.getMinutes()) {
        return toast("Cannot schedule a past time for today", "error");
      }
    }
    setBusy(true);
    const created = await createTask({
      title: title.trim(),
      goalId: goalId || null,
      dueDate: date,
      startTime: time || null,
      isPriority: priority,
    });
    setBusy(false);
    if (created) {
      setTitle("");
      setPriority(false);
      toast(`Task added for ${fmtDateShort(date)}`, "success");
    }
  };

  return (
    <div className="calendar-composer">
      <input
        type="text"
        placeholder={`Add a task for ${fmtDateShort(date)}...`}
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && add()}
      />
      <div className="calendar-composer-options">
        <select value={goalId} onChange={(e) => setGoalId(e.target.value)}>
          <option value="">No goal</option>
          {data.goals.map((g) => (
            <option key={g.id} value={g.id}>
              {g.title}
            </option>
          ))}
        </select>
        <input type="time" value={time} onChange={(e) => setTime(e.target.value)} />
        <label>
          <input type="checkbox" checked={priority} onChange={(e) => setPriority(e.target.checked)} /> Priority
        </label>
        <button className="btn btn-primary" onClick={add} disabled={busy}>
          <Plus /> Add
        </button>
      </div>
    </div>
  );
}
