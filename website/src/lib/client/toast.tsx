"use client";

import { createContext, useCallback, useContext, useState, type ReactNode } from "react";

type ToastType = "" | "success" | "error" | "info";
interface Toast {
  id: number;
  msg: string;
  type: ToastType;
  leaving: boolean;
}

const ToastContext = createContext<(msg: string, type?: ToastType) => void>(() => {});

let nextId = 1;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const toast = useCallback((msg: string, type: ToastType = "") => {
    const id = nextId++;
    setToasts((t) => [...t, { id, msg, type, leaving: false }]);
    setTimeout(() => setToasts((t) => t.map((x) => (x.id === id ? { ...x, leaving: true } : x))), 2500);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 2800);
  }, []);

  return (
    <ToastContext.Provider value={toast}>
      {children}
      <div className="toast-container" aria-live="polite">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={`toast ${t.type}`}
            style={t.leaving ? { opacity: 0, transition: "opacity 0.3s" } : undefined}
          >
            {t.msg}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export const useToast = () => useContext(ToastContext);
