"use client";

import { useState } from "react";
import Link from "next/link";
import {
  ArrowRight,
  CircleAlert,
  Coffee,
  Eye,
  EyeOff,
  LoaderCircle,
  Lock,
  Mail,
  Smartphone,
  Sun,
  Target,
  Timer,
  Trophy,
  User,
} from "lucide-react";
import { api, clientTimeZone, hardNavigate } from "@/lib/client/api";

const FEATURES = [
  { icon: Sun, title: "Plan the day", text: "One clear list, one priority." },
  { icon: Timer, title: "Deep focus", text: "Pomodoro sessions with real breaks." },
  { icon: Trophy, title: "Level up", text: "XP, levels and daily streaks." },
  { icon: Smartphone, title: "Everywhere", text: "Web + app, synced in real time." },
];

export default function AuthForm({ mode }: { mode: "login" | "register" }) {
  const isLogin = mode === "login";
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const strength = password.length === 0 ? 0 : password.length < 8 ? 1 : /[^a-zA-Z]/.test(password) ? 3 : 2;

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api(isLogin ? "/api/auth/login" : "/api/auth/register", {
        method: "POST",
        body: { ...(isLogin ? {} : { name }), email, password, timezone: clientTimeZone() },
      });
      const next = new URLSearchParams(window.location.search).get("next");
      // Full navigation so the server renders the app with the new session cookie.
      hardNavigate(next && next.startsWith("/") && !next.startsWith("//") ? next : "/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
      setBusy(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-glow auth-glow-a" />
      <div className="auth-glow auth-glow-b" />

      <div className="auth-shell">
        {/* Brand / hero */}
        <section className="auth-hero" aria-hidden="true">
          <div className="sidebar-brand">
            <Target />
            <span>Focus System</span>
          </div>
          <div>
            <h2 className="auth-hero-title">
              Plan today.
              <br />
              <span>Do one thing at a time.</span>
            </h2>
            <p className="auth-hero-sub">
              A calm planner with a built-in focus timer, breaks, reminders and progress — on the web and on your
              phone.
            </p>
          </div>

          <div className="auth-preview">
            <div className="auth-preview-ring">
              <svg viewBox="0 0 120 120">
                <circle cx="60" cy="60" r="52" className="ring-bg" />
                <circle cx="60" cy="60" r="52" className="ring-fg" />
              </svg>
              <div>
                <strong>18:24</strong>
                <span>FOCUS</span>
              </div>
            </div>
            <div className="auth-preview-list">
              <div className="auth-preview-task done">
                <i /> Morning review
              </div>
              <div className="auth-preview-task priority">
                <i /> Write the launch plan
              </div>
              <div className="auth-preview-task">
                <i /> Reply to emails
              </div>
              <div className="auth-preview-break">
                <Coffee /> Next: 5 min break
              </div>
            </div>
          </div>

          <ul className="auth-features">
            {FEATURES.map(({ icon: Icon, title, text }) => (
              <li key={title}>
                <span className="auth-feature-icon">
                  <Icon />
                </span>
                <div>
                  <strong>{title}</strong>
                  <span>{text}</span>
                </div>
              </li>
            ))}
          </ul>
        </section>

        {/* Form */}
        <section className="auth-card">
          <div className="auth-mobile-brand sidebar-brand">
            <Target />
            <span>Focus System</span>
          </div>

          <div className="auth-tabs" role="tablist">
            <Link href="/login" role="tab" aria-selected={isLogin} className={isLogin ? "active" : ""}>
              Sign in
            </Link>
            <Link href="/register" role="tab" aria-selected={!isLogin} className={!isLogin ? "active" : ""}>
              Create account
            </Link>
          </div>

          <div>
            <h1>{isLogin ? "Welcome back 👋" : "Start focusing today"}</h1>
            <p className="auth-sub">
              {isLogin ? "Sign in to pick up where you left off." : "Free account · syncs the website and the app."}
            </p>
          </div>

          {error && (
            <div className="auth-error" role="alert">
              <CircleAlert />
              <span>{error}</span>
            </div>
          )}

          <form className="auth-form" onSubmit={submit}>
            {!isLogin && (
              <label className="auth-field">
                <span>Name</span>
                <div className="auth-input">
                  <User />
                  <input
                    id="name"
                    autoComplete="name"
                    placeholder="Your name"
                    required
                    maxLength={80}
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                </div>
              </label>
            )}
            <label className="auth-field">
              <span>Email</span>
              <div className="auth-input">
                <Mail />
                <input
                  id="email"
                  type="email"
                  autoComplete="email"
                  placeholder="you@example.com"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
            </label>
            <label className="auth-field">
              <span>Password</span>
              <div className="auth-input">
                <Lock />
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  autoComplete={isLogin ? "current-password" : "new-password"}
                  placeholder={isLogin ? "Your password" : "At least 8 characters"}
                  required
                  minLength={isLogin ? undefined : 8}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
                <button
                  type="button"
                  className="auth-eye"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  onClick={() => setShowPassword((s) => !s)}
                >
                  {showPassword ? <EyeOff /> : <Eye />}
                </button>
              </div>
              {!isLogin && (
                <div className={`auth-strength s${strength}`} aria-hidden="true">
                  <i />
                  <i />
                  <i />
                  <em>{["", "Too short", "Good", "Strong"][strength]}</em>
                </div>
              )}
            </label>

            <button className="btn btn-primary btn-block auth-submit" type="submit" disabled={busy}>
              {busy ? <LoaderCircle className="spin" /> : null}
              {isLogin ? "Sign in" : "Create account"}
              {!busy && <ArrowRight />}
            </button>
          </form>

          <div className="auth-switch">
            {isLogin ? (
              <>
                New here? <Link href="/register">Create a free account</Link>
              </>
            ) : (
              <>
                Already have an account? <Link href="/login">Sign in</Link>
              </>
            )}
          </div>
          <div className="auth-switch" style={{ fontSize: 12 }}>
            <Link href="/privacy">Privacy policy</Link>
          </div>
        </section>
      </div>
    </div>
  );
}
