'use strict';
// Editor operations. Named helpers replace the former runtime override chain.

const EDIT_KEY='gso-campus-completed-workspace-v1';

const editor={active:false,tool:'points',scope:'Gelände',selection:null,reference:false,opacity:.4,undo:[],redo:[],baseline:null,saved:null,drag:null,dirty:false,serial:0,message:''};

Object.assign(editor,{areas:[],customPlaces:[],originalPlaces:[],draft:null,cataloguing:false,referenceKind:'marked'});

const areaColors={green:'#496456',building:'#506579',paving:'#7b8992',parking:'#526777',mask:'#20364e',blocked:'#bb655f'};

Object.assign(editor,{scenery:[],collectScenery:false});

function reweight(){
  
  for(const n of graph.values())
  {
    
    for(const e of n.edges){
    
      const other=graph.get(e.to);
      e.cost=Math.hypot(n.pos[0]-other.pos[0],n.pos[1]-other.pos[1])+(e.type==='stairs'?25:0)
    }
  }
}

function remember(before){
  
  editor.undo.push(before);
  if(editor.undo.length>20)
  {
    
    editor.undo.shift();
  }
  editor.redo=[];
  editor.dirty=true;
  editor.message='Ungespeicherte Änderungen';
  updateEditor()
}

function editChangedBase1(before){
  
  reweight();
  refreshRoutingConstraints();
  if(routePath&&start&&end)
  {
    
    routePath=shortest(start.node,end.node,$('#accessible').checked);
  }
  remember(before);
  drawMap();
  updateEditor()
}

function editChanged(before){
  
  let hadRoute=!!routePath;
  editChangedBase1(before);
  syncFloorRooms();
  renderDashboard();
  if(hadRoute&&start&&end)
  {
    
    planRoute()
  }
}

function editFloor(){
  
  return editor.scope==='Gelände'?'Gelände':floor
}

function editVisible(item){
  
  return item.f===editFloor()
}

function editKey(a,b){
  
  return [a,b].sort().join('|')
}

function editorOverlayBase1(){
  
  if(!editor.active)
  {
    
    return '';
  }
  let h='';
  if(editor.reference)
  {
    
    h+=`<defs><clipPath id="source-clip"><rect x="0" y="70" width="565" height="780"/></clipPath></defs><image href="assets/Schule-Wege.png" x="0" y="0" width="565" height="850" opacity="${editor.opacity}" clip-path="url(#source-clip)" pointer-events="none"/>`;
  }
  if(editor.tool==='points'){
  
    for(const p of places){
      
      if(p.hidden)
      {
        
        continue;
      }
      if((p.outdoor?'Gelände':p.floor)!==editFloor())
      {
        
        continue;
      }
      const active=editor.selection?.kind==='point'&&editor.selection.id===p.id;
      h+=`<g class="dev-point ${active?'is-selected':''}" data-edit-kind="point" data-edit-id="${esc(p.id)}" tabindex="0" role="button" aria-label="${esc(p.code)} verschieben"><title>${esc(p.code)} · Ziehen oder Pfeiltasten</title><circle class="dev-hit" cx="${p.pos[0]}" cy="${p.pos[1]}" r="8"/><circle class="dev-point-ring" cx="${p.pos[0]}" cy="${p.pos[1]}" r="${active?5.7:4.2}"/>${active?`<text class="dev-map-label" x="${p.pos[0]+9}" y="${p.pos[1]-8}">${esc(p.code)}</text>`:''}</g>`
    }
  }else{
  
    let seen=new Set();
    for(const n of graph.values())
    {
      
      if(editVisible(n))
    {
        
        for(const e of n.edges){
      
          const other=graph.get(e.to),key=editKey(n.id,e.to);
          if(!editVisible(other)||seen.has(key)||Math.hypot(n.pos[0]-other.pos[0],n.pos[1]-other.pos[1])<.1)
      {
            
            continue;
          }
          seen.add(key);
          let active=editor.selection?.kind==='edge'&&editor.selection.id===key;
          h+=`<g class="dev-edge ${active?'is-selected':''}" data-edit-kind="edge" data-edit-id="${esc(key)}" role="button" tabindex="0" aria-label="Wegstück verschieben oder Wegpunkt einfügen"><title>Ziehen: Wegstück verschieben · Doppelklick: Wegpunkt einfügen</title><path class="dev-edge-hit" d="M${n.pos.join(',')}L${other.pos.join(',')}"/><path class="dev-edge-line" d="M${n.pos.join(',')}L${other.pos.join(',')}"/></g>`
        }
      }
    }
    for(const n of graph.values())
    {
      
      if(editVisible(n)){
      
        let active=editor.selection?.kind==='node'&&editor.selection.id===n.id;
        h+=`<g class="dev-node ${active?'is-selected':''}" data-edit-kind="node" data-edit-id="${esc(n.id)}" tabindex="0" role="button" aria-label="Wegpunkt ${esc(n.id)} verschieben"><title>${esc(n.id)}</title><circle class="dev-hit" cx="${n.pos[0]}" cy="${n.pos[1]}" r="6.5"/><circle class="dev-node-ring" cx="${n.pos[0]}" cy="${n.pos[1]}" r="${active?4.3:2.7}"/></g>`
      }
    }
  }
  return '<g id="editor-overlay">'+h+'</g>'
}

function editorOverlayBase2(){
  
  if(!editor.active)
  {
    
    return '';
  }
  let originalTool=editor.tool,ref=editor.reference;
  editor.reference=ref&&editor.referenceKind==='marked';
  if(originalTool==='areas')
  {
    
    editor.tool='none';
  }
  let h=originalTool==='areas'?'':editorOverlayBase1();
  editor.tool=originalTool;
  editor.reference=ref;
  
  if(originalTool==='areas'){
    
    
    for(const a of editor.areas)
    {
      
      if(a.f===editFloor()){
      
        let active=['area','vertex'].includes(editor.selection?.kind)&&(editor.selection.id===a.id||editor.selection.id.startsWith(a.id+'|'));
        h+=`<path data-edit-kind="area" data-edit-id="${esc(a.id)}" class="dev-area ${active?'is-selected':''}" d="${areaD(a)}"><title>${esc(a.name)}</title></path>`;
        if(active)
      {
          
          for(let li=0;li<a.loops.length;li++)
      {
            
            for(let vi=0;vi<a.loops[li].length;vi++){
        
              let p=a.loops[li][vi];
              h+=`<g data-edit-kind="vertex" data-edit-id="${a.id}|${li}|${vi}" class="dev-node"><circle class="dev-hit" cx="${p[0]}" cy="${p[1]}" r="6"/><circle class="dev-node-ring" cx="${p[0]}" cy="${p[1]}" r="2.7"/></g>`
            }
          }
        }
      }
    }
  }
  if(editor.draft?.kind==='area'&&editor.draft.points.length){
    
    let p=editor.draft.points;
    h+=`<polyline points="${p.map(p=>p.join(',')).join(' ')}" class="dev-draft-line"/>`+p.map((p,i)=>`<circle cx="${p[0]}" cy="${p[1]}" r="${i?3:5}" fill="${i?'#ffe4a2':'#81edc8'}" data-draft-close="${i===0}"/>`).join('')
  }
  return h
}

function editorOverlay(){
  
  if(!editor.active)
  {
    
    return '';
  }
  let original=editor.tool,h='';
  if(original==='roads'||original==='trees'){
    
    let ref=editor.reference;
    editor.reference=false;
    editor.tool='points';
    h='';
    editor.tool=original;
    editor.reference=ref;
    for(const s of editor.scenery.filter(s=>original==='trees'?s.kind==='tree':s.kind!=='tree')){
      
      let active=selectedScenery()?.id===s.id;
      if(s.kind==='tree')
      {
        
        h+=`<g data-edit-kind="scenery" data-edit-id="${esc(s.id)}" class="dev-node"><title>${esc(s.name)}</title><circle class="dev-hit" cx="${s.pos[0]}" cy="${s.pos[1]}" r="${s.radius+5}"/><circle cx="${s.pos[0]}" cy="${s.pos[1]}" r="${s.radius}" class="dev-tree-ring ${active?'is-selected':''}"/></g>`;
      }else{
        
        h+=`<path class="dev-road-hit ${active?'is-selected':''}" data-edit-kind="scenery" data-edit-id="${esc(s.id)}" d="M${s.points.map(p=>p.join(',')).join('L')}"/>`;
        if(active)
        {
          
          s.points.forEach((p,i)=>h+=`<g class="dev-node" data-edit-kind="scenery-vertex" data-edit-id="${esc(s.id)}|${i}"><circle class="dev-hit" cx="${p[0]}" cy="${p[1]}" r="7"/><circle class="dev-node-ring" cx="${p[0]}" cy="${p[1]}" r="3"/></g>`)
        }
      }
    }
  }else 
  {
    
    h=editorOverlayBase2();
  }
  if(editor.reference&&['pdf-eg','pdf-og'].includes(editor.referenceKind)){
    
    let m=data.registration.matrix,o=data.registration.offset,og=editor.referenceKind==='pdf-og';
    h=`<g opacity="${editor.opacity}" pointer-events="none" transform="matrix(${m[0][0]} ${m[1][0]} ${m[0][1]} ${m[1][1]} ${o[0]} ${o[1]})"><g transform="translate(${og?78.5:0} 0)"><image href="assets/Vorlage-${og?'OG':'EG'}.png" width="2100" height="1486"/></g></g>`+h
  }
  if(editor.reference&&editor.referenceKind.startsWith('new-')){
    
    let key=editor.referenceKind.slice(4),src=key==='detail'?'Referenz-Detail.png':key==='streets'?'Referenz-Strassen.png':key==='map'?'Referenz-Karte.png':'Referenz-Region.png',transform=(key==='detail'||key==='streets')?'matrix(.5 0 0 .5 194 403.5)':'matrix(2.48 0 0 2.48 -1750 -840)';
    h=`<g transform="${transform}" opacity="${editor.opacity}" pointer-events="none"><image href="assets/${src}" width="1702" height="913"/></g>`+h
  }
  if(['road','footway'].includes(editor.draft?.kind)&&editor.draft.points.length)
  {
    
    h+=`<polyline class="dev-draft-line" points="${editor.draft.points.map(p=>p.join(',')).join(' ')}"/>`;
  }
  return h
}

function updateEditorBase1(){
  
  if(!editor.baseline)
  {
    
    return;
  }
  $('#workspace-templates').setAttribute('aria-pressed',String(editor.reference));
  $('#dev-panel').hidden=!editor.active;
  $('#dev-toggle').setAttribute('aria-pressed',String(editor.active));
  $('#dev-toggle').classList.toggle('active',editor.active);
  $('.map-panel').classList.toggle('editing',editor.active);
  $('#dev-undo').disabled=!editor.undo.length;
  $('#dev-redo').disabled=!editor.redo.length;
  $('#dev-save').disabled=!editor.dirty;
  $('#dev-carry-label').hidden=editor.tool!=='points';
  $('#dev-opacity-label').hidden=!editor.reference;
  $('#dev-status').textContent=editor.message||'Noch keine lokalen Anpassungen.';
  $('#dev-help').textContent=editor.tool==='points'?'Kreise ziehen, um Ziele zu platzieren. Auf freien Flächen verschiebst du weiterhin die Karte.':'Kleine Kreise oder ganze Wegstücke ziehen. Doppelklick auf einen Weg fügt einen Wegpunkt ein.';
  let sel=editor.selection,label='Kein Punkt ausgewählt',pos=null;
  if(sel?.kind==='point'){
    
    let p=places.find(p=>p.id===sel.id);
    if(p){
      
      label=p.code;
      pos=p.pos
    }
  }
  if(sel?.kind==='node'){
    
    let n=graph.get(sel.id);
    if(n){
      
      label='Wegpunkt · '+n.id;
      pos=n.pos
    }
  }
  if(sel?.kind==='edge')
  {
    
    label='Wegstück ausgewählt';
  }
  $('#dev-selection').textContent=label;
  $('#dev-coordinates').textContent=pos?`X ${pos[0].toFixed(1)} · Y ${pos[1].toFixed(1)} · Pfeiltasten zum Feinjustieren`:'Tipp: Zum genauen Platzieren hineinzoomen.';
  $('#dev-split').hidden=sel?.kind!=='edge';
  $('#dev-delete').hidden=!(sel?.kind==='node'&&sel.id.startsWith('dev-')&&graph.get(sel.id)?.edges.length===2);
  $$('[data-dev-tool]').forEach(b=>b.classList.toggle('active',b.dataset.devTool===editor.tool))
}

function updateEditorBase2(){
  
  updateEditorBase1();
  if(!editor.baseline)
  {
    
    return;
  }
  $('#dev-area-pick-label').hidden=editor.tool!=='areas';
  if(document.activeElement?.id!=='dev-area-pick'){
    
    $('#dev-area-pick').innerHTML='<option value="">Fläche auswählen</option>'+editor.areas.filter(a=>a.f===editFloor()).map(a=>`<option value="${esc(a.id)}">${esc(a.name)}</option>`).join('');
    $('#dev-area-pick').value=selectedArea()?.id||''
  }
  $('#dev-delete').hidden=!editor.selection;
  $('#dev-delete').textContent=({vertex:'Eckpunkt löschen',edge:'Wegstück löschen',node:'Wegpunkt & Anschlüsse löschen',point:'Markierung löschen',area:'Fläche löschen'})[editor.selection?.kind]||'Auswahl löschen';
  $('#dev-add-vertex').hidden=!selectedArea();
  $('#dev-properties').hidden=!(selectedArea()||currentPoint());
  $('#dev-finish').hidden=!editor.draft;
  $('#dev-pop-draft').hidden=editor.draft?.kind!=='area';
  $('#dev-new-path').classList.toggle('active',editor.draft?.kind==='path');
  $('#dev-new-area').classList.toggle('active',editor.draft?.kind==='area');
  $('#dev-new-point').classList.toggle('active',editor.draft?.kind==='point');
  $('#dev-connection').hidden=editor.selection?.kind!=='node';
  $('#dev-area-fields').hidden=!selectedArea();
  $('#dev-point-fields').hidden=!currentPoint();
  $('#dev-new-area').hidden=editor.tool!=='areas';
  $('#dev-new-point').hidden=editor.tool!=='points';
  $('#dev-new-path').hidden=editor.tool!=='paths';
  if(editor.tool==='areas')
  {
    
    $('#dev-help').textContent='Flächen auswählen und ziehen. Die gelben Eckpunkte ändern die Form. „Neue Fläche“: Rand durch Klicks zeichnen und abschließen.';
  }
  if(editor.draft)
  {
    
    $('#dev-help').textContent=editor.draft.kind==='path'?'Auf vorhandene Wegpunkte oder freie Stellen klicken. Jeder weitere Klick verlängert den Weg. Mit „Fertig“ beenden.':editor.draft.kind==='area'?'Klicke nacheinander die Eckpunkte an. Zum Schließen den ersten Punkt anklicken oder „Fertig“ wählen.':'Klicke auf die Karte, um die neue Markierung zu platzieren.';
  }
  let a=selectedArea(),p=currentPoint();
  if(a){
    
    $('#dev-selection').textContent=a.name;
    $('#dev-coordinates').textContent=`${a.loops.reduce((s,l)=>s+l.length,0)} Eckpunkte · ${a.blocked?'Sperrfläche':'Darstellungsfläche'}`
  }
 // Avoid overwriting a form while its field is being edited.
  if(p)
  {
    
    $('#dev-point-node').textContent=p.node&&graph.has(p.node)?'Zugehörigen Wegpunkt bearbeiten':'Wegpunkt am Ziel anlegen';
  }
  if(a||p){
    
    let focus=document.activeElement;
    if(!focus?.closest?.('#dev-properties')){
      
      let item=a||p;
      $('#dev-name').value=a?a.name:p.code;
      $('#dev-color').value=a?a.color:'#6bc7ad';
      $('#dev-area-opacity').value=a?Math.round(a.opacity*100):100;
      $('#dev-area-kind').value=a?a.kind:'paving';
      $('#dev-blocked').checked=!!a?.blocked;
      $('#dev-category').value=p?p.category:'marker';
      $('#dev-description').value=p?p.name:''
    }
  }
  if(editor.selection?.kind==='node'&&document.activeElement?.id!=='dev-link-target'){
    
    let n=graph.get(editor.selection.id);
    $('#dev-link-target').innerHTML='<option value="">Ziel-Wegpunkt wählen</option>'+[...graph.values()].filter(x=>x.id!==n.id).map(x=>`<option value="${esc(x.id)}">${esc(x.f+' · '+(places.find(p=>p.node===x.id)?.code||x.id))}</option>`).join('')
  }
}

function updateEditor(){
  
  updateEditorBase2();
  if(!editor.baseline)
  {
    
    return;
  }
  let s=selectedScenery(),tool=editor.tool;
  $('#dev-scope-label').hidden=['roads','trees'].includes(tool);
  $('.floor-control').hidden=mapMode==='neighbourhood'&&!editor.active;
  $('#dev-scenery-fields').hidden=!s;
  $('#dev-scenery-pick-label').hidden=!['roads','trees'].includes(tool);
  $('#dev-new-tree').hidden=tool!=='trees';
  $('#dev-new-road').hidden=tool!=='roads';
  $('#dev-new-footway').hidden=tool!=='roads';
  $('#dev-road-vertex').hidden=!(s&&s.kind!=='tree');
  $('#dev-road-to-path').hidden=!(s&&s.kind==='footway');
  if(document.activeElement?.id!=='dev-scenery-pick'){
    
    $('#dev-scenery-pick').innerHTML='<option value="">Element auswählen</option>'+editor.scenery.filter(s=>tool==='trees'?s.kind==='tree':s.kind!=='tree').map(s=>`<option value="${esc(s.id)}">${esc(s.name||s.kind==='tree'&&'Baum'||'Weglinie')} · ${esc(s.id)}</option>`).join('');
    $('#dev-scenery-pick').value=s?.id||''
  }
  if(s){
    
    $('#dev-selection').textContent=s.name||'Zeichenelement';
    $('#dev-coordinates').textContent=s.kind==='tree'?'Baum verschieben oder Kronenradius ändern.':'Straße verschieben; gelbe Punkte ändern den Verlauf.';
    $('#dev-delete').hidden=false;
    $('#dev-delete').textContent=s.kind==='tree'?'Baum löschen':'Linie / Auswahl löschen';
    if(!document.activeElement?.closest?.('#dev-scenery-fields')){
      
      $('#dev-scene-name').value=s.name;
      $('#dev-scene-color').value=s.color;
      $('#dev-scene-size').value=s.kind==='tree'?s.radius:s.width;
      $('#dev-scene-kind').value=s.kind;
      $('#dev-scene-kind').disabled=s.kind==='tree';
      $('#dev-scene-label').checked=s.label!==false
    }
  }
  if(tool==='trees')
  {
    
    $('#dev-help').textContent='Vorhandene Bäume auswählen und verschieben. Neue Bäume per Klick setzen; Größe und Farbe unten ändern.';
  }
  if(tool==='roads')
  {
    
    $('#dev-help').textContent='Straßen und Gehwege sind Zeichenelemente. Linien ziehen, Verlaufspunkte verschieben oder neue Linien zeichnen. Gehwege lassen sich ausdrücklich ins Wegenetz übernehmen.';
  }
  if(['tree','road','footway'].includes(editor.draft?.kind)){
    
    $('#dev-finish').hidden=editor.draft.kind==='tree';
    $('#dev-cancel-draft').hidden=false;
    $('#dev-help').textContent=editor.draft.kind==='tree'?'Klicke auf die Karte, um einen Baum zu setzen. Danach kannst du ihn verschieben oder seine Größe ändern.':'Klicke nacheinander den Linienverlauf an und wähle „Fertig“. Erst „Als Gehweg ins Wegenetz übernehmen“ macht die Linie routbar.'
  }
}

function setEditorBase1(active){
  
  if(editor.drag)
  {
    
    finishEditDrag();
  }
  editor.active=active;
  editor.selection=null;
  $('#place-card').hidden=true;
  if(active&&innerWidth<=700)
  {
    
    $('.sidebar').classList.remove('open');
  }
  updateEditor();
  drawMap()
}

function setEditor(active){
  
  if(active)
  {
    
    openView('map');
  }else 
  {
    
    editor.draft=null;
  }
  setEditorBase1(active);
  renderList()
}

function mapPoint(e){
  
  let p=new DOMPoint(e.clientX,e.clientY).matrixTransform(svg.getScreenCTM().inverse());
  return [p.x,p.y]
}
/** Group colocated junctions to preserve graph topology during dragging. */
function sameLocation(ids,snapshot){
  
  let out=new Set(ids);
  for(const id of ids){
    
    let n=snapshot.nodes.find(n=>n.id===id);
    if(!n)
    {
      
      continue;
    }
    for(const other of snapshot.nodes)
    {
      
      if(other.f===n.f&&Math.hypot(other.pos[0]-n.pos[0],other.pos[1]-n.pos[1])<.2)
    {
        
        out.add(other.id)
      }
    }
  }
  return [...out]
}

function moveEditSelectionBase1(selection,dx,dy,before){
 
  if(selection.kind==='point'){
  
    let p=places.find(p=>p.id===selection.id),pos=before.points[p.id];
    p.pos=[pos[0]+dx,pos[1]+dy];
    if($('#dev-carry').checked&&p.node){
      
      for(const id of sameLocation([p.node],before)){
        
        let old=before.nodes.find(n=>n.id===id),n=graph.get(id);
        if(old&&n)
        {
          
          n.pos=[old.pos[0]+dx,old.pos[1]+dy]
        }
      }
    }
  }else{
  
    let ids=selection.kind==='node'?[selection.id]:selection.id.split('|');
    ids=sameLocation(ids,before);
    for(const id of ids){
      
      let old=before.nodes.find(n=>n.id===id),n=graph.get(id);
      if(old&&n)
      {
        
        n.pos=[old.pos[0]+dx,old.pos[1]+dy]
      }
    }
    for(const p of outside){
      
      let old=before.nodes.find(n=>n.id===p.node),pos=before.points[p.id];
      if(ids.includes(p.node)&&old&&Math.hypot(old.pos[0]-pos[0],old.pos[1]-pos[1])<2)
      {
        
        p.pos=[pos[0]+dx,pos[1]+dy]
      }
    }
  }
}

function moveEditSelectionBase2(sel,dx,dy,before){
  
  if(sel.kind==='area'||sel.kind==='vertex'){
    
    let id=sel.kind==='area'?sel.id:sel.id.split('|')[0],a=editor.areas.find(a=>a.id===id),old=before.areas.find(a=>a.id===id);
    a.loops=JSON.parse(JSON.stringify(old.loops));
    if(sel.kind==='area')
    {
      
      a.loops=a.loops.map(l=>l.map(p=>[p[0]+dx,p[1]+dy]));
    }else{
      
      let [,li,vi]=sel.id.split('|'),p=a.loops[+li][+vi];
      p[0]+=dx;
      p[1]+=dy
    }
    return
  }
  moveEditSelectionBase1(sel,dx,dy,before);
  if(sel.kind==='node'||sel.kind==='edge'){
    
    let ids=sameLocation(sel.kind==='node'?[sel.id]:sel.id.split('|'),before);
    for(const p of places.filter(p=>p.custom&&p.outdoor)){
      
      let old=before.nodes.find(n=>n.id===p.node),pos=before.points[p.id];
      if(ids.includes(p.node)&&old&&Math.hypot(old.pos[0]-pos[0],old.pos[1]-pos[1])<2)
      {
        
        p.pos=[pos[0]+dx,pos[1]+dy]
      }
    }
  }
}

function moveEditSelection(sel,dx,dy,before){
  
  if(['scenery','scenery-vertex'].includes(sel.kind)){
    
    let id=sel.id.split('|')[0],s=editor.scenery.find(s=>s.id===id),old=before.scenery.find(s=>s.id===id);
    if(s.kind==='tree')
    {
      
      s.pos=[old.pos[0]+dx,old.pos[1]+dy];
    }else{
      
      s.points=old.points.map(p=>[...p]);
      if(sel.kind==='scenery')
      {
        
        s.points=s.points.map(p=>[p[0]+dx,p[1]+dy]);
      }else{
        
        let i=+sel.id.split('|')[1];
        s.points[i][0]+=dx;
        s.points[i][1]+=dy
      }
      if(s.linkedNodes)
      {
        
        for(let i=0;i<s.points.length;i++)
      {
          
          if(s.linkedNodes[i]&&graph.has(s.linkedNodes[i]))
      {
            
            graph.get(s.linkedNodes[i]).pos=[...s.points[i]];
          }
        }
      }
      for(const p of places.filter(p=>p.outdoor)){
        
        let oldNode=before.nodes.find(n=>n.id===p.node),now=graph.get(p.node);
        if(oldNode&&now&&s.linkedNodes?.includes(p.node)&&Math.hypot(before.points[p.id][0]-oldNode.pos[0],before.points[p.id][1]-oldNode.pos[1])<2)
        {
          
          p.pos=[...now.pos]
        }
      }
    }
    return
  }
  moveEditSelectionBase2(sel,dx,dy,before)
}

function beginEditDragBase1(e){
  
  if(!editor.active||e.button>0||e.isPrimary===false)
  {
    
    return;
  }
  let hit=e.target.closest('[data-edit-kind]');
  if(!hit)
  {
    
    return;
  }
  e.preventDefault();
  e.stopImmediatePropagation();
  editor.selection={kind:hit.dataset.editKind,id:hit.dataset.editId};
  editor.drag={pointer:e.pointerId,start:mapPoint(e),client:[e.clientX,e.clientY],before:editSnapshot(),selection:{...editor.selection},moved:false};
  svg.setPointerCapture(e.pointerId);
  updateEditor();
  drawMap()
}

function beginEditDragBase2(e){
  
  if(!editor.active)
  {
    
    return;
  }
  if(editor.draft){
    
    if(e.button>0)
    {
      
      return;
    }
    e.preventDefault();
    e.stopImmediatePropagation();
    let pos=mapPoint(e);
    if(editor.draft.kind==='point')
    {
      
      addTargetAt(pos);
    }else 
    {
      
      if(editor.draft.kind==='path')
    {
        
        pathClick(pos,e.target.closest('[data-edit-kind]'));
      }else{
      
        if(editor.draft.points.length>=3&&Math.hypot(pos[0]-editor.draft.points[0][0],pos[1]-editor.draft.points[0][1])<Math.max(4,view[2]/svg.getBoundingClientRect().width*10))
      {
          
          finishDraft();
        }else{
        
          editor.draft.points.push(pos);
          updateEditor();
          drawMap()
        }
      }
    }
    return
  }
  beginEditDragBase1(e)
}

function beginEditDrag(e){
  
  if(editor.active&&['tree','road','footway'].includes(editor.draft?.kind)){
    
    if(e.button>0)
    {
      
      return;
    }
    e.preventDefault();
    e.stopImmediatePropagation();
    let pos=mapPoint(e);
    if(editor.draft.kind==='tree'){
      
      let before=editSnapshot(),s={id:devId('tree'),kind:'tree',name:'Neuer Baum',pos,radius:7,color:'#4f765f',f:'Gelände',builtin:false};
      editor.scenery.push(s);
      editor.selection={kind:'scenery',id:s.id};
      editor.draft=null;
      editChanged(before)
    }else{
      
      editor.draft.points.push(pos);
      drawMap();
      updateEditor()
    }
    return
  }
  beginEditDragBase2(e)
}

function moveEditDrag(e){
  
  let d=editor.drag;
  if(!d||e.pointerId!==d.pointer)
  {
    
    return;
  }
  e.preventDefault();
  e.stopImmediatePropagation();
  let p=mapPoint(e);
  if(Math.hypot(e.clientX-d.client[0],e.clientY-d.client[1])>2)
  {
    
    d.moved=true;
  }
  if(!d.moved)
  {
    
    return;
  }
  moveEditSelection(d.selection,p[0]-d.start[0],p[1]-d.start[1],d.before);
  if(['area','vertex'].includes(d.selection.kind)){
    backgroundCache=null
  }
  scheduleDraw();
  $('#dev-coordinates').textContent='X '+p[0].toFixed(1)+' · Y '+p[1].toFixed(1)
}

function finishEditDragBase1(e){
  
  let d=editor.drag;
  if(!d||e&&e.pointerId!==d.pointer)
  {
    
    return;
  }
  if(e){
    
    e.preventDefault();
    e.stopImmediatePropagation()
  }
  editor.drag=null;
  if(svg.hasPointerCapture(d.pointer))
  {
    
    svg.releasePointerCapture(d.pointer);
  }
  if(d.moved){
    
    moved=true;
    editChanged(d.before)
  }else{
    
    drawMap();
    updateEditor()
  }
}

function finishEditDrag(e){
  
  let d=editor.drag;
  if(d?.moved&&['area','vertex'].includes(d.selection.kind)){
    
    let id=d.selection.id.split('|')[0],a=editor.areas.find(a=>a.id===id);
    if(a&&!a.builtin&&a.loops.some(l=>!simpleLoop(l))){
      
      editor.drag=null;
      if(svg.hasPointerCapture(d.pointer))
      {
        
        svg.releasePointerCapture(d.pointer);
      }
      restoreEdit(d.before);
      editor.message='Verschieben zurückgenommen: Die Fläche darf sich nicht überkreuzen.';
      updateEditor();
      if(e){
        
        e.preventDefault();
        e.stopImmediatePropagation()
      }
      return
    }
  }
  finishEditDragBase1(e)
}

function cancelEditDrag(e){
  
  let d=editor.drag;
  if(!d||e.pointerId!==d.pointer)
  {
    
    return;
  }
  e.stopImmediatePropagation();
  editor.drag=null;
  if(svg.hasPointerCapture(d.pointer))
  {
    
    svg.releasePointerCapture(d.pointer);
  }
  restoreEdit(d.before);
  editor.message='Verschieben abgebrochen';
  updateEditor()
}

function splitEditEdge(point){
  
  let sel=editor.selection;
  if(sel?.kind!=='edge')
  {
    
    return;
  }
  let [a,b]=sel.id.split('|'),x=graph.get(a),y=graph.get(b);
  if(!x||!y||x.f!==y.f||!x.edges.some(e=>e.to===b))
  {
    
    return;
  }
  let before=editSnapshot(),pos=point||[(x.pos[0]+y.pos[0])/2,(x.pos[1]+y.pos[1])/2];
  if(point){
    
    let dx=y.pos[0]-x.pos[0],dy=y.pos[1]-x.pos[1],l=dx*dx+dy*dy,t=Math.max(.05,Math.min(.95,((point[0]-x.pos[0])*dx+(point[1]-x.pos[1])*dy)/l));
    pos=[x.pos[0]+t*dx,x.pos[1]+t*dy]
  }
  let id='dev-'+Date.now().toString(36)+'-'+(++editor.serial);
  x.edges=x.edges.filter(e=>e.to!==b);
  y.edges=y.edges.filter(e=>e.to!==a);
  addNode(id,pos,x.f);
  edge(a,id);
  edge(id,b);
  editor.selection={kind:'node',id};
  editChanged(before)
}

function deleteEditNodeBase2(){
  
  let sel=editor.selection;
  if(!sel)
  {
    
    return;
  }
  if(editor.draft?.kind==='path'&&editor.draft.last===sel.id)
  {
    
    editor.draft.last=null;
  }
  let before=editSnapshot();
  if(sel.kind==='edge'){
    
    let [a,b]=sel.id.split('|');
    for(const [x,y]of [[a,b],[b,a]])
    {
      
      if(graph.has(x))
    {
        
        graph.get(x).edges=graph.get(x).edges.filter(e=>e.to!==y)
      }
    }
  }else 
  {
    
    if(sel.kind==='node'){
    
      let n=graph.get(sel.id);
      if(!n)
    {
        
        return;
      }
      for(const other of graph.values())
    {
        
        other.edges=other.edges.filter(e=>e.to!==n.id);
      }
      graph.delete(n.id);
      for(const scene of editor.scenery)
    {
        
        if(scene.linkedNodes)
    {
          
          scene.linkedNodes=scene.linkedNodes.map(id=>id===n.id?null:id);
        }
      }
      for(const p of places)
    {
        
        if(p.node===n.id)
    {
          
          p.node=null
        }
      }
    }else 
  {
      
      if(sel.kind==='point'){
    
        let p=currentPoint();
        p.hidden=true;
        if(start===p)
    {
          
          start=null;
        }
        if(end===p)
    {
          
          end=null;
        }
        if(!start||!end){
      
          routePath=null;
          $('#route-result').hidden=true
        }
        renderList();
        $('#route').disabled=!(start&&end)
      }else 
  {
        
        if(sel.kind==='area'){
    
          editor.areas=editor.areas.filter(a=>a.id!==sel.id)
        }else 
  {
          
          if(sel.kind==='vertex'){
    
            let [id,li,vi]=sel.id.split('|'),a=editor.areas.find(a=>a.id===id);
            if(a.loops[+li].length<=3){
      
              editor.message='Eine Fläche braucht mindestens drei Eckpunkte.';
              updateEditor();
              return
            }
            a.loops[+li].splice(+vi,1);
            editor.selection={kind:'area',id}
          }
        }
      }
    }
  }
  editor.selection=null;
  editChanged(before)
}

function deleteEditNode(){
  
  let s=selectedScenery();
  if(s){
    
    let before=editSnapshot();
    if(editor.selection.kind==='scenery-vertex'){
      
      if(s.points.length<=2){
        
        editor.message='Eine Linie benötigt mindestens zwei Punkte.';
        updateEditor();
        return
      }
      let i=+editor.selection.id.split('|')[1];
      s.points.splice(i,1);
      s.linkedNodes?.splice(i,1)
    }else 
    {
      
      editor.scenery=editor.scenery.filter(x=>x.id!==s.id);
    }
    editor.selection=null;
    editChanged(before);
    return
  }
  deleteEditNodeBase2()
}

function editorUndo(redo=false){
  
  let stack=redo?editor.redo:editor.undo,other=redo?editor.undo:editor.redo;
  if(!stack.length)
  {
    
    return;
  }
  let current=editSnapshot(),next=stack.pop();
  other.push(current);
  restoreEdit(next);
  editor.dirty=true;
  editor.message=redo?'Änderung wiederhergestellt · noch nicht gespeichert':'Änderung rückgängig · noch nicht gespeichert';
  updateEditor()
}

function saveEdits(){
  
  try{
    
    let snap=editSnapshot();
    localStorage.setItem(EDIT_KEY,JSON.stringify(snap));
    editor.saved=snap;
    editor.dirty=false;
    editor.message='Auf diesem Gerät gespeichert ✓';
    updateEditor()
  }catch{
    
    editor.message='Speichern im Browser nicht möglich. Bitte JSON exportieren.';
    updateEditor()
  }
}

function exportEdits(){
  
  let snapshot=editSnapshot(),blob=new Blob([JSON.stringify(snapshot)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');
  a.href=url;
  a.download='gso-kartenkorrekturen.json';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
  editor.message='JSON exportiert · zum Übernehmen hier im Chat anhängen.';
  updateEditor()
}

async function importEdits(file){
  
  if(!file)
  {
    
    return;
  }
  try{
    
    if(file.size>16*1024*1024)
    {
      
      throw Error('Die Datei ist zu groß (maximal 16 MB).');
    }
    let parsed=validEdit(JSON.parse(await file.text())),before=editSnapshot();
    restoreEdit(parsed);
    remember(before);
    editor.message='JSON importiert · bitte speichern, um die Änderungen zu behalten.';
    updateEditor()
  }catch(err){
    
    editor.message=err instanceof SyntaxError?'Die Datei enthält kein gültiges JSON.':err.message;
    updateEditor()
  }finally{
    
    $('#dev-file').value=''
  }
}

function devId(prefix){
  
  return 'dev-'+prefix+'-'+Date.now().toString(36)+'-'+(++editor.serial)
}

function areaD(a){
  
  return a.loops.map(l=>'M'+l.map(p=>p.join(',')).join('L')+'Z').join(' ')
}

function renderCustomLayers(){
  
  return places.filter(p=>p.custom&&!p.outdoor&&!p.hidden&&p.floor===floor).map(p=>`<g class="poi" data-place="${esc(p.id)}"><circle cx="${p.pos[0]}" cy="${p.pos[1]}" r="5" fill="#8cd4b9"/><text x="${p.pos[0]+8}" y="${p.pos[1]+2}">${esc(p.code)}</text></g>`).join('')
}

function cross2(a,b,c){
  
  return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
}

function segmentsMeet(a,b,c,d){
  
  let eps=1e-7,on=(p,q,r)=>Math.abs(cross2(p,q,r))<eps&&r[0]>=Math.min(p[0],q[0])-eps&&r[0]<=Math.max(p[0],q[0])+eps&&r[1]>=Math.min(p[1],q[1])-eps&&r[1]<=Math.max(p[1],q[1])+eps;
  return cross2(a,b,c)*cross2(a,b,d)<-eps&&cross2(c,d,a)*cross2(c,d,b)<-eps||on(a,b,c)||on(a,b,d)||on(c,d,a)||on(c,d,b)
}

function insideLoop(p,loop){
  
  let hit=false;
  for(let i=0,j=loop.length-1;i<loop.length;j=i++){
    
    let a=loop[i],b=loop[j];
    if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])
    {
      
      hit=!hit
    }
  }
  return hit
}

function simpleLoop(l){
  
  if(l.length<3)
  {
    
    return false;
  }
  let area=0;
  for(let i=0;i<l.length;i++){
    
    let a=l[i],b=l[(i+1)%l.length];
    area+=a[0]*b[1]-a[1]*b[0];
    if(Math.hypot(a[0]-b[0],a[1]-b[1])<.05)
    {
      
      return false;
    }
    for(let j=i+1;j<l.length;j++){
      
      if(j===i+1||i===0&&j===l.length-1)
      {
        
        continue;
      }
      if(segmentsMeet(a,b,l[j],l[(j+1)%l.length]))
      {
        
        return false
      }
    }
  }
  return Math.abs(area)>.5
}

function selectedArea(){
  
  let sel=editor.selection;
  return sel&&['area','vertex'].includes(sel.kind)?editor.areas.find(a=>a.id===(sel.kind==='area'?sel.id:sel.id.split('|')[0])):null
}

function currentPoint(){
  
  return editor.selection?.kind==='point'?places.find(p=>p.id===editor.selection.id):null
}

function startDraft(kind){
  
  editor.draft={kind,points:[],last:null};
  editor.selection=null;
  editor.message=kind==='path'?'Neue Wege werden direkt Teil des Wegenetzes.':'Neue '+(kind==='area'?'Fläche zeichnen':'Markierung setzen');
  updateEditor();
  drawMap()
}

function finishDraftBase1(){
  
  if(editor.draft?.kind==='area'){
    
    let points=editor.draft.points;
    if(points.length<3){
      
      editor.message='Eine Fläche braucht mindestens drei Eckpunkte.';
      updateEditor();
      return
    }
    if(!simpleLoop(points)){
      
      editor.message='Die Fläche überkreuzt sich oder ist zu klein. Letzten Eckpunkt entfernen oder abbrechen.';
      updateEditor();
      return
    }
    let before=editSnapshot(),a={id:devId('area'),name:'Neue Fläche',f:editFloor(),kind:'paving',loops:[points.map(p=>[...p])],color:areaColors.paving,opacity:1,blocked:false,builtin:false};
    editor.areas.push(a);
    editor.selection={kind:'area',id:a.id};
    editor.draft=null;
    editChanged(before)
  }else{
    
    editor.draft=null;
    updateEditor();
    drawMap()
  }
}

function finishDraft(){
  
  if(['road','footway'].includes(editor.draft?.kind)){
    
    if(editor.draft.points.length<2){
      
      editor.message='Mindestens zwei Verlaufspunkte setzen.';
      updateEditor();
      return
    }
    let before=editSnapshot(),kind=editor.draft.kind,s={id:devId(kind),kind,name:kind==='road'?'Neue Straße':'Neuer Gehweg',points:editor.draft.points.map(p=>[...p]),width:kind==='road'?20:6,color:sceneDefaults[kind],f:'Gelände',builtin:false,label:kind==='road'};
    editor.scenery.push(s);
    editor.selection={kind:'scenery',id:s.id};
    editor.draft=null;
    editChanged(before);
    return
  }
  finishDraftBase1()
}

function addTargetAt(pos){
  
  let before=editSnapshot(),id=devId('place'),node=devId('node'),f=editFloor();
  addNode(node,pos,f);
  let p={id,code:'Neue Markierung',name:'Eigener Navigationspunkt',category:'marker',floor:f,outdoor:f==='Gelände',custom:true,node,pos:[...pos],hidden:false};
  places.push(p);
  editor.selection={kind:'point',id};
  editor.draft=null;
  editChanged(before);
  renderList();
  editor.message='Markierung gesetzt. Name ändern und den Wegpunkt über „Wege“ anbinden.';
  updateEditor()
}

function pathClick(pos,hit){
  
  let before=editSnapshot(),f=editFloor(),id=hit?.dataset.editKind==='node'?hit.dataset.editId:null;
  if(!id){
    
    let threshold=Math.max(2,view[2]/svg.getBoundingClientRect().width*10),near=[...graph.values()].filter(n=>n.f===f).map(n=>[n,Math.hypot(n.pos[0]-pos[0],n.pos[1]-pos[1])]).sort((a,b)=>a[1]-b[1])[0];
    if(near&&near[1]<threshold)
    {
      
      id=near[0].id
    }
  }
  if(!id){
    
    id=devId('node');
    addNode(id,[...pos],f)
  }
  let last=editor.draft.last;
  if(last&&last!==id&&!graph.get(last).edges.some(e=>e.to===id))
  {
    
    edge(last,id);
  }
  editor.draft.last=id;
  editor.selection={kind:'node',id};
  editChanged(before)
}

function addAreaVertex(){
  
  let a=selectedArea();
  if(!a)
  {
    
    return;
  }
  let before=editSnapshot(),li=0,vi=0,longest=-1;
  for(let l=0;l<a.loops.length;l++)
  {
    
    for(let i=0;i<a.loops[l].length;i++){
    
      let p=a.loops[l][i],q=a.loops[l][(i+1)%a.loops[l].length],d=Math.hypot(p[0]-q[0],p[1]-q[1]);
      if(d>longest){
      
        longest=d;
        li=l;
        vi=i
      }
    }
  }
  let loop=a.loops[li],p=loop[vi],q=loop[(vi+1)%loop.length];
  loop.splice(vi+1,0,[(p[0]+q[0])/2,(p[1]+q[1])/2]);
  editor.selection={kind:'vertex',id:a.id+'|'+li+'|'+(vi+1)};
  editChanged(before)
}

function applyProperties(){
  
  let a=selectedArea(),p=currentPoint();
  if(!a&&!p)
  {
    
    return;
  }
  let name=$('#dev-name').value.trim();
  if(!name){
    
    editor.message='Bitte einen Namen eingeben.';
    updateEditor();
    return
  }
  let before=editSnapshot();
  if(a){
    
    a.name=name.slice(0,160);
    a.color=$('#dev-color').value;
    a.opacity=Number($('#dev-area-opacity').value)/100;
    a.kind=$('#dev-area-kind').value;
    a.blocked=$('#dev-blocked').checked
  }else{
    
    p.code=name.slice(0,160);
    p.name=$('#dev-description').value.slice(0,160);
    p.category=$('#dev-category').value
  }
  editChanged(before);
  renderList();
  document.activeElement?.blur?.();
  updateEditor()
}

function connectSelected(){
  
  let sel=editor.selection;
  if(sel?.kind!=='node')
  {
    
    return;
  }
  let a=graph.get(sel.id),b=graph.get($('#dev-link-target').value),type=$('#dev-link-type').value;
  if(!a||!b){
    
    editor.message='Bitte einen Ziel-Wegpunkt auswählen.';
    updateEditor();
    return
  }
  if(a.edges.some(e=>e.to===b.id)){
    
    editor.message='Diese Verbindung besteht bereits.';
    updateEditor();
    return
  }
  let cross=a.f!==b.f;
  if(!cross&&type!=='walk'||cross&&(a.f==='Gelände'||b.f==='Gelände')&&(type!=='door'||![a.f,b.f].includes('EG'))||cross&&a.f!=='Gelände'&&b.f!=='Gelände'&&!['stairs','lift'].includes(type)){
    
    editor.message='Typ passt nicht: gleicher Bereich → Weg, Gelände/EG → Tür, EG/OG → Treppe oder Aufzug.';
    updateEditor();
    return
  }
  if(cross&&!$('#dev-link-verified').checked){
    
    editor.message='Bitte bestätigen, dass du diesen Übergang geprüft hast.';
    updateEditor();
    return
  }
  let before=editSnapshot();
  edge(a.id,b.id,type);
  for(const [n,id]of [[a,b.id],[b,a.id]])
  {
    
    n.edges.find(e=>e.to===id).verified=cross;
  }
  editChanged(before);
  editor.message='Verbindung erstellt und in der Navigation berücksichtigt.';
  updateEditor()
}

function transitionLabel(a,b){
  
  const type=a.edges.find(e=>e.to===b.id)?.type;
  return type==='door'?'Eingang':type==='lift'?'Aufzug':'Treppe'
}

function renderAddedScenery(){
  
  return editor.scenery.filter(s=>!s.builtin).map(renderScenery).join('')
}

function selectedScenery(){
  
  let sel=editor.selection;
  return ['scenery','scenery-vertex'].includes(sel?.kind)?editor.scenery.find(s=>s.id===sel.id.split('|')[0]):null
}

function applySceneProperties(){
  
  let s=selectedScenery();
  if(!s)
  {
    
    return;
  }
  let size=Number($('#dev-scene-size').value),max=s.kind==='tree'?100:150;
  if(!Number.isFinite(size)||size<1||size>max){
    
    editor.message='Bitte eine Größe zwischen 1 und '+max+' eingeben.';
    updateEditor();
    return
  }
  let before=editSnapshot();
  s.name=$('#dev-scene-name').value.slice(0,160);
  s.color=$('#dev-scene-color').value;
  if(s.kind==='tree')
  {
    
    s.radius=size;
  }else{
    
    s.width=size;
    s.kind=$('#dev-scene-kind').value;
    s.label=$('#dev-scene-label').checked
  }
  editChanged(before);
  document.activeElement?.blur?.();
  updateEditor()
}

function addSceneryVertex(){
  
  let s=selectedScenery();
  if(!s||s.kind==='tree')
  {
    
    return;
  }
  let before=editSnapshot(),best=0,max=-1;
  for(let i=0;i<s.points.length-1;i++){
    
    let d=Math.hypot(s.points[i+1][0]-s.points[i][0],s.points[i+1][1]-s.points[i][1]);
    if(d>max){
      
      max=d;
      best=i
    }
  }
  let a=s.points[best],b=s.points[best+1];
  s.points.splice(best+1,0,[(a[0]+b[0])/2,(a[1]+b[1])/2]);
  s.linkedNodes?.splice(best+1,0,null);
  editor.selection={kind:'scenery-vertex',id:s.id+'|'+(best+1)};
  editChanged(before)
}

function sceneryToPath(){
  
  let s=selectedScenery();
  if(!s||s.kind!=='footway')
  {
    
    return;
  }
  let before=editSnapshot(),ids=[];
  for(const p of s.points){
    
    let n=[...graph.values()].find(n=>n.f==='Gelände'&&Math.hypot(n.pos[0]-p[0],n.pos[1]-p[1])<2);
    ids.push(n?n.id:addNode(devId('node'),[...p],'Gelände'))
  }
  for(let i=1;i<ids.length;i++)
  {
    
    if(ids[i]!==ids[i-1]&&!graph.get(ids[i-1]).edges.some(e=>e.to===ids[i]))
  {
      
      edge(ids[i-1],ids[i]);
    }
  }
  s.linkedNodes=ids;
  editChanged(before);
  editor.message='Gehweg ins Wegenetz übernommen. Anschlüsse bei Bedarf im Werkzeug „Wege“ verbinden.';
  updateEditor()
}
