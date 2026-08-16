const CACHE = 'hackathon-india-v3';
const ASSETS = [
  'index.html',
  'manifest.webmanifest',
  'assets/logo.svg',
  'assets/icon-192.png',
  'assets/icon-512.png',
  'assets/icon-180.png',
  'assets/tn-govt.svg'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Same-origin files: stale-while-revalidate (fast + always fresh when online)
  if (url.origin === self.location.origin) {
    e.respondWith(
      caches.match(e.request).then((cached) => {
        const fetched = fetch(e.request).then((res) => {
          if (res.ok && (res.type === 'basic' || url.pathname.endsWith('.svg'))) {
            const clone = res.clone();
            caches.open(CACHE).then((c) => c.put(e.request, clone));
          }
          return res;
        }).catch(() => cached);
        return cached || fetched;
      })
    );
    return;
  }

  // Supabase data: network-first, fall back to last cached data when offline
  if (url.origin === 'https://ciarlvcyhieieioxeyth.supabase.co' && e.request.method === 'GET') {
    e.respondWith(
      fetch(e.request).then((res) => {
        if (res.ok) {
          const clone = res.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
        }
        return res;
      }).catch(() => caches.match(e.request).then((c) => c || new Response(JSON.stringify([]), { headers: { 'Content-Type': 'application/json' } })))
    );
  }
});
