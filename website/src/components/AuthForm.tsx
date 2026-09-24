"use client";

import { useState } from "react";
import Link from "next/link";
import { CircleAlert, Eye, EyeOff, LoaderCircle, Target } from "lucide-react";
import { api, clientTimeZone, hardNavigate } from "@/lib/client/api";

export default function AuthForm({ mode }: { mode: "login" | "register" }) {
  const isLogin = mode === "login";
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

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
      <div className="auth-card">
        <div className="sidebar-brand">
          <Target />
          <span>Focus System</span>
        </div>
        <div>
          <h1>{isLogin ? "Welcome back" : "Create your account"}</h1>
          <p className="auth-sub">
            {isLogin
              ? "Sign in to plan today and do one thing at a time."
              : "One account for the website and the mobile app."}
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
            <div className="field">
              <label htmlFor="name">Name</label>
              <input
                id="name"
                autoComplete="name"
                required
                maxLength={80}
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </div>
          )}
          <div className="field">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor="password">Password</label>
            <div className="password-wrap">
              <input
                id="password"
                type={showPassword ? "text" : "password"}
                autoComplete={isLogin ? "current-password" : "new-password"}
                required
                minLength={isLogin ? undefined : 8}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <button
                type="button"
                className="btn-icon"
                aria-label={showPassword ? "Hide password" : "Show password"}
                onClick={() => setShowPassword((s) => !s)}
              >
                {showPassword ? <EyeOff /> : <Eye />}
              </button>
            </div>
            {!isLogin && <small>At least 8 characters.</small>}
          </div>
          <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
            {busy && <LoaderCircle className="spin" />}
            {isLogin ? "Sign in" : "Create account"}
          </button>
        </form>

        <div className="auth-switch">
          {isLogin ? (
            <>
              New here? <Link href="/register">Create an account</Link>
            </>
          ) : (
            <>
              Already have an account? <Link href="/login">Sign in</Link>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
