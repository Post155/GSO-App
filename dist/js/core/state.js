'use strict';
const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const clone = value => JSON.parse(JSON.stringify(value));
const SCHOOL_VIEW = [-35,125,650,680];
const NEIGHBOURHOOD_VIEW = [-1750,-840,4220,2264];
const sceneDefaults = {road:'#526b7c',footway:'#88958c',tree:'#4f765f'};
const icons = {classroom:'▤',office:'▥',service:'◇',wc:'WC',stairs:'↗',lift:'↕',corridor:'↔',entrance:'↪',gate:'↪',parking:'P',bicycle:'♧',smoking:'≈',bus:'H',tip:'★',marker:'•'};
let data, places=[], floor='EG', filter='all', selected=null, routePath=null, start=null, end=null;
let base=[...SCHOOL_VIEW],view=[...base],mapMode='school',drag=null,pinch=null,moved=false;
let indoorNavigation=null,outlineMigration=null,landscapeMigration=null,completedData=null;
let currentLocation=null,routeChoices=[],routeChoice=0,renderPending=false,configRooms=null;
const svg=$('#map-svg'),content=$('#map-content'),graph=new Map(),pointers=new Map();
let outside=[];
function world(x,y){
  
  const {matrix:m,offset:o}=data.registration;
  return [m[0][0]*x+m[0][1]*y+o[0],m[1][0]*x+m[1][1]*y+o[1]]
}
function addNode(id,pos,f,meta={}){
  
  if(!graph.has(id))
  {
    
    graph.set(id,{id,pos:[...pos],f,edges:[],...meta});
  }
  return id
}
function edge(a,b,type='walk'){
  
  let x=graph.get(a),y=graph.get(b);
  if(!x||!y||a===b)
  {
    
    return;
  }
  for(const [n,to]of [[x,b],[y,a]])
  {
    
    if(!n.edges.some(e=>e.to===to))
  {
      
      n.edges.push({to,type,verified:false,cost:0});
    }
  }
  reweight()
}
/** Coalesce pointer-drag redraws to one frame; committed edits still draw immediately. */
function scheduleDraw(){
  
  if(renderPending)
  {
    
    return;
  }
  renderPending=true;
  requestAnimationFrame(()=>{
    
    renderPending=false;
    drawMap()
  })
}
function emptyPlacesHint(){
  
  return 'Keine passenden Ziele. Versuche eine Raumnummer, Etage oder Kategorie.'
}

let backgroundCache=null;
