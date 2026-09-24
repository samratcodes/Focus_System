import { config } from "./config.js";
import { createApp } from "./create-app.js";
import { prisma } from "./lib/db.js";

const app = createApp();

// On Vercel the exported app is served as a Vercel Function (no listen needed).
// Locally (npm run dev / npm start) we start a normal HTTP server.
if (!process.env.VERCEL) {
  const server = app.listen(config.port, config.host, () => {
    console.log(`Focus System API listening on http://localhost:${config.port}`);
    console.log(`  phones on your Wi-Fi: http://<this computer's IP>:${config.port}`);
  });
  const shutdown = async () => {
    server.close();
    await prisma.$disconnect();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

export default app;
