"use client";

import { Search } from "lucide-react";
import { useNow } from "@/lib/client/clock";
import { completionRate, useStore } from "@/lib/client/store";

function greeting(now: Date) {
  const h = now.getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

export default function Header() {
  const { data, today, ui, setUi } = useStore();
  // Clock-dependent text renders after hydration to avoid SSR mismatches.
  const minute = useNow(60_000);
  const now = minute === null ? null : new Date(minute);

  const rate = completionRate(data.tasks, today);
  const first = data.user.name.split(/\s+/)[0];

  return (
    <header className="header">
      <div className="header-greeting">
        <h2>
          {now ? greeting(now) : "Hello"}
          {first ? `, ${first}` : ""}
        </h2>
        <span>
          {now
            ? `${now.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" })} · ${now.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })}`
            : " "}
        </span>
      </div>
      <div className="header-search">
        <Search />
        <input
          type="text"
          placeholder="Search tasks..."
          id="search-input"
          value={ui.searchQuery}
          onChange={(e) => setUi({ searchQuery: e.target.value })}
        />
      </div>
      <div className="completion-bar">
        <div className="bar-track">
          <div className="bar-fill" style={{ width: `${rate}%` }} />
        </div>
        <span className="bar-text">{rate}%</span>
      </div>
    </header>
  );
}
