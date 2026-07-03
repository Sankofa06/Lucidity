// Fleet/pwa/public/sw.js
//
// What: Service worker for the Lucidity Fleet PWA.
// Does: Precaches the app shell so the installed app opens instantly (even
//       when the tailnet is briefly unreachable), serves navigations
//       network-first with cached fallback, and never touches /api.
// Touches: Cache Storage.
// Touched by: registered from index.html; updated on every deploy (bump VERSION).

const VERSION = "lucidity-shell-v1";
const SHELL = ["/", "/manifest.webmanifest", "/icons/icon-192.png", "/icons/icon-512.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(VERSION).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  // Live data and SSE must always hit the network.
  if (url.pathname.startsWith("/api/") || event.request.method !== "GET") return;

  if (event.request.mode === "navigate") {
    // Network-first navigation: fresh app when reachable, cached shell offline.
    event.respondWith(
      fetch(event.request)
        .then((res) => {
          const copy = res.clone();
          caches.open(VERSION).then((cache) => cache.put("/", copy));
          return res;
        })
        .catch(() => caches.match("/"))
    );
    return;
  }

  // Hashed static assets: cache-first (immutable by construction).
  event.respondWith(
    caches.match(event.request).then(
      (cached) =>
        cached ||
        fetch(event.request).then((res) => {
          const copy = res.clone();
          caches.open(VERSION).then((cache) => cache.put(event.request, copy));
          return res;
        })
    )
  );
});
