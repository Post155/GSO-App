'use strict';

function drawMap(){
  
  if(!data)
  {
    
    return;
  }
  let f=data.floors[floor],m=data.registration.matrix,o=data.registration.offset,transform=`matrix(${m[0][0]} ${m[1][0]} ${m[0][1]} ${m[1][1]} ${o[0]} ${o[1]})`;
  let h=drawSurroundings()+`
 <path d="${[['M',...world(345,125)],['L',...world(1930,125)],['L',...world(1930,670)],['L',...world(1358,670)],['L',...world(1358,340)],['L',...world(640,340)],['L',...world(640,1125)],['L',...world(1358,1125)],['L',...world(1358,798)],['L',...world(1620,798)],['L',...world(1620,1340)],['L',...world(345,1340)]].map(a=>a[0]+a.slice(1).join(',')).join(' ')}Z" fill="#8295ad" stroke="#a3b4c7" stroke-width="1" filter="url(#shadow)"/>`;
 // The courtyard remains an open exterior area.
  h+=drawCourtyard();
  const colors={classroom:'#4d6684',office:'#566e8b',service:'#425b74',wc:'#72628e',stairs:'#486e82',lift:'#527a88',corridor:'#8295ad'};
  const areaByID=new Map(editor.areas.map(a=>[a.id,a])),roomByRegion=new Map(f.rooms.map(r=>[r.region,r]));
  if(mapMode==='school'||editor.active)
  {
    
    for(const reg of f.regions){
    
      let area=areaByID.get('room-'+floor+'-'+reg.id);
      if(!area)
    {
        
        continue;
      }
      let room=roomByRegion.get(reg.id),color=colors[room?.category]||'#4d6681';
      h+=`<path class="room ${selected?.region===reg.id&&selected.floor===floor?'selected':''}" data-region="${reg.id}" ${room&&!room.hidden?`tabindex="0" role="button" aria-label="${esc(room.code)}"`: ''} d="${areaD(area)}" fill="${area.color||color}" opacity="${area.opacity}"/>`
    }
  }
  if(mapMode==='school'||editor.active)
  {
    
    h+=`<g transform="${transform}" opacity=".48" style="mix-blend-mode:multiply" pointer-events="none"><image href="assets/${floor.toLowerCase()}-walls.png" width="2100" height="1486"/></g>`;
  }
  h+=renderCustomAreas();
 // Outdoor path overlay is an explicit graph based on the user's markings.
  let done=new Set();
  for(const n of graph.values())
  {
    
    if(n.f==='Gelände')
  {
      
      for(const e of n.edges){
    
        let k=[n.id,e.to].sort().join('|');
        if(done.has(k))
    {
          
          continue;
        }
        done.add(k);
        let t=graph.get(e.to);
        if(!t||t.f!=='Gelände')
    {
          
          continue;
        }
        h+=`<path d="M${n.pos.join(',')}L${t.pos.join(',')}" stroke="#a5b6c9" stroke-width="2.4" stroke-linecap="round" fill="none" opacity=".48"/>`
      }
    }
  }
 // Trees add orientation around the two parking areas.
  
  h+=drawStreetConnections();
  if(mapMode==='school'||editor.active)
  {
    
    for(const r of f.rooms){
    
      if(r.hidden||$('#important-only').checked&&!r.important&&!r.custom)
    {
        
        continue;
      }
      let p=r.pos;
      let major=['Sekretariat','Sporthalle','Foyer'].includes(r.code)||r.name.toLowerCase().includes('sekretariat');
      let label=major?(r.code.startsWith('A ')?'Sekretariat':r.code):r.code;
      h+=`<text class="room-label ${major?'major':''}" x="${p[0]}" y="${p[1]}" data-place="${esc(r.id)}" tabindex="0" role="button" aria-label="${esc(r.code)}">${esc(label)}</text>`
    }
  }
 // Wing badges are positioned outside room labels.
  if(mapMode==='school'||editor.active)
  {
    
    for(const [code,x,y]of [['A',390,770],['B',840,145],['C',900,1320],['D',1530,1200]]){
    
      let p=world(x,y);
      h+=`<g><circle cx="${p[0]}" cy="${p[1]}" r="7" fill="#263f59" stroke="#90a5bc" stroke-width=".5"/><text x="${p[0]}" y="${p[1]+2.2}" text-anchor="middle" fill="#bfd0e1" font-size="6" font-weight="700">${code}</text></g>`
    }
  }
  for(const p of places.filter(p=>p.outdoor&&!p.hidden&&placeInMode(p)&&(mapMode==='school'||editor.active||['bus','tip'].includes(p.category)||[selected?.id,start?.id,end?.id].includes(p.id)))){
    
    let [x,y]=p.pos,entry=p.category==='entrance',color=entry?'#5edbc1':p.category==='smoking'?'#e4bb6c':p.category==='parking'?'#85a7e0':p.category==='bicycle'?'#9cc689':'#74cbb8';
    h+=`<g class="poi" data-place="${esc(p.id)}" tabindex="0" role="button" aria-label="${esc(p.code)}"><title>${esc(p.code)}</title><circle cx="${x}" cy="${y}" r="${entry?4:8}" fill="${color}" stroke="#1f364c" stroke-width="1.3"/><text class="symbol" x="${x}" y="${y+.1}" style="font-size:${entry?5:9}px">${entry?'↪':esc(icons[p.category]||'•')}</text>${entry?'':`<text x="${x+11}" y="${y+2}">${esc(p.category==='gate'?'Zugang':p.code)}</text>`}</g>`
  }
  
  if(selected){
    
    let [x,y]=selected.pos;
    h+=`<circle cx="${x}" cy="${y}" r="10" fill="none" stroke="#68dfc8" stroke-width="1.3" stroke-dasharray="2 2" pointer-events="none"/>`
  }
  if(mapMode==='neighbourhood'&&!editor.active)
  {
    
    h+='<text data-school-overview="true" x="210" y="552" class="school-overview-label" text-anchor="middle">GSO Berufskolleg</text>';
  }
  h+=renderCustomLayers();
  h+=renderAddedScenery();
  h+=topStreetLabels();
  if(routePath){
    
    for(let i=1;i<routePath.length;i++){
      
      let a=routePath[i-1],b=routePath[i];
      if(a.f!==b.f)
      {
        
        continue;
      }
      if(a.f!==floor&&a.f!=='Gelände')
      {
        
        continue;
      }
      let d=`M${a.pos.join(',')}L${b.pos.join(',')}`;
      h+=`<path class="route-under" d="${d}"/><path class="route-line" d="${d}"/><path class="route-dash" d="${d}"/>`
    }
    for(const [i,n]of routePath.entries()){
      
      if(n.f!==floor&&n.f!=='Gelände')
      {
        
        continue;
      }
      if(i===0||i===routePath.length-1){
        
        h+=`<circle cx="${n.pos[0]}" cy="${n.pos[1]}" r="4" fill="${i===0?'#effffb':'#50e0c1'}" stroke="#0b806c" stroke-width="1.5"/>`
      }
      if(i&&routePath[i-1].f!==n.f)
      {
        
        h+=`<circle cx="${n.pos[0]}" cy="${n.pos[1]}" r="6" fill="#d8b56c"/><text class="transition-label" x="${n.pos[0]}" y="${n.pos[1]-9}">${esc(transitionLabel(routePath[i-1],n))} · ${esc(n.f)}</text>`
      }
    }
  }
  if(currentLocation&&(currentLocation.outdoor||currentLocation.floor===floor)){
    
    let [x,y]=currentLocation.pos;
    h+=`<g class="location-marker" pointer-events="none"><circle cx="${x}" cy="${y}" r="8" fill="#65b5ff" opacity=".2"/><circle cx="${x}" cy="${y}" r="3.5" fill="#49a8ff" stroke="white" stroke-width="1.4"/><title>Dein gewählter Standort</title></g>`
  }
  h+=indoorDoorOverlay();
  h+=editorOverlay();
  content.innerHTML=h;
  updateReferenceLabels();
  svg.setAttribute('aria-label',`Campuskarte ${floor}, Räume und Außenwege`);

}
