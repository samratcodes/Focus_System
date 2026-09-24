import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./ui-v2.css";

export const metadata: Metadata = {
  title: "Focus System",
  description: "Plan today. Do one thing at a time.",
  icons: { icon: "/icon.svg" },
};

export const viewport: Viewport = {
  themeColor: "#09090B",
  colorScheme: "dark",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
