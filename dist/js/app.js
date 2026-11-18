'use strict';
async function readJSON(path){
  
  let response=await fetch(path);
  if(!response.ok)
  {
    
    throw Error('Datei konnte nicht geladen werden: '+path);
  }
  return response.json()
}
function bindApplication(){
 
  bindMapInteractions();
  initDashboard();
  bindSearch('start');
  bindSearch('end');
  $('#view-campus').onclick=()=>setMapMode('school');
  $('#view-wide').onclick=()=>setMapMode('neighbourhood');
  $('#zoom-in').onclick=()=>zoom(.8);
  $('#zoom-out').onclick=()=>zoom(1.25);
  $('#reset').onclick=fit;
  $('#outdoors').onclick=()=>{
    
    setFloor('EG');
    setMapMode('school')
  };
  $$('[data-floor]').forEach(b=>b.onclick=()=>setFloor(b.dataset.floor));
  $('#route').onclick=planRoute;
  $('#swap').onclick=()=>{
    
    [start,end]=[end,start];
    $('#start').value=start?.code||'';
    $('#end').value=end?.code||'';
    clearRoute();
    $('#route').disabled=!(start&&end)
  };
  $('#accessible').onchange=()=>{
    
    if(routePath)
    {
      
      planRoute()
    }
  };
  $('#browse-search').oninput=renderList;
  $('#important-only').onchange=()=>{
    
    renderList();
    drawMap()
  };
  $$('[data-filter]').forEach(b=>b.onclick=()=>{
    
    filter=b.dataset.filter;
    $$('[data-filter]').forEach(x=>x.classList.toggle('active',x===b));
    renderList()
  });
  ['info-button','source-button'].forEach(id=>$('#'+id).onclick=()=>$('#info').showModal());
  $('.dialog-close').onclick=()=>$('#info').close();
  $('#mobile-panel').onclick=()=>{
    
    openView('map');
    $('.sidebar').classList.toggle('open')
  };
  $('#room-export').onclick=()=>downloadJSON(roomCatalogue(),'gso-raeume.json');
  $('#room-import').onclick=()=>$('#room-file').click();
  $('#room-file').onchange=e=>importRoomCatalogue(e.target.files[0]);
  content.addEventListener('click',e=>{
    
    if(editor.active||moved)
    {
      
      return;
    }
    let hit=e.target.closest('[data-place],[data-region]');
    if(!hit)
    {
      
      return;
    }
    let p=hit.dataset.place?places.find(p=>p.id===hit.dataset.place):data.floors[floor].rooms.find(p=>p.region===+hit.dataset.region);
    if(p&&!p.hidden)
    {
      
      selectPlace(p)
    }
  });
  content.addEventListener('keydown',e=>{
    
    if(e.key==='Enter'||e.key===' '){
      
      let hit=e.target.closest('[data-place],[data-region]');
      if(hit){
        
        e.preventDefault();
        let p=hit.dataset.place?places.find(p=>p.id===hit.dataset.place):data.floors[floor].rooms.find(p=>p.region===+hit.dataset.region);
        if(p&&!p.hidden)
        {
          
          selectPlace(p)
        }
      }
    }
  });
  window.addEventListener('pagehide',()=>{
    
    pointers.clear();
    drag=null;
    pinch=null
  });
}
async function bootstrap(){
  
  try{
 
    const [building,rooms,campus,navigation,outlines,landscape,walkability,appConfig]=await Promise.all(['building','rooms','campus','indoor-navigation','outline-migration','landscape-migration','walkability','app'].map(name=>readJSON('config/'+name+'.json')));
    data=building;
    appSettings=Config.validateApp(appConfig);
    configRooms=Config.validateRooms(rooms);
    SCHOOL_VIEW=[...appSettings.maps.school];
    NEIGHBOURHOOD_VIEW=[...appSettings.maps.neighbourhood];
    base=[...SCHOOL_VIEW];
    view=[...base];
    const customIDs=new Set(campus.customPlaces.map(p=>p.id));
    outside=['gate-north','smoking','bicycles','cars','gate-parking',...Array.from({length:8},(_,i)=>'entry-'+(i+1))].map(id=>({id,...campus.pointMeta[id],pos:campus.points[id],node:campus.pointNodes[id],floor:'Gelände',outdoor:true,hidden:campus.hiddenPoints.includes(id)}));
    places=[...outside,...configRooms.rooms.map(r=>({id:r.id,code:r.code,name:r.name,building:r.building,category:r.type,floor:r.floor,x:r.x,y:r.y,region:r.region,pos:world(r.x,r.y),node:campus.pointNodes[r.id]||null,outdoor:false,important:r.important,hidden:!r.visible}))];
 // Room catalogue is authoritative for published defaults; local snapshots remain separate.
    const known=new Set(places.map(p=>p.id));
    for(const id of Object.keys(campus.points))
    {
      
      if(!known.has(id)&&!customIDs.has(id)){
      
        delete campus.points[id];
        delete campus.pointNodes[id];
        delete campus.pointMeta[id];
        campus.hiddenPoints=campus.hiddenPoints.filter(x=>x!==id)
      }
    }
    for(const p of places.filter(p=>!p.outdoor)){
      
      campus.points[p.id]=p.pos;
      campus.pointMeta[p.id]={code:p.code,name:p.name,category:p.category};
      campus.pointNodes[p.id]=campus.pointNodes[p.id]||null;
      campus.hiddenPoints=campus.hiddenPoints.filter(id=>id!==p.id);
      if(p.hidden)
      {
        
        campus.hiddenPoints.push(p.id)
      }
    }
    syncFloorRooms();
    initEditor();
    syncFloorRooms();
    bindApplication();
    setMapMode('school');
    positionFromURL();
    renderList();
    renderDashboard();
    $('#app-status').textContent=appSettings.release.statusReady+' · Stand '+appSettings.release.date;
    if('serviceWorker'in navigator){
      
      try{
        
        let registration=await navigator.serviceWorker.register('sw.js');
        registration.addEventListener('updatefound',()=>{
          
          let worker=registration.installing;
          worker?.addEventListener('statechange',()=>{
            
            if(worker.state==='activated')
            {
              
              $('#offline-status').textContent='Offline-Karte vorbereitet'
            }
          })
        });
        $('#offline-status').textContent=navigator.serviceWorker.controller?'Offline-Karte aktiv':'Offline-Karte wird vorbereitet'
      }catch{
        
        $('#offline-status').textContent='Offline-Speicherung nicht verfügbar'
      }
    }
  }catch(err){
    
    console.error(err);
    $('#app-status').textContent=appSettings?.release.statusLoadFailed||'Laden fehlgeschlagen. Bitte erneut versuchen.';
    $('#places').innerHTML='<p class="empty">Die Karte konnte nicht geladen werden.</p>';
    $('#dashboard-results').hidden=false;
    $('#dashboard-results').innerHTML='<p class="dashboard-empty">'+esc(appSettings?.release.statusRetryDashboard||'Karte nicht verfügbar.')+' <button id="retry-load">Erneut laden</button></p>';
    $('#retry-load').onclick=()=>location.reload()
  }
}
const appReady=bootstrap();
