"use client";

import { useState } from "react";
import { Check, Clock, ListChecks, Pencil, Timer, Trash2, X, Zap } from "lucide-react";
import { useStore } from "@/lib/client/store";
import { EISENHOWER_LABELS } from "@/lib/shared/logic";
import type { TaskDTO } from "@/lib/shared/types";

export default function TaskCard({ task: t }: { task: TaskDTO }) {
  const { data, today, toggleComplete, toggleFrog, deleteTask, openTaskEditor, addSubtask, updateSubtask, deleteSubtask } =
    useStore();
  const [newSub, setNewSub] = useState("");

  const goal = t.goalId ? data.goals.find((g) => g.id === t.goalId) : null;
  const doneSubs = t.subtasks.filter((s) => s.completed).length;

  const submitSub = async () => {
    if (!newSub.trim()) return;
    const title = newSub;
    setNewSub("");
    await addSubtask(t.id, title);
  };

  return (
    <div className={`task-card ${t.completed ? "completed" : ""} ${t.isPriority && !t.completed ? "priority" : ""}`} data-task-id={t.id}>
      <div
        className={`task-check ${t.completed ? "done" : ""}`}
        role="checkbox"
        aria-checked={t.completed}
        tabIndex={0}
        onClick={() => toggleComplete(t.id)}
        onKeyDown={(e) => (e.key === " " || e.key === "Enter") && toggleComplete(t.id)}
      >
        {t.completed && <Check />}
      </div>
      <div className="task-body">
        <div className="task-title">{t.title}</div>
        <div className="task-meta">
          {goal && (
            <span
              className="badge"
              style={{ background: `${goal.color}22`, color: goal.color, border: `1px solid ${goal.color}44` }}
            >
              🎯 {goal.title}
            </span>
          )}
          {t.isPriority && <span className="badge badge-frog">Priority</span>}
          {t.dueDate === today && <span className="badge badge-today">Today</span>}
          {t.eisenhower && <span className={`badge badge-${t.eisenhower}`}>{EISENHOWER_LABELS[t.eisenhower]}</span>}
          {t.startTime && (
            <span className="task-time">
              <Clock /> {t.startTime}
              {t.endTime ? ` - ${t.endTime}` : ""}
            </span>
          )}
          {t.subtasks.length > 0 && (
            <span className="task-time">
              <ListChecks /> {doneSubs}/{t.subtasks.length}
            </span>
          )}
          {t.pomodoroCount > 0 && (
            <span className="task-time">
              <Timer /> {t.pomodoroCount}
            </span>
          )}
        </div>

        {t.subtasks.length > 0 && (
          <div className="subtasks">
            {t.subtasks.map((s) => (
              <div className="subtask-item" key={s.id}>
                <div
                  className={`subtask-check ${s.completed ? "done" : ""}`}
                  onClick={(e) => {
                    e.stopPropagation();
                    updateSubtask(t.id, s.id, { completed: !s.completed });
                  }}
                >
                  {s.completed && <Check style={{ width: 12, height: 12 }} />}
                </div>
                <span className={`subtask-title ${s.completed ? "done" : ""}`}>{s.title}</span>
                <button
                  className="btn-icon"
                  style={{ padding: 2 }}
                  onClick={(e) => {
                    e.stopPropagation();
                    deleteSubtask(t.id, s.id);
                  }}
                >
                  <X style={{ width: 12, height: 12 }} />
                </button>
              </div>
            ))}
            <div className="subtask-add">
              <input
                type="text"
                placeholder="Add subtask..."
                value={newSub}
                onChange={(e) => setNewSub(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && submitSub()}
              />
              <button className="btn btn-sm btn-secondary" onClick={submitSub}>
                +
              </button>
            </div>
          </div>
        )}
      </div>
      <div className="task-actions">
        <button className="btn-icon" onClick={() => openTaskEditor(t.id)} title="Edit">
          <Pencil />
        </button>
        <button
          className="btn-icon"
          onClick={() => toggleFrog(t.id)}
          title={t.isPriority ? "Unmark Frog" : "Eat the Frog"}
          style={{ color: t.isPriority ? "var(--frog)" : undefined }}
        >
          <Zap />
        </button>
        <button className="btn-icon" onClick={() => deleteTask(t.id)} title="Delete">
          <Trash2 />
        </button>
      </div>
    </div>
  );
}
