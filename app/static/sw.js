// Vidéo pas à pas — service worker (application installable)
// SPDX-License-Identifier: AGPL-3.0-or-later
// Met en cache l'interface pour un démarrage rapide ; les envois et traitements passent toujours par le serveur.
const CACHE = "video-pas-a-pas-v1";
const SHELL = ["/", "/manifest.webmanifest", "/static/icons/icon-192.png", "/static/icons/icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((keys) =>
    Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))));
  self.clients.claim();
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin ||
      url.pathname.startsWith("/api/") || url.pathname === "/share") {
    return; // envois, estimations, téléchargements : jamais mis en cache
  }
  // Réseau d'abord (toujours la dernière version), cache si hors ligne
  e.respondWith(
    fetch(e.request).then((resp) => {
      if (resp.ok && SHELL.includes(url.pathname)) {
        const copy = resp.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
      }
      return resp;
    }).catch(() => caches.match(e.request, { ignoreSearch: true }))
  );
});
