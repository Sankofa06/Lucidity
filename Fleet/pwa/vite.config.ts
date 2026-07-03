// Fleet/pwa/vite.config.ts
//
// What: Vite build/dev configuration for the Lucidity PWA.
// Does: React plugin; in dev, proxies /api to a local orchestrator so the
//       PWA can be developed against a live fleet without CORS.
// Touches: nothing at runtime — build tooling only.
// Touched by: `npm run dev` / `npm run build` in this workspace.

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
    plugins: [react()],
    server: {
        proxy: {
            "/api": {
                target: process.env.ORCHESTRATOR_URL ?? "http://127.0.0.1:8780",
                changeOrigin: true,
            },
        },
    },
    build: {
        sourcemap: true,
    },
});
