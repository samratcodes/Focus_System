"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { api, ApiClientError } from "./api";
import { useNow } from "./clock";
import { useToast } from "./toast";
import { useDialogs } from "./dialogs";
import { GOAL_COLORS, toDateStr } from "@/lib/shared/logic";
import type {
  BootstrapDTO,
  FocusDTO,
  GoalDTO,
  TaskDTO,
  UserDTO,
  UserSettings,
  XpEvent,
} from "@/lib/shared/types";

export type AnalyticsPeriod = "day" | "week" | "month";
export type FocusActionName = "start" | "pause" | "reset" | "skip";
export type FocusMode = "work" | "shortBreak" | "longBreak";

export interface UIState {
  searchQuery: string;
  activeGoalId: string | null;
  selectedDate: string;
  calendarMonth: number;
  calendarYear: number;
  analyticsPeriod: AnalyticsPeriod;
}

export interface NewTaskInput {
  title: string;
  description?: string;
  goalId?: string | null;
  dueDate: string;
  startTime?: string | null;
  endTime?: string | null;
  eisenhower?: TaskDTO["eisenhower"];
  isPriority?: boolean;
  subtasks?: { title: string; completed?: boolean }[];
}
export type TaskPatch = Partial<
  Pick<TaskDTO, "title" | "description" | "goalId" | "dueDate" | "startTime" | "endTime" | "eisenhower" | "isPriority" | "completed">
>;

interface Store {
  data: BootstrapDTO;
  today: string;
  online: boolean;
  /** Estimated server clock minus local clock, in ms. */
  serverOffset: number;
  ui: UIState;
  setUi: (patch: Partial<UIState>) => void;
  refresh: () => Promise<void>;

  createTask: (input: NewTaskInput) => Promise<TaskDTO | null>;
  updateTask: (id: string, patch: TaskPatch) => Promise<TaskDTO | null>;
  toggleComplete: (id: string) => void;
  toggleFrog: (id: string) => void;
  clearFrog: () => void;
  deleteTask: (id: string, skipConfirm?: boolean) => Promise<boolean>;
  addSubtask: (taskId: string, title: string) => Promise<TaskDTO | null>;
  updateSubtask: (taskId: string, subId: string, patch: { title?: string; completed?: boolean }) => Promise<void>;
  deleteSubtask: (taskId: string, subId: string) => Promise<void>;

  createGoal: () => Promise<void>;
  editGoal: (id: string) => Promise<void>;
  deleteGoal: (id: string) => Promise<void>;

  focusAction: (action: FocusActionName) => Promise<FocusDTO | null>;
  setFocusMode: (mode: FocusMode) => Promise<void>;
  attachTask: (taskId: string | null) => Promise<void>;
  applyFocus: (focus: FocusDTO, serverTime?: number) => void;
  handleEvents: (events: XpEvent[] | undefined) => void;
  updateSettings: (patch: Partial<UserSettings>) => Promise<boolean>;
  setUser: (user: UserDTO) => void;

  editingTaskId: string | null | undefined; // undefined = closed, null = new task
  openTaskEditor: (id: string | null) => void;
  closeTaskEditor: () => void;
  overlayOpen: boolean;
  setOverlayOpen: (open: boolean) => void;
  musicPlaying: boolean;
  setMusicPlaying: (playing: boolean) => void;
}

const StoreContext = createContext<Store | null>(null);

export function useStore() {
  const s = useContext(StoreContext);
  if (!s) throw new Error("useStore must be used inside <StoreProvider>");
  return s;
}

const SYNC_INTERVAL_MS = 30_000;

export function StoreProvider({ initial, children }: { initial: BootstrapDTO; children: ReactNode }) {
  const toast = useToast();
  const { confirm, goalDialog } = useDialogs();
  const [data, setData] = useState<BootstrapDTO>(initial);
  const [serverOffset, setServerOffset] = useState(() => initial.serverTime - Date.now());
  // Server-computed date (user time zone) until hydrated, then the device clock.
  const nowMinute = useNow(60_000);
  const today = nowMinute === null ? initial.today : toDateStr(new Date(nowMinute));
  const [online, setOnline] = useState(true);
  const [ui, setUiState] = useState<UIState>(() => {
    const [y, m] = initial.today.split("-").map(Number);
    return {
      searchQuery: "",
      activeGoalId: null,
      selectedDate: initial.today,
      calendarMonth: m - 1,
      calendarYear: y,
      analyticsPeriod: "week",
    };
  });
  const [editingTaskId, setEditingTaskId] = useState<string | null | undefined>(undefined);
  const [overlayOpen, setOverlayOpen] = useState(false);
  const [musicPlaying, setMusicPlaying] = useState(false);
  const refreshing = useRef(false);

  const setUi = useCallback((patch: Partial<UIState>) => setUiState((u) => ({ ...u, ...patch })), []);

  const handleEvents = useCallback(
    (events: XpEvent[] | undefined) => {
      if (!events?.length) return;
      for (const e of events) {
        if (e.leveledUp) toast(`🎉 LEVEL UP! You reached Level ${e.level}!`, "success");
        else if (e.amount > 0) toast(`+${e.amount} XP: ${e.reason}`, "success");
      }
      const last = events[events.length - 1];
      setData((d) => ({ ...d, user: { ...d.user, xp: last.total } }));
    },
    [toast],
  );

  const fail = useCallback(
    (err: unknown) => {
      const msg = err instanceof ApiClientError ? err.message : "Something went wrong";
      if (err instanceof ApiClientError && err.status === 0) setOnline(false);
      toast(msg, "error");
    },
    [toast],
  );

  const refresh = useCallback(async () => {
    if (refreshing.current) return;
    refreshing.current = true;
    try {
      const fresh = await api<BootstrapDTO>("/api/bootstrap");
      setData(fresh);
      setServerOffset(fresh.serverTime - Date.now());
      setOnline(true);
      handleEvents(fresh.events);
    } catch (err) {
      if (err instanceof ApiClientError && err.status === 0) setOnline(false);
    } finally {
      refreshing.current = false;
    }
  }, [handleEvents]);

  // Keep in sync with the mobile app / other tabs, and roll over at midnight.
  useEffect(() => {
    const onFocus = () => {
      if (!document.hidden) refresh();
    };
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onFocus);
    window.addEventListener("online", onFocus);
    const sync = setInterval(() => !document.hidden && refresh(), SYNC_INTERVAL_MS);
    return () => {
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onFocus);
      window.removeEventListener("online", onFocus);
      clearInterval(sync);
    };
  }, [refresh]);

  // ---------- local mutation helpers ----------
  const putTask = useCallback((task: TaskDTO) => {
    setData((d) => {
      const exists = d.tasks.some((t) => t.id === task.id);
      let tasks = exists ? d.tasks.map((t) => (t.id === task.id ? task : t)) : [...d.tasks, task];
      if (task.isPriority) tasks = tasks.map((t) => (t.id !== task.id && t.isPriority ? { ...t, isPriority: false } : t));
      return { ...d, tasks };
    });
  }, []);

  const patchLocalTask = useCallback((id: string, patch: Partial<TaskDTO>) => {
    setData((d) => ({ ...d, tasks: d.tasks.map((t) => (t.id === id ? { ...t, ...patch } : t)) }));
  }, []);

  // ---------- tasks ----------
  const createTask = useCallback(
    async (input: NewTaskInput) => {
      try {
        const { task } = await api<{ task: TaskDTO }>("/api/tasks", { method: "POST", body: input });
        putTask(task);
        setData((d) => (d.streakDays.includes(today) ? d : { ...d, streakDays: [...d.streakDays, today] }));
        return task;
      } catch (err) {
        fail(err);
        return null;
      }
    },
    [putTask, fail, today],
  );

  const updateTask = useCallback(
    async (id: string, patch: TaskPatch) => {
      try {
        const res = await api<{ task: TaskDTO; events: XpEvent[] }>(`/api/tasks/${id}`, {
          method: "PATCH",
          body: patch,
        });
        putTask(res.task);
        handleEvents(res.events);
        return res.task;
      } catch (err) {
        fail(err);
        refresh();
        return null;
      }
    },
    [putTask, handleEvents, fail, refresh],
  );

  const toggleComplete = useCallback(
    (id: string) => {
      const t = data.tasks.find((x) => x.id === id);
      if (!t) return;
      const completed = !t.completed;
      patchLocalTask(id, { completed, isPriority: completed ? false : t.isPriority });
      updateTask(id, { completed });
    },
    [data.tasks, patchLocalTask, updateTask],
  );

  const toggleFrog = useCallback(
    (id: string) => {
      const t = data.tasks.find((x) => x.id === id);
      if (!t) return;
      const isPriority = !t.isPriority;
      setData((d) => ({
        ...d,
        tasks: d.tasks.map((x) =>
          x.id === id ? { ...x, isPriority } : isPriority && x.isPriority ? { ...x, isPriority: false } : x,
        ),
      }));
      updateTask(id, { isPriority });
    },
    [data.tasks, updateTask],
  );

  const clearFrog = useCallback(() => {
    const flagged = data.tasks.filter((t) => t.isPriority);
    setData((d) => ({ ...d, tasks: d.tasks.map((t) => (t.isPriority ? { ...t, isPriority: false } : t)) }));
    flagged.forEach((t) => updateTask(t.id, { isPriority: false }));
  }, [data.tasks, updateTask]);

  const deleteTask = useCallback(
    async (id: string, skipConfirm = false) => {
      if (!skipConfirm && !(await confirm({ title: "Delete this task?", confirmLabel: "Delete", danger: true }))) {
        return false;
      }
      const before = data.tasks;
      setData((d) => ({ ...d, tasks: d.tasks.filter((t) => t.id !== id) }));
      try {
        await api(`/api/tasks/${id}`, { method: "DELETE" });
        return true;
      } catch (err) {
        setData((d) => ({ ...d, tasks: before }));
        fail(err);
        return false;
      }
    },
    [confirm, data.tasks, fail],
  );

  const addSubtask = useCallback(
    async (taskId: string, title: string) => {
      if (!title.trim()) return null;
      try {
        const { task } = await api<{ task: TaskDTO }>(`/api/tasks/${taskId}/subtasks`, {
          method: "POST",
          body: { title },
        });
        putTask(task);
        return task;
      } catch (err) {
        fail(err);
        return null;
      }
    },
    [putTask, fail],
  );

  const updateSubtask = useCallback(
    async (taskId: string, subId: string, patch: { title?: string; completed?: boolean }) => {
      setData((d) => ({
        ...d,
        tasks: d.tasks.map((t) =>
          t.id === taskId ? { ...t, subtasks: t.subtasks.map((s) => (s.id === subId ? { ...s, ...patch } : s)) } : t,
        ),
      }));
      try {
        const res = await api<{ task: TaskDTO; events: XpEvent[] }>(`/api/tasks/${taskId}/subtasks/${subId}`, {
          method: "PATCH",
          body: patch,
        });
        putTask(res.task);
        handleEvents(res.events);
      } catch (err) {
        fail(err);
        refresh();
      }
    },
    [putTask, handleEvents, fail, refresh],
  );

  const deleteSubtask = useCallback(
    async (taskId: string, subId: string) => {
      setData((d) => ({
        ...d,
        tasks: d.tasks.map((t) => (t.id === taskId ? { ...t, subtasks: t.subtasks.filter((s) => s.id !== subId) } : t)),
      }));
      try {
        const { task } = await api<{ task: TaskDTO }>(`/api/tasks/${taskId}/subtasks/${subId}`, { method: "DELETE" });
        putTask(task);
      } catch (err) {
        fail(err);
        refresh();
      }
    },
    [putTask, fail, refresh],
  );

  // ---------- goals ----------
  const createGoal = useCallback(async () => {
    const res = await goalDialog({
      title: "New goal",
      submitLabel: "Create goal",
      initialColor: GOAL_COLORS[Math.floor(Math.random() * GOAL_COLORS.length)],
    });
    if (!res) return;
    try {
      const { goal } = await api<{ goal: GoalDTO }>("/api/goals", {
        method: "POST",
        body: { title: res.name, color: res.color },
      });
      setData((d) => ({ ...d, goals: [...d.goals, goal] }));
      toast("New Goal created!", "success");
    } catch (err) {
      fail(err);
    }
  }, [goalDialog, toast, fail]);

  const editGoal = useCallback(
    async (id: string) => {
      const g = data.goals.find((x) => x.id === id);
      if (!g) return;
      const res = await goalDialog({ title: "Edit goal", initialName: g.title, initialColor: g.color });
      if (!res) return;
      try {
        const { goal } = await api<{ goal: GoalDTO }>(`/api/goals/${id}`, {
          method: "PATCH",
          body: { title: res.name, color: res.color },
        });
        setData((d) => ({ ...d, goals: d.goals.map((x) => (x.id === id ? goal : x)) }));
        toast("Goal updated", "success");
      } catch (err) {
        fail(err);
      }
    },
    [data.goals, goalDialog, toast, fail],
  );

  const deleteGoal = useCallback(
    async (id: string) => {
      const g = data.goals.find((x) => x.id === id);
      if (!g) return;
      const ok = await confirm({
        title: `Delete "${g.title}"?`,
        message: "Tasks in this goal will become uncategorized.",
        confirmLabel: "Delete goal",
        danger: true,
      });
      if (!ok) return;
      try {
        await api(`/api/goals/${id}`, { method: "DELETE" });
        setData((d) => ({
          ...d,
          goals: d.goals.filter((x) => x.id !== id),
          tasks: d.tasks.map((t) => (t.goalId === id ? { ...t, goalId: null } : t)),
        }));
        setUiState((u) => (u.activeGoalId === id ? { ...u, activeGoalId: null } : u));
      } catch (err) {
        fail(err);
      }
    },
    [data.goals, confirm, fail],
  );

  // ---------- focus ----------
  const applyFocus = useCallback((focus: FocusDTO, serverTime?: number) => {
    setData((d) => ({ ...d, focus }));
    if (serverTime) setServerOffset(serverTime - Date.now());
  }, []);

  const focusAction = useCallback(
    async (action: FocusActionName) => {
      try {
        const res = await api<{ focus: FocusDTO; events: XpEvent[]; serverTime: number }>("/api/focus", {
          method: "POST",
          body: { action },
        });
        applyFocus(res.focus, res.serverTime);
        handleEvents(res.events);
        return res.focus;
      } catch (err) {
        fail(err);
        return null;
      }
    },
    [applyFocus, handleEvents, fail],
  );

  const setFocusMode = useCallback(
    async (mode: FocusMode) => {
      try {
        const res = await api<{ focus: FocusDTO; serverTime: number }>("/api/focus", {
          method: "POST",
          body: { action: "mode", mode },
        });
        applyFocus(res.focus, res.serverTime);
      } catch (err) {
        fail(err);
      }
    },
    [applyFocus, fail],
  );

  const attachTask = useCallback(
    async (taskId: string | null) => {
      setData((d) => ({ ...d, focus: { ...d.focus, attachedTaskId: taskId } }));
      try {
        const res = await api<{ focus: FocusDTO; serverTime: number }>("/api/focus", {
          method: "POST",
          body: { action: "attach", taskId },
        });
        applyFocus(res.focus, res.serverTime);
      } catch (err) {
        fail(err);
      }
    },
    [applyFocus, fail],
  );

  const updateSettings = useCallback(
    async (patch: Partial<UserSettings>) => {
      try {
        const res = await api<{ user: UserDTO; focus: FocusDTO }>("/api/settings", { method: "PATCH", body: patch });
        setData((d) => ({ ...d, user: res.user, focus: res.focus }));
        return true;
      } catch (err) {
        fail(err);
        return false;
      }
    },
    [fail],
  );

  const setUser = useCallback((user: UserDTO) => setData((d) => ({ ...d, user })), []);

  const value = useMemo<Store>(
    () => ({
      data,
      today,
      online,
      serverOffset,
      ui,
      setUi,
      refresh,
      createTask,
      updateTask,
      toggleComplete,
      toggleFrog,
      clearFrog,
      deleteTask,
      addSubtask,
      updateSubtask,
      deleteSubtask,
      createGoal,
      editGoal,
      deleteGoal,
      focusAction,
      setFocusMode,
      attachTask,
      applyFocus,
      handleEvents,
      updateSettings,
      setUser,
      editingTaskId,
      openTaskEditor: setEditingTaskId,
      closeTaskEditor: () => setEditingTaskId(undefined),
      overlayOpen,
      setOverlayOpen,
      musicPlaying,
      setMusicPlaying,
    }),
    [
      data, today, online, serverOffset, ui, setUi, refresh, createTask, updateTask, toggleComplete, toggleFrog,
      clearFrog, deleteTask, addSubtask, updateSubtask, deleteSubtask, createGoal, editGoal, deleteGoal,
      focusAction, setFocusMode, attachTask, applyFocus, handleEvents, updateSettings, setUser, editingTaskId, overlayOpen,
      musicPlaying,
    ],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

// ---------- selectors (ported from shared.js) ----------
export function tasksForDate(tasks: TaskDTO[], date: string) {
  return tasks.filter((t) => t.dueDate === date);
}

export function completionRate(tasks: TaskDTO[], date: string) {
  const list = tasksForDate(tasks, date);
  if (!list.length) return 0;
  return Math.round((list.filter((t) => t.completed).length / list.length) * 100);
}

export function todayTasks(tasks: TaskDTO[], today: string, activeGoalId: string | null) {
  let list = tasksForDate(tasks, today);
  if (activeGoalId) list = list.filter((t) => t.goalId === activeGoalId);
  return list;
}

export function frogTask(tasks: TaskDTO[], today: string) {
  return tasks.find((t) => t.isPriority && !t.completed && t.dueDate === today);
}
