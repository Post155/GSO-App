'use strict';
const normalizeSearch=value=>String(value).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/ß/g,'ss').replace(/[^a-z0-9]/g,'');
const searchAliases={wc:'wc toilette toiletten toilet restroom',office:'buro buero office sekretariat empfang besprechung',classroom:'raum schulung klassenraum classroom training',stairs:'treppe treppenhaus stairs',lift:'aufzug lift elevator',parking:'parken auto parkplatz parking',bicycle:'fahrrad rad bike',entrance:'eingang ausgang entrance exit',bus:'bus haltestelle stop',service:'technik lager service',smoking:'raucher smoking'};
function searchPlaces(query,{allModes=false}={}){
  
  let building=/^[abcd]\s*$/i.test(query)?query.trim().toUpperCase():null;
  let tokens=query.trim().split(/\s+/).filter(Boolean).map(normalizeSearch);
  return places.filter(p=>!p.hidden&&(!building||p.building===building)&&(allModes||placeInMode(p))).map(p=>{
    
    let code=normalizeSearch(p.code),text=normalizeSearch([p.code,p.name,p.floor,p.building,searchAliases[p.category]||''].join(' '));
    if(!tokens.every(t=>text.includes(t)))
    {
      
      return null;
    }
    let score=tokens.reduce((s,t)=>s+(code===t?100:code.startsWith(t)?50:text.startsWith(t)?20:5),0);
    return {p,score}
  }).filter(Boolean).sort((a,b)=>b.score-a.score||a.p.code.localeCompare(b.p.code,'de',{numeric:true})).map(x=>x.p)
}
function matchPlaces(query){
  
  return searchPlaces(query)
}
