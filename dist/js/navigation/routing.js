'use strict';
const wallGrid={data:null,floors:{},cache:new Map()};
function configureWalkability(raw){
  
  wallGrid.data=raw;
  wallGrid.cache.clear();
  for(const [floor,b64]of Object.entries(raw.floors))
  {
    
    wallGrid.floors[floor]=Uint8Array.from(atob(b64),c=>c.charCodeAt(0))
  }
}
function worldToGrid(pos){
  
  let {matrix:m,offset:o}=wallGrid.data.registration,x=pos[0]-o[0],y=pos[1]-o[1],det=m[0][0]*m[1][1]-m[0][1]*m[1][0];
  return [((x*m[1][1]-y*m[0][1])/det-1)/2,((y*m[0][0]-x*m[1][0])/det-1)/2].map(v=>Math.abs(v-Math.round(v))<.001?Math.round(v):v)
}
/** Supercover-style sampling includes both side cells on diagonal steps, preventing corner cutting. */
function crossesWall(a,b){
  
  if(!wallGrid.data||a.f!==b.f||a.f==='Gelände')
  {
    
    return false;
  }
  let k=a.f+':'+[...a.pos,...b.pos].join(','),cached=wallGrid.cache.get(k);
  if(cached!==undefined)
  {
    
    return cached;
  }
  const gridRound=v=>Math.abs(v-Math.floor(v)-.5)<1e-9?2*Math.round(v/2):Math.round(v);
  let p=worldToGrid(a.pos),q=worldToGrid(b.pos),steps=Math.max(1,Math.ceil(Math.max(Math.abs(q[0]-p[0]),Math.abs(q[1]-p[1]))*5)),previous=null,blocked=false;
  const {width,height}=wallGrid.data,bytes=wallGrid.floors[a.f];
  const free=(x,y)=>x>=0&&y>=0&&x<width&&y<height&&!!(bytes[(y*width+x)>>3]&(1<<((y*width+x)&7)));
  for(let i=0;i<=steps;i++){
    
    let t=i/steps,x=gridRound(p[0]+(q[0]-p[0])*t),y=gridRound(p[1]+(q[1]-p[1])*t);
    if(!free(x,y)||previous&&x!==previous[0]&&y!==previous[1]&&(!free(previous[0],y)||!free(x,previous[1]))){
      
      blocked=true;
      break
    }
    previous=[x,y]
  }
  if(wallGrid.cache.size>12000)
  {
    
    wallGrid.cache.clear();
  }
  wallGrid.cache.set(k,blocked);
  return blocked
}
let blockingAreas=[];
function refreshRoutingConstraints(){
 
  backgroundCache=null;
  
  blockingAreas=editor.areas.filter(a=>a.blocked);
  wallGrid.cache.clear()
}
function segmentBlocked(a,b){
  
  if(!a||!b||a.f!==b.f)
  {
    
    return false;
  }
  if(crossesWall(a,b))
  {
    
    return true;
  }
  for(const area of blockingAreas){
    
    if(area.f!==a.f)
    {
      
      continue;
    }
    let contains=p=>area.loops.reduce((hit,loop)=>hit!==insideLoop(p,loop),false);
    if(contains(a.pos)||contains(b.pos))
    {
      
      return true;
    }
    for(const loop of area.loops)
    {
      
      for(let i=0;i<loop.length;i++)
    {
        
        if(segmentsMeet(a.pos,b.pos,loop[i],loop[(i+1)%loop.length]))
    {
          
          return true
        }
      }
    }
  }
  return false
}
function shortest(a,b,accessible){
  
  const result=Routing.shortest(graph,a,b,{stepFree:accessible,blocked:segmentBlocked});
  return result?.ids.map(id=>graph.get(id))||null
}
function transitionLabel(a,b){
  
  const type=a.edges.find(e=>e.to===b.id)?.type;
  return type==='door'?'Gebäudeeingang':type==='lift'?'Aufzug':'Treppe'
}
function clearRoute(){
  
  routePath=null;
  routeChoices=[];
  $('#route-result').hidden=true;
  drawMap()
}
function routeInstructions(path){
  
  const result=[{text:'Bei '+start.code+' starten.',floor:start.floor}];
  let lastTurn=-10;
  for(let i=1;i<path.length;i++){
    
    let a=path[i-1],b=path[i];
    if(a.f!==b.f){
      
      result.push({text:transitionLabel(a,b)+' zum '+b.f+' nutzen.',floor:b.f});
      lastTurn=i;
      continue
    }
    if(i<path.length-1&&i-lastTurn>=3){
      
      let c=path[i+1];
      if(c.f!==b.f)
      {
        
        continue;
      }
      let u=[b.pos[0]-a.pos[0],b.pos[1]-a.pos[1]],v=[c.pos[0]-b.pos[0],c.pos[1]-b.pos[1]],length=Math.hypot(...u)*Math.hypot(...v);
      if(length<.01)
      {
        
        continue;
      }
      let turn=Math.atan2(u[0]*v[1]-u[1]*v[0],u[0]*v[0]+u[1]*v[1])*180/Math.PI;
      if(Math.abs(turn)>35&&Math.abs(turn)<150){
        
        result.push({text:(turn>0?'Rechts':'Links')+' dem '+(b.f==='Gelände'?'Weg':'Flur')+' folgen.',floor:b.f});
        lastTurn=i
      }
    }
  }
  result.push({text:'Über den Türpunkt zu '+end.code+'.',floor:end.floor});
  return result
}
function showRouteChoice(index){
  
  routeChoice=index;
  routePath=routeChoices[index].ids.map(id=>graph.get(id));
  let box=$('#route-result');
  box.hidden=false;
  box.className='route-result';
  const instructions=routeInstructions(routePath);
  box.innerHTML=`<div class="route-heading"><strong>${esc(start.code)} → ${esc(end.code)}</strong><button id="clear-route" aria-label="Route schließen">×</button></div><div class="route-choices">${routeChoices.map((c,i)=>`<button data-route-choice="${i}" aria-pressed="${i===index}">${i?'Alternative':'Kürzester Weg'} · ${c.ids.length} Wegpunkte</button>`).join('')}</div><ol>${instructions.map(s=>`<li>${esc(s.text)} ${s.floor!=='Gelände'?`<button data-route-floor="${esc(s.floor)}">${esc(s.floor)}</button>`:''}</li>`).join('')}</ol><p>Tür- und Flurpunkte aus den Bauplänen · Keine Live-Positionierung</p>`;
  $('#clear-route').onclick=clearRoute;
  box.querySelectorAll('[data-route-choice]').forEach(b=>b.onclick=()=>showRouteChoice(+b.dataset.routeChoice));
  box.querySelectorAll('[data-route-floor]').forEach(b=>b.onclick=()=>setFloor(b.dataset.routeFloor));
  if(!start.outdoor)
  {
    
    setFloor(start.floor);
  }else 
  {
    
    drawMap()
  }
}
function planRoute(){
  
  if(!start||!end)
  {
    
    return;
  }
  let box=$('#route-result');
  box.hidden=false;
  box.className='route-result';
  if(start.id===end.id){
    
    routePath=null;
    box.innerHTML='<strong>Du bist bereits am Ziel.</strong>';
    drawMap();
    return
  }
  routeChoices=Routing.alternatives(graph,start.node,end.node,{stepFree:$('#accessible').checked,blocked:segmentBlocked});
  if(!routeChoices.length){
    
    routePath=null;
    box.classList.add('error');
    box.innerHTML='<strong>Kein durchgängiger Weg verfügbar</strong><p>Ein Türanschluss fehlt, eine Sperrfläche blockiert den Weg oder es gibt keinen bestätigten stufenfreien Übergang. Wähle ein anderes Ziel oder prüfe den Anschluss im Editor.</p>';
    drawMap();
    return
  }
  recordRecent(end.id);
  showRouteChoice(0)
}
