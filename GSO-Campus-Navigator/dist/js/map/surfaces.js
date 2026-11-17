'use strict';
function completionBackground(){
 
  if(backgroundCache!==null){
    return backgroundCache
  }
  
  let h='<rect x="-10000" y="-10000" width="20000" height="20000" fill="#374d64"/>';
  for(const a of editor.areas.filter(a=>a.f==='Gelände'&&a.completionLayer==='background'))
  {
    
    h+=`<path d="${areaD(a)}" fill="${a.color}" opacity="${a.opacity}" fill-rule="evenodd"/>`;
  }
  return backgroundCache=h
}

function areaFrame(a){
  
  let p=a.loops[0],cx=p.reduce((s,v)=>s+v[0],0)/p.length,cy=p.reduce((s,v)=>s+v[1],0)/p.length,best=0,len=0;
  for(let i=0;i<p.length;i++){
    
    let n=p[(i+1)%p.length],d=Math.hypot(n[0]-p[i][0],n[1]-p[i][1]);
    if(d>len){
      
      best=i;
      len=d
    }
  }
  let q=p[(best+1)%p.length],angle=Math.atan2(q[1]-p[best][1],q[0]-p[best][0]),u=[Math.cos(angle),Math.sin(angle)],v=[-u[1],u[0]],local=p.map(p=>[(p[0]-cx)*u[0]+(p[1]-cy)*u[1],(p[0]-cx)*v[0]+(p[1]-cy)*v[1]]);
  return {cx,cy,angle:angle*180/Math.PI,x0:Math.min(...local.map(p=>p[0])),x1:Math.max(...local.map(p=>p[0])),y0:Math.min(...local.map(p=>p[1])),y1:Math.max(...local.map(p=>p[1]))}
}

function parkingPattern(a){
  
  let f=areaFrame(a),clip='parking-'+a.id.replace(/[^a-z0-9-]/gi,''),bike=/fahrrad/i.test(a.name),margin=4,aisle=bike?5:10,step=bike?10:12;
  let marks='';
  if(bike){
    
    for(let x=f.x0+7;x<f.x1-4;x+=step)
    {
      
      for(const sign of [-1,1])
    {
        
        marks+=`<path d="M${x} ${sign*aisle}v${sign*15}q4 ${sign*4} 7 0v${-sign*15}" fill="none"/>`
      }
    }
  }else{
    
    marks+=`<path d="M${f.x0+margin} -${aisle}H${f.x1-margin}M${f.x0+margin} ${aisle}H${f.x1-margin}" fill="none"/>`;
    for(let x=f.x0+7;x<f.x1-3;x+=step)
    {
      
      marks+=`<path d="M${x} ${f.y0+margin}V${-aisle}M${x} ${aisle}V${f.y1-margin}" fill="none"/>`;
    }
    for(const x of [f.x0+(f.x1-f.x0)*.19,f.x0+(f.x1-f.x0)*.81])
    {
      
      marks+=`<text x="${x}" y="3" text-anchor="middle" fill="#d0dce3" stroke="none" font-size="8" font-family="Arial,sans-serif">P</text>`
    }
  }
  return `<defs><clipPath id="${clip}"><path d="${areaD(a)}" fill-rule="evenodd"/></clipPath></defs><g clip-path="url(#${clip})" pointer-events="none"><g transform="translate(${f.cx} ${f.cy}) rotate(${f.angle})" stroke="#ccdde2" stroke-opacity="${bike?.8:.6}" stroke-width=".8">${marks}</g></g>`
}

function footballPattern(a){
  
  let p=a.loops[0];
  if(p.length!==4)
  {
    
    return '';
  }
  const at=(u,v)=>[p[0][0]*(1-u)*(1-v)+p[1][0]*u*(1-v)+p[2][0]*u*v+p[3][0]*(1-u)*v,p[0][1]*(1-u)*(1-v)+p[1][1]*u*(1-v)+p[2][1]*u*v+p[3][1]*(1-u)*v],line=(list)=>'M'+list.map(q=>at(...q).join(',')).join('L');
  let center=at(.5,.5);
  return `<g pointer-events="none" stroke="#d6e1cc" stroke-opacity=".7" stroke-width="1" fill="none"><path d="${line([[.04,.04],[.96,.04],[.96,.96],[.04,.96],[.04,.04]])}"/><path d="${line([[.5,.04],[.5,.96]])}"/><circle cx="${center[0]}" cy="${center[1]}" r="15"/><path d="${line([[.04,.28],[.18,.28],[.18,.72],[.04,.72]])} ${line([[.96,.28],[.82,.28],[.82,.72],[.96,.72]])}"/></g>`
}

function renderCustomAreas(){
  
  let h='';
  for(const a of editor.areas.filter(a=>!a.builtin&&!a.completionLayer&&(a.f==='Gelände'||a.f===floor))){
    
    h+=`<path d="${areaD(a)}" fill="${a.color}" opacity="${a.opacity}" fill-rule="evenodd" stroke="${a.blocked?'#e5a69d':'#9bb0ba'}" stroke-opacity=".55" stroke-width=".7"/>`;
    if(a.kind==='parking')
    {
      
      h+=parkingPattern(a);
    }else 
    {
      
      if(/fußball|fussball/i.test(a.name))
    {
        
        h+=footballPattern(a);
      }else 
    {
        
        if(a.name&&a.kind!=='mask'){
      
          let p=a.loops[0],x=p.reduce((s,p)=>s+p[0],0)/p.length,y=p.reduce((s,p)=>s+p[1],0)/p.length;
          h+=`<text x="${x}" y="${y}" class="zone-label" text-anchor="middle">${esc(a.name)}</text>`
        }
      }
    }
  }
  return h
}

function outlineFingerprint(loops){
  
  let text=loops.map(l=>l.map(p=>p.map(v=>Math.round(v*1000)).join(',')).join('|')).join(';'),h=2166136261;
  for(let i=0;i<text.length;i++)
  {
    
    h=Math.imul(h^text.charCodeAt(i),16777619);
  }
  return String(h>>>0)
}

function upgradeOutlines(raw){
  
  if(!outlineMigration||!raw?.areas)
  {
    
    return raw;
  }
  let changes=[];
  for(let i=0;i<raw.areas.length;i++){
    
    let a=raw.areas[i],m=outlineMigration[a.id];
    if(m&&a.completionLayer==='background'&&a.outlineVersion!==1&&outlineFingerprint(a.loops)===m.beforeHash)
    {
      
      changes.push([i,m])
    }
  }
  if(!changes.length)
  {
    
    return raw;
  }
  let result=JSON.parse(JSON.stringify(raw));
  for(const [i,m]of changes)
  {
    
    Object.assign(result.areas[i],{loops:JSON.parse(JSON.stringify(m.loops)),outlineVersion:1,edgeStyle:m.edgeStyle,cornerRadius:m.cornerRadius});
  }
  return result
}

function roundedAreaPath(loop,radius){
  
  if(loop.length<3)
  {
    
    return '';
  }
  let starts=[],ends=[];
  for(let i=0;i<loop.length;i++){
    
    let p=loop[i],prev=loop[(i+loop.length-1)%loop.length],next=loop[(i+1)%loop.length],l1=Math.hypot(prev[0]-p[0],prev[1]-p[1]),l2=Math.hypot(next[0]-p[0],next[1]-p[1]),r=Math.min(radius,l1*.2,l2*.2);
    if(l1<1e-6||l2<1e-6){
      
      starts.push([...p]);
      ends.push([...p])
    }else{
      
      starts.push([p[0]+(prev[0]-p[0])*r/l1,p[1]+(prev[1]-p[1])*r/l1]);
      ends.push([p[0]+(next[0]-p[0])*r/l2,p[1]+(next[1]-p[1])*r/l2])
    }
  }
  let d='M'+ends[0].join(',');
  for(let j=1;j<=loop.length;j++){
    
    let i=j%loop.length;
    d+='L'+starts[i].join(',')+'Q'+loop[i].join(',')+' '+ends[i].join(',')
  }
  return d+'Z'
}

function upgradeNavigation(raw){
  
  let r=JSON.parse(JSON.stringify(raw));
  for(const a of r.areas||[]){
    
    let m=landscapeMigration?.[a.id];
    if(m&&a.landscapeVersion!==1&&m.beforeHashes.includes(outlineFingerprint(a.loops)))
    {
      
      Object.assign(a,{loops:m.loops,landscapeVersion:1,outlineVersion:2,edgeStyle:'rounded',cornerRadius:18})
    }
  }
  if(!indoorNavigation||r.navigationRevision===1||r.nodes.some(n=>n.id.startsWith('dev-indoor-')))
  {
    
    return r;
  }
 // Keep the outdoor network and all manual indoor additions. Replace only the old generated corridor axes.
  let old=new Set(r.nodes.filter(n=>n.f!=='Gelände'&&!n.id.startsWith('dev-')).map(n=>n.id));
  r.nodes=r.nodes.filter(n=>!old.has(n.id));
  for(const n of r.nodes)
  {
    
    n.edges=n.edges.filter(e=>!old.has(e.to));
  }
  r.nodes.push(...JSON.parse(JSON.stringify(indoorNavigation.nodes)));
  let by=new Map(r.nodes.map(n=>[n.id,n]));
  for(const e of indoorNavigation.entrances.filter(e=>e.connected)){
    
    let a=by.get(e.outsideNode),b=by.get(e.insideNode);
    if(a&&b){
      
      a.edges.push({to:b.id,type:'door',verified:true});
      b.edges.push({to:a.id,type:'door',verified:true})
    }
  }
  for(const [id,node]of Object.entries(r.pointNodes)){
    
    if(old.has(node)||indoorNavigation.rooms[id])
    {
      
      r.pointNodes[id]=indoorNavigation.rooms[id]||null
    }
  }
  r.navigationRevision=1;
  return r
}

function roundedWalkPath(points,r){
  
  let d='M'+points[0].join(',');
  for(let i=1;i<points.length-1;i++){
    
    let a=points[i-1],b=points[i],c=points[i+1],u=Math.hypot(b[0]-a[0],b[1]-a[1]),v=Math.hypot(c[0]-b[0],c[1]-b[1]),k=Math.min(r,u*.2,v*.2);
    if(!u||!v)
    {
      
      continue;
    }
    d+='L'+[b[0]+(a[0]-b[0])*k/u,b[1]+(a[1]-b[1])*k/u]+'Q'+b+' '+[b[0]+(c[0]-b[0])*k/v,b[1]+(c[1]-b[1])*k/v]
  }
  return d+'L'+points.at(-1).join(',')
}

function topStreetLabels(){
  
  return '<g id="street-labels" pointer-events="none">'+editor.scenery.filter(s=>s.kind!=='tree'&&s.label!==false&&s.name&&!/^Neue(r)?\s+(Straße|Gehweg)$/i.test(s.name)).map(s=>{
    
    let best=0,len=0;
    for(let i=0;i<s.points.length-1;i++){
      
      let d=Math.hypot(s.points[i+1][0]-s.points[i][0],s.points[i+1][1]-s.points[i][1]);
      if(d>len){
        
        best=i;
        len=d
      }
    }
    let a=s.points[best],b=s.points[best+1],x=(a[0]+b[0])/2,y=(a[1]+b[1])/2,angle=Math.atan2(b[1]-a[1],b[0]-a[0])*180/Math.PI;
    if(angle>90||angle<-90)
    {
      
      angle+=180;
    }
    return `<text class="road-name top-road-name" x="${x}" y="${y}" transform="rotate(${angle} ${x} ${y})" style="font-size:${referenceLabelSize()*.9}px;paint-order:stroke;stroke:#132638;stroke-width:${referenceLabelSize()*.4}px;stroke-linejoin:round">${esc(s.name)}</text>`
  }).join('')+'</g>'
}

function indoorDoorOverlay(){
  
  if(!editor.active||editor.scope==='Gelände'||!indoorNavigation)
  {
    
    return '';
  }
  return '<g pointer-events="none">'+indoorNavigation.doors.filter(d=>d.floor===floor||d.f===floor).map(d=>{
    
    let pos=world(...d.xy);
    return `<rect x="${pos[0]-1.1}" y="${pos[1]-1.1}" width="2.2" height="2.2" fill="${d.connected?'#65ddc7':'#ffa85b'}"><title>${d.connected?'Tür angeschlossen':'Türanschluss offen'}</title></rect>`
  }).join('')+'</g>'
}
