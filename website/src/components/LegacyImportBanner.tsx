"use client";

import { useState } from "react";
import { Upload } from "lucide-react";
import { api } from "@/lib/client/api";
import { useMounted } from "@/lib/client/clock";
import { markLegacyImported, readLegacyData } from "@/lib/client/legacy";
import { useStore } from "@/lib/client/store";
import { useToast } from "@/lib/client/toast";

export default function LegacyImportBanner() {
  const { data, refresh } = useStore();
  const toast = useToast();
  const [hidden, setHidden] = useState(false);
  const [busy, setBusy] = useState(false);
  const mounted = useMounted(); // localStorage only exists in the browser
  const userId = data.user.id;

  const legacy = mounted && !hidden ? readLegacyData(userId) : null;
  if (!legacy) return null;

  const count = (legacy.tasks as unknown[]).length;

  const doImport = async () => {
    setBusy(true);
    try {
      const res = await api<{ imported: { tasks: number } }>("/api/import", { method: "POST", body: legacy });
      markLegacyImported(userId);
      setHidden(true);
      await refresh();
      toast(`Imported ${res.imported.tasks} tasks into your account`, "success");
    } catch (err) {
      toast(err instanceof Error ? err.message : "Import failed", "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="banner">
      <Upload />
      <div>
        <strong>Found data from the previous version</strong>
        <span>
          {count} task{count === 1 ? "" : "s"} saved in this browser. Import them into your account to sync with the app.
        </span>
      </div>
      <button className="btn btn-sm btn-primary" onClick={doImport} disabled={busy}>
        Import
      </button>
      <button
        className="btn btn-sm btn-secondary"
        onClick={() => {
          markLegacyImported(userId);
          setHidden(true);
        }}
      >
        Dismiss
      </button>
    </div>
  );
}
