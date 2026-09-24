"use client";

// Ported from shared.js: playChime / playAlarm (Web Audio, no assets needed).

function ctx() {
  const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  return new Ctor();
}

export function playChime() {
  try {
    const c = ctx();
    [523.25, 659.25, 783.99, 1046.5].forEach((freq, i) => {
      const osc = c.createOscillator();
      const gain = c.createGain();
      osc.type = "sine";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.15, c.currentTime + i * 0.15);
      gain.gain.exponentialRampToValueAtTime(0.001, c.currentTime + i * 0.15 + 0.4);
      osc.connect(gain);
      gain.connect(c.destination);
      osc.start(c.currentTime + i * 0.15);
      osc.stop(c.currentTime + i * 0.15 + 0.4);
    });
  } catch {}
}

export function playAlarm() {
  try {
    const c = ctx();
    const pattern = [
      { freq: 880, start: 0, dur: 0.18 },
      { freq: 660, start: 0.22, dur: 0.18 },
      { freq: 880, start: 0.48, dur: 0.18 },
      { freq: 660, start: 0.7, dur: 0.18 },
      { freq: 1046, start: 1.02, dur: 0.28 },
    ];
    pattern.forEach((note) => {
      const osc = c.createOscillator();
      const gain = c.createGain();
      osc.type = "square";
      osc.frequency.value = note.freq;
      gain.gain.setValueAtTime(0.001, c.currentTime + note.start);
      gain.gain.exponentialRampToValueAtTime(0.18, c.currentTime + note.start + 0.03);
      gain.gain.exponentialRampToValueAtTime(0.001, c.currentTime + note.start + note.dur);
      osc.connect(gain);
      gain.connect(c.destination);
      osc.start(c.currentTime + note.start);
      osc.stop(c.currentTime + note.start + note.dur + 0.02);
    });
  } catch {}
}

/** System notification when the tab is in the background (asks permission lazily). */
export function notify(title: string, body: string) {
  if (typeof Notification === "undefined") return;
  if (Notification.permission === "granted" && document.hidden) {
    try {
      new Notification(title, { body, icon: "/icon.svg" });
    } catch {}
  }
}

export function requestNotificationPermission() {
  if (typeof Notification !== "undefined" && Notification.permission === "default") {
    Notification.requestPermission().catch(() => {});
  }
}
