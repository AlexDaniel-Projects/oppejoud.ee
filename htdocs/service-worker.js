var CACHE_NAME = 'oppejoud-cache-v1';
var urlsToCache = [
    '/',
    '/css/awesomplete.css',
    '/css/my.css',
    '/js/awesomplete.js',
    '/js/my.js',
    '/js/scroll.js'
];

self.addEventListener('install', function(event) {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(function(cache) {
                console.log('Opened cache');
                return cache.addAll(urlsToCache);
            })
    );
});

self.addEventListener('fetch', function(event) {
    event.respondWith(
        caches.match(event.request)
            .then(function(response) {
                if (response) { return response; }
                return fetch(event.request);
            }
                 )
    );
});
