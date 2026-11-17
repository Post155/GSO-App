'use strict';
function bindMapInteractions(){

  svg.addEventListener('wheel',e=>{
    
    e.preventDefault();
    let r=svg.getBoundingClientRect();
    zoom(e.deltaY>0?1.12:.89,(e.clientX-r.left)/r.width,(e.clientY-r.top)/r.height)
  },{passive:false});
  
  svg.addEventListener('pointerdown',e=>{
    
    pointers.set(e.pointerId,[e.clientX,e.clientY]);
    moved=false;
    if(pointers.size===1)
    {
      
      drag={x:e.clientX,y:e.clientY,view:[...view]};
    }
    if(pointers.size===2){
      
      let p=[...pointers.values()];
      pinch={distance:Math.hypot(p[0][0]-p[1][0],p[0][1]-p[1][1]),view:[...view]};
      drag=null
    }
    if(e.target===svg||!e.target.closest('[data-place],[data-region]'))
    {
      
      svg.setPointerCapture(e.pointerId)
    }
  });
  svg.addEventListener('pointermove',e=>{
    
    if(!pointers.has(e.pointerId))
    {
      
      return;
    }
    pointers.set(e.pointerId,[e.clientX,e.clientY]);
    if(pointers.size===2&&pinch){
      
      let p=[...pointers.values()],d=Math.hypot(p[0][0]-p[1][0],p[0][1]-p[1][1]);
      if(d>1){
        
        view=[...pinch.view];
        zoom(pinch.distance/d);
      }
      moved=true
    }else 
    {
      
      if(drag){
      
        let rect=svg.getBoundingClientRect(),scale=Math.min(rect.width/drag.view[2],rect.height/drag.view[3]);
        let dx=e.clientX-drag.x,dy=e.clientY-drag.y;
        if(Math.abs(dx)+Math.abs(dy)>4)
      {
          
          moved=true;
        }
        view=[drag.view[0]-dx/scale,drag.view[1]-dy/scale,drag.view[2],drag.view[3]];
        applyView()
      }
    }
  });
  function release(e){
    
    pointers.delete(e.pointerId);
    drag=null;
    pinch=null;
    if(pointers.size===1){
      
      let p=[...pointers.values()][0];
      drag={x:p[0],y:p[1],view:[...view]}
    };
    if(svg.hasPointerCapture(e.pointerId))
    {
      
      svg.releasePointerCapture(e.pointerId)
    }
  }
  svg.addEventListener('pointerup',release);
  svg.addEventListener('pointercancel',release);
  svg.addEventListener('click',e=>{
    
    if(moved){
      
      e.stopImmediatePropagation();
      moved=false
    }
  },true);
  $('#map').addEventListener('keydown',e=>{
    
    let amount=view[2]*.08;
    if(e.target.closest('input,button,select,textarea'))
    {
      
      return;
    }
    if(e.key==='+'||e.key==='=')
    {
      
      zoom(.85);
    }else 
    {
      
      if(e.key==='-')
    {
        
        zoom(1.15);
      }else 
    {
        
        if(e.key==='ArrowLeft')
    {
          
          view[0]-=amount;
        }else 
    {
          
          if(e.key==='ArrowRight')
    {
            
            view[0]+=amount;
          }else 
    {
            
            if(e.key==='ArrowUp')
    {
              
              view[1]-=amount;
            }else 
    {
              
              if(e.key==='ArrowDown')
    {
                
                view[1]+=amount;
              }else 
    {
                
                return;
              }
            }
          }
        }
      }
    }
    e.preventDefault();
    applyView()
  });

}
