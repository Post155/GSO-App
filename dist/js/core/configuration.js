'use strict';
const Config = (() => {
 
  const floors=new Set(['EG','OG','Gelände']),types=new Set(['marker','entrance','gate','parking','bicycle','smoking','wc','classroom','office','service','stairs','lift','corridor','bus','tip']);
  const id=value=>typeof value==='string'&&/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,159}$/.test(value)&&!['__proto__','constructor','prototype'].includes(value);
  const text=value=>typeof value==='string'&&value.length<=160;
  const pos=value=>Array.isArray(value)&&value.length===2&&value.every(n=>Number.isFinite(n)&&Math.abs(n)<10000);
  const color=value=>typeof value==='string'&&/^#[0-9a-f]{6}$/i.test(value);
  function assert(value,message){
    
    if(!value)
    {
      
      throw Error(message)
    }
  }
  function safeClone(raw){
    
    assert(raw&&typeof raw==='object'&&!Array.isArray(raw),'Kartendaten fehlen.');
    let s=JSON.stringify(raw);
    assert(s.length<=16*1024*1024,'Die Datei ist zu groß (maximal 16 MB).');
    return JSON.parse(s)
  }
 /** Validate before mutating live state. Every returned field has a bounded, explicit type. */
  function validate(raw,baseline,originalPlaces){
  
    let r=safeClone(raw);
    assert([1,2,3,4].includes(r.version)&&r.site==='gso-campus','Unbekanntes Kartenformat.');
    if(r.version<4){
      
      r={...safeClone(baseline),...r};
      r.customPlaces??=[];
      r.hiddenPoints??=[];
      r.scenery??=[];
      r.areas??=[];
      r.pointNodes??=baseline.pointNodes;
      r.pointMeta??=baseline.pointMeta
    }
    assert(r.points&&r.pointNodes&&r.pointMeta&&Array.isArray(r.customPlaces)&&r.customPlaces.length<=700,'Zieldaten sind unvollständig.');
    assert(Array.isArray(r.nodes)&&r.nodes.length<=3000&&Array.isArray(r.areas)&&r.areas.length<=3000&&Array.isArray(r.scenery)&&r.scenery.length<=5000&&Array.isArray(r.hiddenPoints),'Kartenelemente sind unvollständig.');
    const targets=new Map(originalPlaces.map(p=>[p.id,p.floor]));
    if(r.roomDefinitions){
      
      assert(Array.isArray(r.roomDefinitions)&&r.roomDefinitions.length<=700,'Ungültige Raumdefinitionen.');
      const ids=new Set();
      r.roomDefinitions=r.roomDefinitions.map(d=>{
        
        assert(d&&targets.has(d.id)&&!ids.has(d.id)&&['EG','OG'].includes(d.floor)&&text(d.building)&&typeof d.important==='boolean','Ungültige Raumdefinition.');
        ids.add(d.id);
        targets.set(d.id,d.floor);
        return {id:d.id,floor:d.floor,building:d.building,important:d.important}
      })
    }
    r.customPlaces=r.customPlaces.map(p=>{
      
      assert(p&&id(p.id)&&!targets.has(p.id)&&floors.has(p.floor)&&text(p.code)&&p.code.trim()&&text(p.name)&&types.has(p.category)&&p.outdoor===(p.floor==='Gelände'),'Ungültige eigene Markierung.');
      targets.set(p.id,p.floor);
      return {id:p.id,code:p.code,name:p.name,category:p.category,floor:p.floor,outdoor:p.outdoor}
    });
    assert(Object.keys(r.points).length===targets.size&&Object.keys(r.points).every(k=>targets.has(k)&&pos(r.points[k]))&&r.hiddenPoints.every(k=>targets.has(k)),'Zielpunkte passen nicht zu dieser Karte.');
    let metadata={};
    for(const key of targets.keys()){
      
      let m=r.pointMeta[key];
      assert(m&&text(m.code)&&m.code.trim()&&text(m.name)&&types.has(m.category),'Ungültige Zielbeschriftung.');
      assert(m.building===undefined||text(m.building),'Ungültiger Gebäudename.');
      assert(m.important===undefined||typeof m.important==='boolean','Ungültige Raumpriorität.');
      metadata[key]={code:m.code,name:m.name,category:m.category,...(m.building!==undefined?{building:m.building}:{}),...(m.important!==undefined?{important:m.important}:{})}
    }
    r.pointMeta=metadata;
    const nodes=new Map();
    r.nodes=r.nodes.map(n=>{
      
      assert(n&&id(n.id)&&!nodes.has(n.id)&&pos(n.pos)&&floors.has(n.f)&&Array.isArray(n.edges)&&n.edges.length<=150,'Ungültiger Wegpunkt.');
      let result={id:n.id,pos:n.pos,f:n.f,edges:n.edges.map(e=>{
        
        assert(e&&id(e.to)&&['walk','door','stairs','lift'].includes(e.type)&&(!('verified'in e)||typeof e.verified==='boolean'),'Ungültige Verbindung.');
        return {to:e.to,type:e.type,verified:!!e.verified}
      })};
      nodes.set(n.id,result);
      return result
    });
    for(const n of nodes.values()){
      
      let seen=new Set();
      for(const e of n.edges){
        
        let other=nodes.get(e.to);
        assert(other&&other!==n&&!seen.has(e.to),'Fehlender oder doppelter Anschluss.');
        seen.add(e.to);
        assert(other.edges.some(back=>back.to===n.id&&back.type===e.type&&back.verified===e.verified),'Verbindungen müssen beidseitig übereinstimmen.');
        if(n.f===other.f)
        {
          
          assert(e.type==='walk','Gleiche Etage benötigt einen normalen Weg.');
        }else{
          
          assert(e.verified,'Etagen- und Gebäudeübergänge müssen bestätigt sein.');
          assert(n.f==='Gelände'||other.f==='Gelände'?e.type==='door'&&[n.f,other.f].includes('EG'):['stairs','lift'].includes(e.type),'Unpassender Etagenübergang.')
        }
      }
    }
    for(const [key,f]of targets)
    {
      
      assert(r.pointNodes[key]===null||nodes.get(r.pointNodes[key])?.f===f,'Ziel verweist auf einen ungültigen Wegpunkt.');
    }
    const builtinAreas=new Set(baseline.areas.filter(a=>a.builtin).map(a=>a.id)),areaIDs=new Set();
    let vertices=0;
    for(const a of r.areas){
      
      assert(a&&id(a.id)&&!areaIDs.has(a.id)&&text(a.name)&&floors.has(a.f)&&['green','building','paving','parking','mask','blocked','room'].includes(a.kind)&&color(a.color)&&Number.isFinite(a.opacity)&&a.opacity>=.05&&a.opacity<=1&&typeof a.blocked==='boolean'&&Array.isArray(a.loops)&&a.loops.length>0&&a.loops.length<=100,'Ungültige Fläche.');
      for(const loop of a.loops){
        
        assert(Array.isArray(loop)&&loop.length>=3&&loop.every(pos),'Ungültige Flächeneckpunkte.');
        vertices+=loop.length
      }
      assert(vertices<=120000,'Zu viele Flächeneckpunkte.');
      if(a.cornerRadius!==undefined)
      {
        
        assert(Number.isFinite(a.cornerRadius)&&a.cornerRadius>=0&&a.cornerRadius<=30,'Ungültiger Eckenradius.');
      }
      assert(a.completionLayer===undefined||a.completionLayer==='background','Ungültige Flächenebene.');
      a.builtin=builtinAreas.has(a.id);
      areaIDs.add(a.id)
    }
    const sceneIDs=new Set(),builtinScene=new Set(baseline.scenery.filter(s=>s.builtin).map(s=>s.id));
    let sceneVertices=0;
    for(const s of r.scenery){
      
      assert(s&&id(s.id)&&!sceneIDs.has(s.id)&&['tree','road','footway'].includes(s.kind)&&s.f==='Gelände'&&text(s.name)&&color(s.color)&&(!('label'in s)||typeof s.label==='boolean'),'Ungültiges Straßenelement oder Baum.');
      if(s.kind==='tree')
      {
        
        assert(pos(s.pos)&&Number.isFinite(s.radius)&&s.radius>=1&&s.radius<=100,'Ungültige Baumgröße.');
      }else{
        
        assert(Array.isArray(s.points)&&s.points.length>=2&&s.points.length<=700&&s.points.every(pos)&&Number.isFinite(s.width)&&s.width>=1&&s.width<=150,'Ungültige Straßenkontur.');
        sceneVertices+=s.points.length
      }
      assert(sceneVertices<=120000,'Zu viele Straßenpunkte.');
      if(s.linkedNodes)
      {
        
        assert(Array.isArray(s.linkedNodes)&&s.linkedNodes.length===s.points?.length&&s.linkedNodes.every(k=>k===null||nodes.get(k)?.f==='Gelände'),'Ungültiger Straßen-Wegeanschluss.');
      }
      s.builtin=builtinScene.has(s.id);
      sceneIDs.add(s.id)
    }
    r.version=4;
    r.navigationRevision=r.nodes.some(n=>n.id.startsWith('dev-indoor-'))?1:0;
    return r;
  }
  function validateRooms(raw){
    
    assert(raw?.schemaVersion===1&&Array.isArray(raw.rooms)&&raw.rooms.length<=700,'Ungültiger Raumkatalog.');
    let seen=new Set();
    for(const r of raw.rooms){
      
      assert(r&&id(r.id)&&!seen.has(r.id)&&text(r.code)&&r.code.trim()&&text(r.name)&&text(r.building)&&['EG','OG'].includes(r.floor)&&pos([r.x,r.y])&&types.has(r.type)&&typeof r.visible==='boolean'&&typeof r.important==='boolean'&&(r.region==null||Number.isInteger(r.region)),'Ungültiger Raum im Katalog.');
      seen.add(r.id)
    }
    return safeClone(raw)
  }
  return {validate,validateRooms,safeClone};
})();
if(typeof module!=='undefined'&&module.exports)
{
  
  module.exports=Config;
}
