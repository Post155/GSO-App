'use strict';
/** Editable room catalogue can be exchanged independently of the drawing and graph. */
function roomCatalogue(){
  
  return {schemaVersion:1,coordinateSystem:'blueprint',rooms:places.filter(p=>!p.outdoor).map(p=>{
    
    let m=data.registration.matrix,o=data.registration.offset,det=m[0][0]*m[1][1]-m[0][1]*m[1][0],x=p.pos[0]-o[0],y=p.pos[1]-o[1];
    return {id:p.id,code:p.code,name:p.name,building:p.building||p.code[0],floor:p.floor,x:(x*m[1][1]-y*m[0][1])/det,y:(y*m[0][0]-x*m[1][0])/det,type:p.category,visible:!p.hidden,important:p.important!==false,node:p.node||null,...(Number.isInteger(p.region)?{region:p.region}:{})}
  })}
}
async function importRoomCatalogue(file){
  
  if(!file)
  {
    
    return;
  }
  let before=editSnapshot();
  try{
    
    if(file.size>1024*1024)
    {
      
      throw Error('Raumkatalog zu groß (maximal 1 MB).');
    }
    const raw=Config.validateRooms(JSON.parse(await file.text())),incoming=new Map(raw.rooms.map(r=>[r.id,r]));
    for(const p of places.filter(p=>!p.outdoor)){
      
      if(!incoming.has(p.id)){
        
        p.hidden=true;
        continue
      }
      let r=incoming.get(p.id);
      if(r.floor!==p.floor)
      {
        
        p.region=undefined;
      }
      if(r.floor!==p.floor&&p.node&&graph.get(p.node)?.f!==r.floor)
      {
        
        p.node=null;
      }
      Object.assign(p,{code:r.code,name:r.name,building:r.building,floor:r.floor,pos:world(r.x,r.y),category:r.type,hidden:!r.visible,important:r.important});
      incoming.delete(p.id)
    }
    for(const r of incoming.values()){
      
      if(!r.id.startsWith('dev-'))
      {
        
        throw Error('Neue Raum-IDs müssen mit dev- beginnen.');
      }
      if(places.some(p=>p.id===r.id))
      {
        
        throw Error('Raum-ID bereits vergeben.');
      }
      places.push({id:r.id,code:r.code,name:r.name,building:r.building,floor:r.floor,pos:world(r.x,r.y),category:r.type,hidden:!r.visible,important:r.important,custom:true,outdoor:false,node:r.node&&graph.get(r.node)?.f===r.floor?r.node:null})
    }
    editChanged(before);
    saveEdits();
    editor.message='Raumkatalog übernommen. Neue Räume im Werkzeug Wege anschließen.';
    syncFloorRooms();
    renderList();
    renderDashboard();
    updateEditor();
    drawMap()
  }catch(err){
    
    restoreEdit(before);
    editor.message=err.message;
    updateEditor()
  }finally{
    
    $('#room-file').value=''
  }
}
function syncFloorRooms(){
  
  for(const f of ['EG','OG'])
  {
    
    data.floors[f].rooms=places.filter(p=>p.floor===f&&!p.outdoor)
  }
}
