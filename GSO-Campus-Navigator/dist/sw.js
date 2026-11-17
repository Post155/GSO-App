'use strict';
const CACHE='gso-campus-v2-9caeef8b030b';
const FILES=["index.html","style.css","dashboard.css","manifest.webmanifest","assets/icon.svg","assets/campus-preview.svg","assets/eg-walls.png","assets/og-walls.png","js/core/state.js","js/core/configuration.js","js/navigation/engine.js","js/editor/operations.js","js/editor/persistence.js","js/editor/bindings.js","js/map/surfaces.js","js/map/view.js","js/map/renderer.js","js/map/interactions.js","js/navigation/routing.js","js/ui/icons.js","js/ui/search.js","js/ui/places.js","js/ui/dashboard.js","js/ui/config-editor.js","js/app.js","config/building.json","config/campus.json","config/indoor-navigation.json","config/landscape-migration.json","config/outline-migration.json","config/rooms.json","config/walkability.json"];
const absolute=path=>new URL(path,self.registration.scope).href;
const allowed=new Set(FILES.map(absolute));
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES.map(absolute))).then(()=>self.skipWaiting()))});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('gso-campus-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',event=>{
 const request=event.request,url=new URL(request.url);if(request.method!=='GET'||url.origin!==self.location.origin)return;
 const scope=new URL(self.registration.scope),isShell=request.mode==='navigate'&&(url.pathname===scope.pathname||url.pathname===scope.pathname+'index.html');
 if(!isShell&&!allowed.has(url.href))return;
 const target=isShell?absolute('index.html'):url.href;
 event.respondWith(caches.open(CACHE).then(async cache=>{let cached=await cache.match(target);if(cached)return cached;return fetch(request)}));
});
