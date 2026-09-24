"use client";

import { useEffect, useState } from "react";
import { X } from "lucide-react";
import { useStore } from "@/lib/client/store";
import { useToast } from "@/lib/client/toast";
import { api } from "@/lib/client/api";
import { timeToMinutes } from "@/lib/shared/logic";
import type { Eisenhower, TaskDTO } from "@/lib/shared/types";

interface DraftSub {
  id: string | null; // null = not saved yet
  key: string;
  title: string;
  completed: boolean;
}

const EIS: { value: Eisenhower; label: string; cls: string }[] = [
  { value: "do-first", label: "Do First", cls: "" },
  { value: "schedule", label: "Schedule", cls: "sched" },
  { value: "delegate", label: "Delegate", cls: "del" },
  { value: "eliminate", label: "Eliminate", cls: "elim" },
];

function nowMinutes() {
  const n = new Date();
  return n.getHours() * 60 + n.getMinutes();
}

function currentTimeStr() {
  const n = new Date();
  return `${String(n.getHours()).padStart(2, "0")}:${String(n.getMinutes()).padStart(2, "0")}`;
}

/** Wrapper: mounts a fresh editor each time it opens. */
export default function TaskEditor() {
  const { editingTaskId, data } = useStore();
  if (editingTaskId === undefined) return null;
  const task = editingTaskId ? (data.tasks.find((t) => t.id === editingTaskId) ?? null) : null;
  return <EditorModal key={editingTaskId ?? "new"} task={task} />;
}

function EditorModal({ task: t }: { task: TaskDTO | null }) {
  const store = useStore();
  const { data, today, ui, closeTaskEditor, createTask, updateTask, deleteTask, refresh } = store;
  const toast = useToast();

  const [title, setTitle] = useState(t?.title ?? "");
  const [goalId, setGoalId] = useState(t ? (t.goalId ?? "") : (ui.activeGoalId ?? ""));
  const [description, setDescription] = useState(t?.description ?? "");
  const [dueDate, setDueDate] = useState(t?.dueDate ?? (ui.selectedDate || today));
  const [startTime, setStartTime] = useState(t?.startTime ?? "");
  const [endTime, setEndTime] = useState(t?.endTime ?? "");
  const [eisenhower, setEisenhower] = useState<Eisenhower | null>(t?.eisenhower ?? null);
  const [isPriority, setIsPriority] = useState(t?.isPriority ?? false);
  const [addToToday, setAddToToday] = useState(t ? t.dueDate === today : false);
  const [subs, setSubs] = useState<DraftSub[]>(
    (t?.subtasks ?? []).map((s) => ({ id: s.id, key: s.id, title: s.title, completed: s.completed })),
  );
  const [newSub, setNewSub] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && closeTaskEditor();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [closeTaskEditor]);

  const addSub = () => {
    if (!newSub.trim()) return;
    setSubs((s) => [...s, { id: null, key: crypto.randomUUID(), title: newSub.trim(), completed: false }]);
    setNewSub("");
  };

  const save = async () => {
    const cleanTitle = title.trim();
    if (!cleanTitle) return toast("Title is required", "error");
    const due = addToToday ? today : dueDate;
    const start = startTime || null;
    const scheduleChanged = !t || due !== t.dueDate || start !== t.startTime;
    if (scheduleChanged && due < today) return toast("Cannot schedule tasks in the past", "error");
    if (scheduleChanged && start && due === today && (timeToMinutes(start) ?? 0) <= nowMinutes()) {
      return toast("Cannot set a start time in the past for today", "error");
    }

    setSaving(true);
    const fields = {
      title: cleanTitle,
      goalId: goalId || null,
      description,
      dueDate: due,
      startTime: start,
      endTime: endTime || null,
      eisenhower,
      isPriority,
    };

    if (!t) {
      const created = await createTask({ ...fields, subtasks: subs.map((s) => ({ title: s.title })) });
      setSaving(false);
      if (created) closeTaskEditor();
      return;
    }

    const updated = await updateTask(t.id, fields);
    if (!updated) return setSaving(false);

    // Sync subtask edits made in the modal.
    try {
      const keep = new Set(subs.filter((s) => s.id).map((s) => s.id));
      const ops: Promise<unknown>[] = [];
      for (const s of t.subtasks) {
        if (!keep.has(s.id)) ops.push(api(`/api/tasks/${t.id}/subtasks/${s.id}`, { method: "DELETE" }));
      }
      for (const s of subs) {
        const orig = t.subtasks.find((o) => o.id === s.id);
        if (orig && orig.title !== s.title && s.title.trim()) {
          ops.push(api(`/api/tasks/${t.id}/subtasks/${s.id}`, { method: "PATCH", body: { title: s.title.trim() } }));
        }
      }
      await Promise.all(ops);
      for (const s of subs.filter((x) => !x.id)) {
        await api(`/api/tasks/${t.id}/subtasks`, { method: "POST", body: { title: s.title } });
      }
      if (ops.length || subs.some((s) => !s.id)) await refresh();
    } catch {
      toast("Some subtask changes could not be saved", "error");
    }
    setSaving(false);
    closeTaskEditor();
  };

  const remove = async () => {
    if (!t) return;
    if (await deleteTask(t.id)) closeTaskEditor();
  };

  const subInputStyle = {
    flex: 1,
    padding: "6px 10px",
    borderRadius: "var(--radius-xs)",
    border: "1px solid var(--border)",
    background: "var(--bg-surface2)",
    color: "var(--text)",
    fontSize: 13,
  } as const;

  return (
    <div
      className="modal-overlay active"
      id="task-modal-overlay"
      onMouseDown={(e) => e.target === e.currentTarget && closeTaskEditor()}
    >
      <div className="modal" id="task-modal" role="dialog" aria-modal="true">
        <h3>{t ? "Edit Task" : "New Task"}</h3>
        <div className="form-group">
          <label>Title</label>
          <input
            type="text"
            autoFocus
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && save()}
          />
        </div>
        <div className="form-group">
          <label>Associated Goal</label>
          <select value={goalId} onChange={(e) => setGoalId(e.target.value)}>
            <option value="">— Standalone Task —</option>
            {data.goals.map((g) => (
              <option key={g.id} value={g.id}>
                🎯 {g.title}
              </option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label>Description</label>
          <textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} />
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>Due Date</label>
            <input type="date" value={dueDate} min={today} onChange={(e) => setDueDate(e.target.value)} />
          </div>
        </div>
        <div className="form-row">
          <div className="form-group">
            <label>Start Time</label>
            <input
              type="time"
              value={startTime}
              min={(addToToday ? today : dueDate) === today ? currentTimeStr() : undefined}
              onChange={(e) => setStartTime(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>End Time</label>
            <input type="time" value={endTime} onChange={(e) => setEndTime(e.target.value)} />
          </div>
        </div>
        <div className="form-group">
          <label>Eisenhower Priority</label>
          <div className="eisenhower-selector">
            {EIS.map((o) => (
              <button
                key={o.value}
                type="button"
                className={`eisenhower-option${eisenhower === o.value ? ` selected ${o.cls}` : ""}`}
                onClick={() => setEisenhower((cur) => (cur === o.value ? null : o.value))}
              >
                {o.label}
              </button>
            ))}
          </div>
        </div>
        <div className="form-group" style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
          <input
            type="checkbox"
            id="edit-frog"
            checked={isPriority}
            onChange={(e) => setIsPriority(e.target.checked)}
            style={{ width: 18, height: 18, accentColor: "var(--frog)" }}
          />
          <label htmlFor="edit-frog" style={{ textTransform: "none", letterSpacing: 0, fontSize: 14 }}>
            Mark as priority task (+50 XP)
          </label>
        </div>
        <div className="form-group" style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
          <input
            type="checkbox"
            id="edit-today"
            checked={addToToday}
            onChange={(e) => setAddToToday(e.target.checked)}
            style={{ width: 18, height: 18, accentColor: "var(--primary)" }}
          />
          <label htmlFor="edit-today" style={{ textTransform: "none", letterSpacing: 0, fontSize: 14 }}>
            Add to Today&apos;s list
          </label>
        </div>
        <div className="form-group">
          <label>Subtasks</label>
          {subs.map((s) => (
            <div key={s.key} style={{ display: "flex", gap: 6, alignItems: "center", marginBottom: 4 }}>
              <input
                type="text"
                value={s.title}
                style={subInputStyle}
                onChange={(e) =>
                  setSubs((all) => all.map((x) => (x.key === s.key ? { ...x, title: e.target.value } : x)))
                }
              />
              <button className="btn-icon" onClick={() => setSubs((all) => all.filter((x) => x.key !== s.key))}>
                <X />
              </button>
            </div>
          ))}
          <div style={{ display: "flex", gap: 6 }}>
            <input
              type="text"
              placeholder="Add subtask..."
              value={newSub}
              style={subInputStyle}
              onChange={(e) => setNewSub(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && addSub()}
            />
            <button className="btn btn-sm btn-secondary" onClick={addSub}>
              +
            </button>
          </div>
        </div>
        <div className="modal-actions">
          <button className="btn btn-secondary" onClick={closeTaskEditor}>
            Cancel
          </button>
          {t && (
            <button className="btn btn-danger" onClick={remove}>
              Delete
            </button>
          )}
          <button className="btn btn-primary" onClick={save} disabled={saving}>
            {t ? "Save Changes" : "Create Task"}
          </button>
        </div>
      </div>
    </div>
  );
}
