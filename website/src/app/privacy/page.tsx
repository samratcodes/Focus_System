import type { Metadata } from "next";
import Link from "next/link";
import { Target } from "lucide-react";

export const metadata: Metadata = { title: "Privacy Policy — Focus System" };

const UPDATED = "September 24, 2026";

export default function PrivacyPage() {
  return (
    <div className="legal-page">
      <article className="legal-card">
        <Link href="/" className="sidebar-brand legal-brand">
          <Target />
          <span>Focus System</span>
        </Link>
        <h1>Privacy Policy</h1>
        <p className="legal-updated">Last updated: {UPDATED}</p>

        <p>
          Focus System (the website at focus-system-amber.vercel.app and the Focus System mobile app) helps you plan tasks
          and run focus sessions. This policy explains what we collect and how we use it. In short:{" "}
          <strong>we only store what the app needs to work, we never sell your data, and you can delete it at any time.</strong>
        </p>

        <h2>What we collect</h2>
        <ul>
          <li>
            <strong>Account details</strong> — your name, email address and a securely hashed password (bcrypt). We never
            store your password in plain text.
          </li>
          <li>
            <strong>Your content</strong> — tasks, subtasks, goals, focus sessions, settings, XP and streaks that you
            create.
          </li>
          <li>
            <strong>Time zone</strong> — so &quot;today&quot; and reminders match your local day.
          </li>
        </ul>
        <p>
          We do <strong>not</strong> collect your location, contacts, photos, advertising identifiers or device
          identifiers, and the app contains no ads or third-party analytics.
        </p>

        <h2>How we use it</h2>
        <ul>
          <li>To sign you in and keep your data in sync between the website and the app.</li>
          <li>To show reminders, focus alarms and your home-screen widget. These notifications are generated on your device.</li>
          <li>We do not sell, rent or share your personal data with third parties for marketing.</li>
        </ul>

        <h2>Where it is stored</h2>
        <p>
          Data is stored in a PostgreSQL database hosted by Neon (United States) and served through Vercel. All traffic is
          encrypted in transit (HTTPS/TLS). On your phone, your sign-in token is kept in encrypted storage and is excluded
          from device backups.
        </p>

        <h2>Permissions used by the app</h2>
        <ul>
          <li><strong>Notifications</strong> — focus countdown, break alarms and task reminders.</li>
          <li><strong>Alarms &amp; reminders</strong> — so session and break alarms ring on time.</li>
          <li><strong>Run at startup</strong> — to restore scheduled reminders after the phone restarts.</li>
          <li><strong>Internet</strong> — to sync with your account.</li>
        </ul>

        <h2>Your choices and rights</h2>
        <ul>
          <li>
            <strong>Delete your account</strong> — in the app (Settings → Delete account) or on the website (Settings →
            Delete account). This permanently deletes your account and all associated data immediately.
          </li>
          <li>
            <strong>Export your data</strong> — on the website (Settings → Export JSON).
          </li>
          <li>You can turn notifications off at any time in Settings or in your phone&apos;s system settings.</li>
        </ul>

        <h2>Children</h2>
        <p>Focus System is not directed to children under 13 and we do not knowingly collect their data.</p>

        <h2>Changes</h2>
        <p>If this policy changes, we will update the date above. Continued use means you accept the updated policy.</p>

        <h2>Contact</h2>
        <p>
          Questions or requests: open an issue at{" "}
          <a href="https://github.com/samratcodes/Focus_System/issues">github.com/samratcodes/Focus_System</a>.
        </p>
      </article>
    </div>
  );
}
