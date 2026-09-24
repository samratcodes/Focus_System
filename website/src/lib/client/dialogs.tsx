"use client";

import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { GOAL_COLORS } from "@/lib/shared/logic";

// Styled replacements for window.confirm / window.prompt used by the original.

interface ConfirmOptions {
  title: string;
  message?: string;
  confirmLabel?: string;
  danger?: boolean;
}
interface GoalDialogOptions {
  title: string;
  initialName?: string;
  initialColor?: string;
  submitLabel?: string;
}
interface GoalDialogResult {
  name: string;
  color: string;
}

interface DialogApi {
  confirm: (o: ConfirmOptions) => Promise<boolean>;
  goalDialog: (o: GoalDialogOptions) => Promise<GoalDialogResult | null>;
}

const DialogContext = createContext<DialogApi>({
  confirm: async () => false,
  goalDialog: async () => null,
});

type Open =
  | { kind: "confirm"; opts: ConfirmOptions; resolve: (v: boolean) => void }
  | { kind: "goal"; opts: GoalDialogOptions; resolve: (v: GoalDialogResult | null) => void }
  | null;

export function DialogProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState<Open>(null);

  const confirm = useCallback(
    (opts: ConfirmOptions) => new Promise<boolean>((resolve) => setOpen({ kind: "confirm", opts, resolve })),
    [],
  );
  const goalDialog = useCallback(
    (opts: GoalDialogOptions) =>
      new Promise<GoalDialogResult | null>((resolve) => setOpen({ kind: "goal", opts, resolve })),
    [],
  );

  const close = (value: unknown) => {
    if (!open) return;
    (open.resolve as (v: unknown) => void)(value);
    setOpen(null);
  };

  return (
    <DialogContext.Provider value={{ confirm, goalDialog }}>
      {children}
      {open && (
        <div
          className="modal-overlay active"
          style={{ zIndex: 600 }}
          onMouseDown={(e) => e.target === e.currentTarget && close(open.kind === "confirm" ? false : null)}
          onKeyDown={(e) => e.key === "Escape" && close(open.kind === "confirm" ? false : null)}
        >
          {open.kind === "confirm" ? (
            <ConfirmBody opts={open.opts} onClose={close} />
          ) : (
            <GoalBody opts={open.opts} onClose={close} />
          )}
        </div>
      )}
    </DialogContext.Provider>
  );
}

function ConfirmBody({ opts, onClose }: { opts: ConfirmOptions; onClose: (v: boolean) => void }) {
  const ref = useRef<HTMLButtonElement>(null);
  useEffect(() => ref.current?.focus(), []);
  return (
    <div className="modal modal-sm" role="alertdialog" aria-modal="true">
      <h3>{opts.title}</h3>
      {opts.message && <p className="modal-text">{opts.message}</p>}
      <div className="modal-actions">
        <button className="btn btn-secondary" onClick={() => onClose(false)}>
          Cancel
        </button>
        <button ref={ref} className={`btn ${opts.danger ? "btn-danger" : "btn-primary"}`} onClick={() => onClose(true)}>
          {opts.confirmLabel ?? "Confirm"}
        </button>
      </div>
    </div>
  );
}

function GoalBody({ opts, onClose }: { opts: GoalDialogOptions; onClose: (v: GoalDialogResult | null) => void }) {
  const [name, setName] = useState(opts.initialName ?? "");
  const [color, setColor] = useState(opts.initialColor ?? GOAL_COLORS[0]);
  const submit = () => name.trim() && onClose({ name: name.trim(), color });
  return (
    <div className="modal modal-sm" role="dialog" aria-modal="true">
      <h3>{opts.title}</h3>
      <div className="form-group">
        <label>Goal name</label>
        <input
          autoFocus
          type="text"
          value={name}
          maxLength={80}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submit()}
        />
      </div>
      <div className="form-group">
        <label>Color</label>
        <div className="color-swatches">
          {[...new Set([...GOAL_COLORS, "#6366F1", "#10B981", "#0EA5E9", "#F97316"])].map((c) => (
            <button
              key={c}
              type="button"
              aria-label={c}
              className={`color-swatch ${c.toLowerCase() === color.toLowerCase() ? "selected" : ""}`}
              style={{ background: c }}
              onClick={() => setColor(c)}
            />
          ))}
        </div>
      </div>
      <div className="modal-actions">
        <button className="btn btn-secondary" onClick={() => onClose(null)}>
          Cancel
        </button>
        <button className="btn btn-primary" onClick={submit} disabled={!name.trim()}>
          {opts.submitLabel ?? "Save"}
        </button>
      </div>
    </div>
  );
}

export const useDialogs = () => useContext(DialogContext);
