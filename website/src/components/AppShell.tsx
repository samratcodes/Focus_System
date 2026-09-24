"use client";

import { useEffect, type ReactNode } from "react";
import { usePathname } from "next/navigation";
import { ToastProvider } from "@/lib/client/toast";
import { DialogProvider } from "@/lib/client/dialogs";
import { StoreProvider, useStore } from "@/lib/client/store";
import { FocusTimerProvider } from "@/lib/client/timer";
import type { BootstrapDTO } from "@/lib/shared/types";
import Sidebar from "./Sidebar";
import Header from "./Header";
import TaskEditor from "./TaskEditor";
import FocusOverlay from "./FocusOverlay";

export default function AppShell({ initial, children }: { initial: BootstrapDTO; children: ReactNode }) {
  return (
    <ToastProvider>
      <DialogProvider>
        <StoreProvider initial={initial}>
          <FocusTimerProvider>
            <Shell initialEvents={initial.events}>{children}</Shell>
          </FocusTimerProvider>
        </StoreProvider>
      </DialogProvider>
    </ToastProvider>
  );
}

function Shell({ children, initialEvents }: { children: ReactNode; initialEvents: BootstrapDTO["events"] }) {
  const pathname = usePathname();
  const { handleEvents, overlayOpen, setOverlayOpen, editingTaskId, openTaskEditor } = useStore();

  // XP earned by a focus session that finished while no device was open.
  useEffect(() => {
    handleEvents(initialEvents);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Same shortcuts as the original: Esc, Ctrl+K (search), Ctrl+N (new task).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && overlayOpen) {
        setOverlayOpen(false);
        return;
      }
      if (e.ctrlKey && e.key.toLowerCase() === "k") {
        e.preventDefault();
        document.getElementById("search-input")?.focus();
      }
      if (e.ctrlKey && e.key.toLowerCase() === "n" && editingTaskId === undefined) {
        e.preventDefault();
        const quick = document.getElementById("quick-add-input");
        if (quick) quick.focus();
        else openTaskEditor(null);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [overlayOpen, setOverlayOpen, editingTaskId, openTaskEditor]);

  return (
    <>
      <div className="app">
        <Sidebar />
        <main className="main">
          <Header />
          <div className={`content ${pathname === "/calendar" ? "calendar-content" : ""}`} id="content">
            {children}
          </div>
        </main>
      </div>
      <TaskEditor />
      <FocusOverlay />
    </>
  );
}
