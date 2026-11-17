'use strict';
function selectPlace(p){
  
  if(!p||p.hidden)
  {
    
    return;
  }
  recordRecent(p.id);
  selected=p;
  if(!p.outdoor&&p.floor!==floor)
  {
    
    setFloor(p.floor);
  }else 
  {
    
    drawMap();
  }
  let card=$('#place-card');
  card.hidden=false;
  card.innerHTML=`<button class="close-card" aria-label="Auswahl schließen">×</button><span class="eyebrow">${esc(p.floor==='Gelände'?'AUF DEM GELÄNDE':p.floor+' · GEBÄUDE '+p.code[0])}</span><h3>${esc(p.code)}</h3><p>${esc(p.name)}${!p.outdoor?(p.node?'<br>Tür-/Flurpunkt hinterlegt.':'<br>Türanschluss noch offen.'):''}</p><div class="card-actions"><button data-use="start">Als Start</button><button data-use="end">Als Ziel ↗</button></div><div class="place-extras"><button id="place-favorite" aria-pressed="${preferences.favorites.includes(p.id)}">${preferences.favorites.includes(p.id)?'★ Favorit':'☆ Merken'}</button><button id="place-location">Ich bin hier</button><button id="place-link">Standort-Link</button></div><p id="place-link-status" role="status"></p>`;
  $('#place-favorite').onclick=()=>{
    
    toggleFavorite(p.id);
    $('#place-favorite').textContent=preferences.favorites.includes(p.id)?'★ Favorit':'☆ Merken';
    $('#place-favorite').setAttribute('aria-pressed',String(preferences.favorites.includes(p.id)))
  };
  $('#place-location').onclick=()=>{
    
    setCurrentLocation(p);
    card.hidden=true
  };
  $('#place-link').onclick=async()=>{
    
    let link=locationLink(p);
    try{
      
      await navigator.clipboard.writeText(link);
      $('#place-link-status').textContent='Standort-Link kopiert. Kann als QR-Code gedruckt werden.'
    }catch{
      
      $('#place-link-status').textContent=link
    }
  };
  card.querySelector('.close-card').onclick=()=>{
    
    card.hidden=true;
    selected=null;
    drawMap()
  };
  card.querySelectorAll('[data-use]').forEach(b=>b.onclick=()=>{
    
    setEndpoint(b.dataset.use,p);
    card.hidden=true;
    if(innerWidth<=700)
    {
      
      $('.sidebar').classList.add('open')
    }
  })
}

function setEndpoint(which,p){
  
  if(which==='start')
  {
    
    start=p;
  }else 
  {
    
    end=p;
  }
  $('#'+which).value=p.code+(p.outdoor?'':' · '+p.floor);
  $('#suggestions-'+which).hidden=true;
  $('#'+which).setAttribute('aria-expanded','false');
  $('#route').disabled=!(start&&end);
  clearRoute(false)
}

function bindSearch(which){
  
  let input=$('#'+which),box=$('#suggestions-'+which);
  function show(){
    
    let list=matchPlaces(input.value).slice(0,30);
    box.hidden=false;
    input.setAttribute('aria-expanded','true');
    box.innerHTML=list.length?list.map(p=>`<button type="button" role="option" data-id="${esc(p.id)}">${esc(p.code)} <small>${esc(p.floor)} · ${esc(p.name)}</small></button>`).join(''):'<div class="empty">Kein passendes Ziel gefunden</div>';
    box.querySelectorAll('button').forEach(b=>b.onclick=e=>{
      
      e.preventDefault();
      setEndpoint(which,places.find(p=>p.id===b.dataset.id))
    })
  }
  input.addEventListener('focus',()=>{
    
    if((which==='start'?start:end))
    {
      
      input.select();
    }
    show()
  });
  input.addEventListener('input',()=>{
    
    if(which==='start')
    {
      
      start=null;
    }else 
    {
      
      end=null;
    }
    $('#route').disabled=true;
    clearRoute(false);
    show()
  });
  input.addEventListener('blur',()=>{
    
    setTimeout(()=>{
      
      if(!box.contains(document.activeElement)&&document.activeElement!==input){
        box.hidden=true;
        input.setAttribute('aria-expanded','false')
      }
    },130)
  });
  input.addEventListener('keydown',e=>{
    
    if(e.key==='Escape'){
      
      box.hidden=true;
      input.blur()
    }
    if(e.key==='ArrowDown'){
      
      e.preventDefault();
      box.querySelector('button')?.focus()
    }
    if(e.key==='Enter'){
      
      let p=matchPlaces(input.value)[0];
      if(p){
        
        setEndpoint(which,p);
        input.blur()
      }
    }
  });
  box.addEventListener('keydown',e=>{
    
    let b=[...box.querySelectorAll('button')],i=b.indexOf(document.activeElement);
    if(e.key==='ArrowDown'){
      
      e.preventDefault();
      b[(i+1)%b.length]?.focus()
    }
    if(e.key==='ArrowUp'){
      
      e.preventDefault();
      b[(i-1+b.length)%b.length]?.focus()
    }
    if(e.key==='Escape'){
      
      box.hidden=true;
      input.focus();
      return
    }
    if(e.key==='Enter'&&i>=0){
      
      e.preventDefault();
      setEndpoint(which,places.find(p=>p.id===b[i].dataset.id));
      input.focus();
      box.hidden=true;
      input.setAttribute('aria-expanded','false')
    }
  })
}

function renderList(){
  
  let q=$('#browse-search').value,list=matchPlaces(q).filter(p=>filter==='outdoor'?p.outdoor:filter==='all'?true:filter==='bus'||filter==='tip'?p.category===filter:filter==='classroom'?!p.outdoor&&['classroom','office','service'].includes(p.category):p.category===filter);
  if($('#important-only').checked&&!q)
  {
    
    list=list.filter(p=>p.outdoor||p.important||p.custom);
  }
  if(!q&&filter!=='wc')
  {
    
    list.sort((a,b)=>{
    
      let rank=p=>p.outdoor?0:p.name.toLowerCase().includes('sekretariat')?1:p.floor===floor?2:3;
      return rank(a)-rank(b)||a.code.localeCompare(b.code,'de',{numeric:true})
    });
  }
  $('#count').textContent=list.length+' Ziele';
  $('#places').innerHTML=list.length?list.slice(0,120).map(p=>`<button class="place-row" data-id="${esc(p.id)}"><span class="place-symbol ${p.outdoor?'outdoor':p.category}">${uiIcon(p.category)}</span><span class="place-label"><strong>${esc(p.code)}</strong><small>${esc(p.floor)} · ${esc(p.name)}</small></span><span class="arrow">↗</span></button>`).join(''):'<p class="empty">'+esc(emptyPlacesHint())+'</p>';
  $('#places').querySelectorAll('button').forEach(b=>b.onclick=()=>{
    
    selectPlace(places.find(p=>p.id===b.dataset.id));
    if(innerWidth<=700)
    {
      
      $('.sidebar').classList.remove('open')
    }
  })
}
