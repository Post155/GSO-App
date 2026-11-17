'use strict';
const preferences={favorites:[],recent:[],theme:'dark',language:'de',kiosk:false};
let uiView='dashboard';
function loadPreferences(){
  
  try{
    
    let saved=JSON.parse(localStorage.getItem('gso-preferences-v1')||'{}');
    preferences.favorites=Array.isArray(saved.favorites)?saved.favorites.filter(id=>typeof id==='string').slice(0,100):[];
    preferences.recent=Array.isArray(saved.recent)?saved.recent.filter(id=>typeof id==='string').slice(0,12):[];
    preferences.theme=saved.theme==='light'?'light':'dark';
    preferences.language=saved.language==='en'?'en':'de'
  }catch{
    
  }
  document.documentElement.dataset.theme=preferences.theme
}
function persistPreferences(){
  
  try{
    
    localStorage.setItem('gso-preferences-v1',JSON.stringify(preferences))
  }catch{
    
    $('#app-status').textContent='Browserspeicher nicht verfügbar · JSON-Export bleibt möglich.'
  }
}
function recordRecent(id){
  
  preferences.recent=[id,...preferences.recent.filter(x=>x!==id)].slice(0,8);
  persistPreferences();
  renderDashboard()
}
function toggleFavorite(id){
  
  preferences.favorites=preferences.favorites.includes(id)?preferences.favorites.filter(x=>x!==id):[id,...preferences.favorites].slice(0,100);
  persistPreferences();
  renderDashboard()
}
function openView(name){
  
  uiView=name;
  $('#dashboard').hidden=name!=='dashboard';
  $$('[data-main-view]').forEach(b=>{
    
    b.classList.toggle('active',b.dataset.mainView===name);
    b.setAttribute('aria-pressed',String(b.dataset.mainView===name))
  });
  if(name==='map'){
    
    applyView();
    if(innerWidth<=700)
    {
      
      $('.sidebar').classList.remove('open')
    }
  }
  renderDashboard()
}
function targetCard(p){
  
  return `<button class="dashboard-target" data-dashboard-place="${esc(p.id)}"><span class="dashboard-icon">${uiIcon(p.category)}</span><span><strong>${esc(p.code)}</strong><small>${esc(p.floor)} · ${esc(p.name)}</small></span><span aria-hidden="true">↗</span></button>`
}
function renderDashboard(){
  
  if(!data||!places.length)
  {
    
    return;
  }
  const visible=places.filter(p=>!p.hidden),favorites=preferences.favorites.map(id=>visible.find(p=>p.id===id)).filter(Boolean),recent=preferences.recent.map(id=>visible.find(p=>p.id===id)).filter(Boolean);
  $('#favorite-places').innerHTML=favorites.length?favorites.map(targetCard).join(''):'<p class="dashboard-empty">Öffne einen Raum und markiere ihn mit ☆ als Favorit.</p>';
  $('#recent-places').innerHTML=recent.length?recent.map(targetCard).join(''):'<p class="dashboard-empty">Deine zuletzt verwendeten Ziele erscheinen hier.</p>';
  const quick=visible.filter(p=>['office','wc','entrance','bicycle','parking','bus'].includes(p.category)&&!p.code.startsWith('Eingang E')).sort((a,b)=>Number(!a.name.toLowerCase().includes('sekretariat'))-Number(!b.name.toLowerCase().includes('sekretariat'))).slice(0,6);
  $('#quick-places').innerHTML=quick.map(targetCard).join('');
  $('#building-summary').innerHTML=['A','B','C','D'].map(b=>{
    
    let rooms=visible.filter(p=>!p.outdoor&&p.building===b);
    return `<button class="building-card" data-building="${b}"><span>TRAKT</span><strong>${b}</strong><small>${rooms.length} Ziele · EG / OG</small><i>↗</i></button>`
  }).join('');
  let indoor=visible.filter(p=>!p.outdoor),reachable=indoor.filter(p=>p.node&&graph.has(p.node));
  $('#stat-rooms').textContent=indoor.length;
  $('#stat-connected').textContent=reachable.length;
  $('#stat-doors').textContent=indoorNavigation?.doors.filter(d=>!graph.get(d.id)?.edges.length).length||0;
  $('#current-location-label').textContent=currentLocation?currentLocation.code+' · '+currentLocation.floor:'Standort selbst auswählen';
  $('#connection-status').textContent=navigator.onLine===false?'Offline · lokale Karte':'Online · lokale Karte bereit';
  $('#floor-status').textContent=floor;
  $('#dashboard').querySelectorAll('[data-dashboard-place]').forEach(b=>b.onclick=()=>{
    
    openView('map');
    setMapMode('school');
    let p=places.find(p=>p.id===b.dataset.dashboardPlace);
    selectPlace(p)
  });
  $('#dashboard').querySelectorAll('[data-building]').forEach(b=>b.onclick=()=>{
    
    openView('map');
    setMapMode('school');
    $('#browse-search').value=b.dataset.building+' ';
    renderList();
    $('.sidebar').classList.add('open')
  })
}
function dashboardSearch(){
  
  let input=$('#dashboard-search'),box=$('#dashboard-results'),q=input.value.trim();
  box.hidden=!q;
  if(!q)
  {
    
    return;
  }
  let list=searchPlaces(q,{allModes:true}).slice(0,8);
  box.innerHTML=list.length?list.map(targetCard).join(''):'<p class="dashboard-empty">Kein passendes Ziel gefunden.</p>';
  box.querySelectorAll('button').forEach(b=>b.onclick=()=>{
    
    let p=places.find(p=>p.id===b.dataset.dashboardPlace);
    input.value='';
    box.hidden=true;
    openView('map');
    setMapMode('school');
    selectPlace(p)
  })
}
function setCurrentLocation(p){
  
  currentLocation=p;
  setEndpoint('start',p);
  if(!p.outdoor)
  {
    
    setFloor(p.floor);
  }
  $('#location-status').textContent='Standort: '+p.code+' · '+p.floor+' (manuell)';
  renderDashboard();
  drawMap()
}
function positionFromURL(){
  
  let id=new URLSearchParams(location.search).get('location');
  if(id){
    
    let p=places.find(p=>p.id===id&&!p.hidden);
    if(p){
      
      setCurrentLocation(p);
      openView('map')
    }else 
    {
      
      $('#app-status').textContent='Der Standort-Link enthält kein bekanntes Ziel.'
    }
  }
}
function locationLink(p){
  
  let url=new URL(location.href);
  url.search='';
  url.hash='';
  url.searchParams.set('location',p.id);
  return url.toString()
}
function applyLanguage(lang){
  
  preferences.language=lang;
  document.documentElement.lang=lang;
  const en=lang==='en',labels={'nav-home':en?'Overview':'Übersicht','nav-map':en?'Map & route':'Karte & Route','dashboard-eyebrow':en?'GEORG-SIMON-OHM · COLOGNE':'GEORG-SIMON-OHM · KÖLN','dashboard-title':en?'Find your way.':'Dein Weg. Dein Campus.','dashboard-subtitle':en?'Rooms, entrances and favourite places, all in one view.':'Räume, Eingänge und Lieblingsorte auf einen Blick.','quick-title':en?'Quick navigation':'Schnellnavigation','favorite-title':en?'Favourites':'Lieblingsräume','recent-title':en?'Recent destinations':'Zuletzt verwendet'};
  for(const[id,label]of Object.entries(labels))
  {
    
    $('#'+id).textContent=label;
  }
  $('#dashboard-search').placeholder=en?'Search room, place or floor …':'Raum, Ort oder Etage suchen …';
  $('#language-toggle').textContent=en?'DE':'EN';
  persistPreferences()
}
function initDashboard(){
  
  loadPreferences();
  $$('[data-main-view]').forEach(b=>b.onclick=()=>openView(b.dataset.mainView));
  $('#dashboard-search').addEventListener('input',dashboardSearch);
  $('#dashboard-search').addEventListener('keydown',e=>{
    
    if(e.key==='Escape')
    {
      
      $('#dashboard-results').hidden=true;
    }
    if(e.key==='ArrowDown'){
      
      e.preventDefault();
      $('#dashboard-results button')?.focus()
    }
    if(e.key==='Enter')
    {
      
      $('#dashboard-results button')?.click()
    }
  });
  $('#theme-toggle').onclick=()=>{
    
    preferences.theme=preferences.theme==='dark'?'light':'dark';
    document.documentElement.dataset.theme=preferences.theme;
    $('#theme-toggle').setAttribute('aria-pressed',String(preferences.theme==='light'));
    persistPreferences()
  };
  $('#language-toggle').onclick=()=>applyLanguage(preferences.language==='de'?'en':'de');
  $('#kiosk-toggle').onclick=()=>{
    
    preferences.kiosk=!preferences.kiosk;
    document.body.classList.toggle('kiosk',preferences.kiosk);
    $('#kiosk-toggle').textContent=preferences.kiosk?'Kiosk beenden':'Kiosk';
    $('#kiosk-toggle').setAttribute('aria-pressed',String(preferences.kiosk))
  };
  window.addEventListener('online',renderDashboard);
  window.addEventListener('offline',renderDashboard);
  document.addEventListener('keydown',e=>{
    
    if(e.key==='Escape'&&preferences.kiosk){
      
      preferences.kiosk=false;
      document.body.classList.remove('kiosk');
      $('#kiosk-toggle').textContent='Kiosk'
    }
  });
  applyLanguage(preferences.language);
  openView('dashboard')
}
