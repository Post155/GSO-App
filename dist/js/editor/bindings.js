'use strict';
function bindEditorControls(){

  $('#dev-toggle').onclick=()=>setEditor(!editor.active);
  $('#dev-close').onclick=()=>setEditor(false);
  
  $('#dev-reference').onchange=e=>{
    
    editor.reference=e.target.checked;
    updateEditor();
    drawMap()
  };
  $('#dev-opacity').oninput=e=>{
    
    editor.opacity=Number(e.target.value)/100;
    drawMap()
  };
  $('#dev-split').onclick=()=>splitEditEdge();
  
  $('#dev-undo').onclick=()=>editorUndo();
  $('#dev-redo').onclick=()=>editorUndo(true);
  $('#dev-save').onclick=saveEdits;
  $('#dev-export').onclick=exportEdits;
  $('#dev-import').onclick=()=>$('#dev-file').click();
  $('#dev-file').onchange=e=>importEdits(e.target.files[0]);
  $('#dev-reset').onclick=()=>{
    
    if(!confirm('Alle Kartenkorrekturen auf diesem Gerät auf den Ausgangsstand zurücksetzen? Du kannst sie vorher als JSON exportieren.'))
    {
      
      return;
    }
    let before=editSnapshot();
    restoreEdit(editor.baseline);
    remember(before);
    saveEdits();
    editor.message='Ausgangsstand wiederhergestellt und auf diesem Gerät gespeichert.';
    updateEditor()
  };
  svg.addEventListener('pointerdown',beginEditDrag,true);
  svg.addEventListener('pointermove',moveEditDrag,true);
  svg.addEventListener('pointerup',finishEditDrag,true);
  svg.addEventListener('pointercancel',cancelEditDrag,true);
  svg.addEventListener('click',e=>{
    
    if(editor.active){
      
      e.stopImmediatePropagation();
      moved=false
    }
  },true);
  svg.addEventListener('dblclick',e=>{
    
    if(!editor.active||editor.tool!=='paths')
    {
      
      return;
    }
    let hit=e.target.closest('[data-edit-kind="edge"]')||document.elementFromPoint(e.clientX,e.clientY)?.closest('[data-edit-kind="edge"]');
    if(!hit)
    {
      
      return;
    }
    e.preventDefault();
    e.stopImmediatePropagation();
    editor.selection={kind:'edge',id:hit.dataset.editId};
    splitEditEdge(mapPoint(e))
  },true);
  svg.addEventListener('keydown',e=>{
    
    if(!editor.active)
    {
      
      return;
    }
    let hit=e.target.closest('[data-edit-kind]');
    if(hit)
    {
      
      editor.selection={kind:hit.dataset.editKind,id:hit.dataset.editId};
    }
    if(e.key==='Escape'){
      
      if(editor.draft){
        
        editor.draft=null;
        updateEditor();
        drawMap()
      }else 
      {
        
        setEditor(false);
      }
      e.stopImmediatePropagation();
      return
    }
    if(!editor.selection)
    {
      
      return;
    }
    let dx=0,dy=0,step=e.shiftKey?5:1;
    if(e.key==='ArrowLeft')
    {
      
      dx=-step;
    }else 
    {
      
      if(e.key==='ArrowRight')
    {
        
        dx=step;
      }else 
    {
        
        if(e.key==='ArrowUp')
    {
          
          dy=-step;
        }else 
    {
          
          if(e.key==='ArrowDown')
    {
            
            dy=step;
          }else 
    {
            
            if(e.key==='Delete'||e.key==='Backspace'){
      
              e.preventDefault();
              e.stopImmediatePropagation();
              deleteEditNode();
              return
            }else 
    {
              
              return;
            }
          }
        }
      }
    }
    e.preventDefault();
    e.stopImmediatePropagation();
    let before=editSnapshot(),key={...editor.selection};
    moveEditSelection(key,dx,dy,before);
    editChanged(before);
    svg.querySelector(`[data-edit-kind="${key.kind}"][data-edit-id="${CSS.escape(key.id)}"]`)?.focus()
  },true);
  document.addEventListener('keydown',e=>{
    
    if(!editor.active||e.target.matches('input,textarea,select')||!(e.ctrlKey||e.metaKey))
    {
      
      return;
    }
    if(e.key.toLowerCase()==='z'){
      
      e.preventDefault();
      editorUndo(e.shiftKey)
    }
    if(e.key.toLowerCase()==='s'){
      
      e.preventDefault();
      saveEdits()
    }
  });
  window.addEventListener('beforeunload',e=>{
    
    if(editor.dirty){
      
      e.preventDefault();
      e.returnValue=''
    }
  });
  $('#dev-area-pick').onchange=e=>{
    
    editor.selection=e.target.value?{kind:'area',id:e.target.value}:null;
    updateEditor();
    drawMap()
  };
  $('#dev-point-node').onclick=()=>{
    
    let p=currentPoint();
    if(!p)
    {
      
      return;
    }
    if(!p.node||!graph.has(p.node)){
      
      let before=editSnapshot();
      p.node=devId('node');
      addNode(p.node,[...p.pos],p.floor);
      editChanged(before)
    }
    editor.tool='paths';
    editor.scope=p.outdoor?'Gelände':'floor';
    editor.selection={kind:'node',id:p.node};
    editor.message='Mit „Neuen Weg zeichnen“ oder „Wegpunkt verbinden“ an das Wegenetz anschließen.';
    updateEditor();
    drawMap()
  };
  $('#dev-new-point').onclick=()=>startDraft('point');
  $('#dev-new-path').onclick=()=>startDraft('path');
  $('#dev-new-area').onclick=()=>startDraft('area');
  
  $('#dev-cancel-draft').onclick=()=>{
    
    editor.draft=null;
    updateEditor();
    drawMap()
  };
  $('#dev-pop-draft').onclick=()=>{
    
    editor.draft?.points.pop();
    updateEditor();
    drawMap()
  };
  $('#dev-add-vertex').onclick=addAreaVertex;
  $('#dev-apply-properties').onclick=applyProperties;
  $('#dev-connect').onclick=connectSelected;
  $('#dev-reference-kind').onchange=e=>{
    
    editor.referenceKind=e.target.value;
    drawMap()
  };
  
  $('#dev-area-kind').onchange=e=>{
    
    if(areaColors[e.target.value])
    {
      
      $('#dev-color').value=areaColors[e.target.value];
    }
    if(e.target.value==='blocked')
    {
      
      $('#dev-blocked').checked=true
    }
  };
  $('#dev-scope').onchange=e=>{
    
    editor.scope=e.target.value;
    editor.draft=null;
    editor.selection=null;
    updateEditor();
    drawMap()
  };
  document.addEventListener('keydown',e=>{
    
    if(!editor.active||e.target.matches('input,textarea,select'))
    {
      
      return;
    }
    if(e.key==='Escape'&&editor.draft){
      
      editor.draft=null;
      updateEditor();
      drawMap();
      e.preventDefault()
    }
    if(e.key==='Enter'&&editor.draft){
      
      finishDraft();
      e.preventDefault()
    }
  });
  updateEditor()
  $$('[data-dev-tool]').forEach(b=>b.onclick=()=>{
    
    editor.tool=b.dataset.devTool;
    editor.scope=['roads','trees'].includes(editor.tool)?'Gelände':editor.scope;
    $('#dev-scope').value=editor.scope;
    editor.draft=null;
    editor.selection=null;
    updateEditor();
    drawMap()
  });
  $('#dev-new-tree').onclick=()=>startDraft('tree');
  $('#dev-new-road').onclick=()=>startDraft('road');
  $('#dev-new-footway').onclick=()=>startDraft('footway');
  $('#dev-finish').onclick=()=>finishDraft();
  $('#dev-delete').onclick=()=>deleteEditNode();
  $('#dev-scenery-pick').onchange=e=>{
    
    editor.selection=e.target.value?{kind:'scenery',id:e.target.value}:null;
    updateEditor();
    drawMap()
  };
  $('#dev-apply-scene').onclick=applySceneProperties;
  $('#dev-road-vertex').onclick=addSceneryVertex;
  $('#dev-road-to-path').onclick=sceneryToPath;
}
