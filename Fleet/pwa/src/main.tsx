// Fleet/pwa/src/main.tsx
//
// What: PWA entrypoint.
// Does: Mounts <App /> and opens the SSE connection.
// Touches: DOM #root, events.ts.
// Touched by: index.html module script.

import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { connectEvents, reconnectEvents } from "./events";
import "./styles.css";

connectEvents();
document.addEventListener("visibilitychange", () => {
    // Coming back from background: EventSource may be zombie after a network
    // change (WiFi -> cellular via Tailscale). Force a clean reconnect.
    if (document.visibilityState === "visible") reconnectEvents();
});

createRoot(document.getElementById("root")!).render(
    <React.StrictMode>
        <App />
    </React.StrictMode>,
);
