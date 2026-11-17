'use strict';
function editSnapshot(){
  
  return {version:4,site:'gso-campus',navigationRevision:1,roomDefinitions:places.filter(p=>!p.outdoor&&!p.custom).map(p=>({id:p.id,floor:p.floor,building:p.building||p.code[0],important:p.important!==false})),points:Object.fromEntries(places.map(p=>[p.id,[...p.pos]])),pointNodes:Object.fromEntries(places.map(p=>[p.id,p.node||null])),pointMeta:Object.fromEntries(places.map(p=>[p.id,{code:p.code,name:p.name,category:p.category,building:p.building||'',important:p.important!==false}])),customPlaces:places.filter(p=>p.custom).map(p=>({id:p.id,code:p.code,name:p.name,category:p.category,floor:p.floor,outdoor:p.outdoor})),hiddenPoints:places.filter(p=>p.hidden).map(p=>p.id),areas:clone(editor.areas),nodes:[...graph.values()].map(n=>({id:n.id,pos:[...n.pos],f:n.f,edges:n.edges.map(e=>({to:e.to,type:e.type,verified:!!e.verified}))})),scenery:editor.scenery.map(s=>({...clone(s),linkedNodes:s.linkedNodes?.map(id=>graph.has(id)?id:null)}))}
}
/** Reconcile catalogue additions/removals without resetting the user's existing geometry. */
function reconcileCatalogue(raw){
 
  const r=clone(raw),originalIDs=new Set(editor.originalPlaces.map(p=>p.id));
  r.customPlaces=r.customPlaces.filter(p=>!originalIDs.has(p.id));
  const allowed=new Set([...originalIDs,...r.customPlaces.map(p=>p.id)]),nodeIDs=new Set(r.nodes.map(n=>n.id));
  for(const id of originalIDs){
    if(!Object.hasOwn(r.points,id)){
      r.points[id]=clone(editor.baseline.points[id]);
      r.pointMeta[id]=clone(editor.baseline.pointMeta[id]);
      const node=editor.baseline.pointNodes[id];
      r.pointNodes[id]=nodeIDs.has(node)?node:null
    }
  }
  for(const id of Object.keys(r.points)){
    if(!allowed.has(id)){
      delete r.points[id];
      delete r.pointMeta[id];
      delete r.pointNodes[id]
    }
  }
  r.hiddenPoints=r.hiddenPoints.filter(id=>allowed.has(id));
  if(r.roomDefinitions){
    r.roomDefinitions=r.roomDefinitions.filter(d=>originalIDs.has(d.id))
  }
  return r;
}
function validEdit(raw){
 
  if(!raw||![1,2,3,4].includes(raw.version)||raw.site!=='gso-campus'||!Array.isArray(raw.nodes)||!raw.points){
    throw Error('Unvollständiger oder unbekannter Kartenexport.')
  }
  let normalized=clone(raw);
  if(normalized.version<4){
    const defaults=editor.baseline;
    normalized={customPlaces:[],hiddenPoints:[],areas:clone(defaults.areas),scenery:clone(defaults.scenery),pointNodes:clone(defaults.pointNodes),pointMeta:clone(defaults.pointMeta),...normalized}
  }
  if(!Array.isArray(normalized.areas)||!Array.isArray(normalized.customPlaces)||!Array.isArray(normalized.hiddenPoints)||!normalized.pointNodes||!normalized.pointMeta){
    throw Error('Unvollständiger Kartenexport.')
  }
  return Config.validate(reconcileCatalogue(upgradeNavigation(upgradeOutlines(normalized))),editor.baseline,editor.originalPlaces)
}
/** Preserve endpoints by ID, rather than retaining stale objects after import/undo. */
function restoreEdit(raw){
  
  const snapshot=validEdit(raw),startID=start?.id,endID=end?.id;
  editor.areas=snapshot.areas;
  editor.scenery=snapshot.scenery;
  places=editor.originalPlaces.map(p=>({...p,...snapshot.roomDefinitions?.find(r=>r.id===p.id)}));
  for(const p of snapshot.customPlaces)
  {
    
    places.push({...p,custom:true});
  }
  for(const p of places){
    
    p.pos=[...snapshot.points[p.id]];
    p.node=snapshot.pointNodes[p.id];
    p.hidden=snapshot.hiddenPoints.includes(p.id);
    Object.assign(p,snapshot.pointMeta[p.id])
  }
  outside=places.filter(p=>p.outdoor);
  graph.clear();
  for(const n of snapshot.nodes)
  {
    
    graph.set(n.id,{...n,edges:n.edges.map(e=>({...e,cost:0}))});
  }
  start=places.find(p=>p.id===startID&&!p.hidden)||null;
  end=places.find(p=>p.id===endID&&!p.hidden)||null;
  if(currentLocation)
  {
    
    currentLocation=places.find(p=>p.id===currentLocation.id&&!p.hidden)||null;
  }
  selected=null;
  syncFloorRooms();
  reweight();
  refreshRoutingConstraints();
  routePath=null;
  routeChoices=[];
  $('#route-result').hidden=true;
  $('#start').value=start?start.code:'';
  $('#end').value=end?end.code:'';
  $('#route').disabled=!(start&&end);
  editor.selection=null;
  editor.draft=null;
  drawMap();
  renderList();
  updateEditor();
  renderDashboard()
}
function initEditor(){
  
  editor.originalPlaces=places.map(p=>({...p}));
  editor.baseline=clone(completedData);
  let saved=null,error=null;
  try{
    
    let text=localStorage.getItem(EDIT_KEY);
    if(text)
    {
      
      saved=JSON.parse(text)
    }
  }catch(e){
    
    error=e
  }
  try{
    
    restoreEdit(saved||completedData)
  }catch(e){
    
    error=e;
    restoreEdit(completedData)
  }
  editor.undo=[];
  editor.redo=[];
  editor.dirty=false;
  editor.saved=saved&&!error?editSnapshot():null;
  editor.message=error?'Lokaler Stand konnte nicht gelesen werden. Er bleibt erhalten; bitte exportierte JSON prüfen.':saved?'Lokale Anpassungen geladen.':'Kartenstand geladen.';
  bindEditorControls();
  editor.referenceKind='new-map';
  $('#dev-reference-kind').innerHTML='<option value="new-map">Neue Region – Karte</option><option value="pdf-eg">Bauplan Erdgeschoss</option><option value="pdf-og">Bauplan Obergeschoss</option>';
  $('#dev-reference-kind').value='new-map';
  $('#workspace-templates').onclick=()=>{
    
    setEditor(true);
    editor.reference=!editor.reference;
    $('#dev-reference').checked=editor.reference;
    updateEditor();
    drawMap()
  };
  $('#dev-previous').hidden=true;
  setEditor(false)
}
function downloadJSON(value,name){
  
  let url=URL.createObjectURL(new Blob([JSON.stringify(value,null,2)],{type:'application/json'}));
  let a=document.createElement('a');
  a.href=url;
  a.download=name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1000)
}
