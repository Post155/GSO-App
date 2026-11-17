'use strict';
function placeInMode(p){
  
  return editor.active||mapMode==='school'||p.outdoor
}
function setMapMode(mode){
  
  if(!['school','neighbourhood'].includes(mode))
  {
    
    return;
  }
  mapMode=mode;
  selected=null;
  $('#place-card').hidden=true;
  editor.draft=null;
  base=[...(mode==='school'?SCHOOL_VIEW:NEIGHBOURHOOD_VIEW)];
  if(mode==='neighbourhood'){
    
    let r=svg.getBoundingClientRect(),ratio=r.width/Math.max(1,r.height),cx=base[0]+base[2]/2,cy=base[1]+base[3]/2;
    if(base[2]/base[3]<ratio)
    {
      
      base[2]=base[3]*ratio;
    }else 
    {
      
      base[3]=base[2]/ratio;
    }
    base[0]=cx-base[2]/2;
    base[1]=cy-base[3]/2
  }
  view=[...base];
  $('#view-campus').classList.toggle('active',mode==='school');
  $('#view-wide').classList.toggle('active',mode==='neighbourhood');
  $('#view-campus').setAttribute('aria-pressed',String(mode==='school'));
  $('#view-wide').setAttribute('aria-pressed',String(mode==='neighbourhood'));
  $('#mode-description').textContent=mode==='school'?'Schule · Räume und Eingänge':'Umgebung · Haltestellen und Tipps';
  $('.intro p').textContent='Dein Weg beginnt hier.';
  $('.section-title h2').textContent=mode==='school'?'Ziele entdecken':'In der Umgebung';
  $$('[data-neighbourhood]').forEach(b=>b.hidden=mode==='school');
  filter='all';
  $('#browse-search').value='';
  applyView();
  drawMap();
  renderList();
  updateEditor()
}
function setFloor(f){
  
  if(!['EG','OG'].includes(f))
  {
    
    return;
  }
  floor=f;
  $$('[data-floor]').forEach(b=>{
    
    b.classList.toggle('active',b.dataset.floor===f);
    b.setAttribute('aria-pressed',String(b.dataset.floor===f))
  });
  if(editor.active){
    
    editor.selection=null;
    editor.draft=null;
    updateEditor()
  }
  drawMap();
  renderList();
  renderDashboard()
}
function fit(){
  
  view=[...base];
  applyView()
}
function applyView(){
  
  svg.setAttribute('viewBox',view.join(' '));
  updateReferenceLabels()
}
function zoom(factor,cx=.5,cy=.5){
  
  if(!Number.isFinite(factor)||factor<=0)
  {
    
    return;
  }
  let w=Math.max(80,Math.min(6000,view[2]*factor)),ratio=w/view[2];
  view=[view[0]+view[2]*cx*(1-ratio),view[1]+view[3]*cy*(1-ratio),w,view[3]*ratio];
  applyView()
}
function referenceLabelSize(){
  
  let r=svg.getBoundingClientRect(),scale=Math.min(r.width/view[2],r.height/view[3]);
  return 11/Math.max(scale,.01)
}
function updateReferenceLabels(){
  
  let size=referenceLabelSize();
  svg.querySelectorAll('.road-name,.transition-label').forEach(el=>{
    
    el.style.fontSize=size*.9+'px';
    el.style.strokeWidth=size*.4+'px'
  });
  svg.querySelectorAll('[data-school-overview]').forEach(el=>{
    
    el.style.fontSize=size*1.2+'px';
    el.style.strokeWidth=size*.35+'px'
  })
}
function drawCourtyard(){
  
  return ''
}
function drawStreetConnections(){
  
  return ''
}
function drawSurroundings(){
  
  return completionBackground()
}
function areaD(a){
  
  if(a.edgeStyle==='rounded'||a.landscapeVersion===1)
  {
    
    return a.loops.map(l=>roundedAreaPath(l,a.landscapeVersion===1?18:Math.min(12,a.cornerRadius||6))).join(' ');
  }
  return a.loops.map(l=>'M'+l.map(p=>p.join(',')).join('L')+'Z').join(' ')
}
function renderScenery(s){
  
  if(s.kind==='tree'){
    
    let[x,y]=s.pos;
    return `<g pointer-events="none"><circle cx="${x+1}" cy="${y+2}" r="${s.radius}" fill="#153e34" opacity=".25"/><circle cx="${x}" cy="${y}" r="${s.radius}" fill="${s.color}"/></g>`
  }
  let d=s.kind==='footway'?roundedWalkPath(s.points,Math.min(s.width*.45,5)):'M'+s.points.map(p=>p.join(',')).join('L');
  return `<g pointer-events="none"><path d="${d}" fill="none" stroke="#263d51" stroke-width="${s.width+3}" stroke-linecap="round" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="${s.color}" stroke-width="${s.width}" stroke-linecap="round" stroke-linejoin="round"/>${s.kind==='road'&&s.width>=35?`<path d="${d}" fill="none" stroke="#b5c4ce" stroke-opacity=".55" stroke-width="1.1" stroke-dasharray="7 10"/>`:''}</g>`
}
function renderAddedScenery(){
  
  return editor.scenery.map(renderScenery).join('')
}
