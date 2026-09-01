const CACHE_NAME = 'circuitjs1-app-cache-v2';
const urlsToCache = [
  '/circuit/about.html',
  '/circuit/canvas2svg.js',
  '/circuit/circuitjs.html',
  '/circuit/crystal.html',
  '/circuit/customfunction.html',
  '/circuit/customlogic.html',
  '/circuit/customtransformer.html',
  '/circuit/diodecalc.html',
  '/circuit/icon512.png',
  '/circuit/icon128.png',
  '/circuit/iframe.html',
  '/circuit/lz-string.min.js',
  '/circuit/manifest.json',
  '/circuit/mexle.html',
  '/circuit/mosfet-beta.html',
  '/circuit/opampreal.html',
  '/circuit/split.js',
  '/circuit/subcircuits.html',
];

function isNetworkFirst(url) {
  return /circuitjs[^/]*\.html(?:\?|$)/.test(url) || url.includes('.nocache.js');
}

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') {
    return;
  }

  if (isNetworkFirst(event.request.url)) {
    event.respondWith(
      fetch(event.request).then((networkResponse) => {
        if (networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }

        return networkResponse;
      }).catch(() => caches.match(event.request))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }

      return fetch(event.request).then((networkResponse) => {
        if (event.request.method === 'GET' && networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }

        return networkResponse;
      });
    })
  );
});

self.addEventListener('activate', (event) => {
  const cacheWhitelist = [CACHE_NAME];

  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (!cacheWhitelist.includes(cacheName)) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});
