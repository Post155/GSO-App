'use strict';
/** Dependency-free routing kernel. No DOM or mutable application state. */
const Routing = (() => {
  
  class MinHeap {
    constructor(){
    
    this.items=[]
  }
    push(value){
    
    let a=this.items,i=a.length;
    a.push(value);
    while(i){
      
      let p=(i-1)>>1;
      if(a[p][0]<=value[0])
      {
        
        break;
      }
      a[i]=a[p];
      i=p
    }
    a[i]=value
  }
    pop(){
    
    let a=this.items,first=a[0],last=a.pop();
    if(a.length){
      
      let i=0;
      while(i*2+1<a.length){
        
        let c=i*2+1;
        if(c+1<a.length&&a[c+1][0]<a[c][0])
        {
          
          c++;
        }
        if(a[c][0]>=last[0])
        {
          
          break;
        }
        a[i]=a[c];
        i=c
      }
      a[i]=last
    }
    return first
  }
    get size(){
    
    return this.items.length
  }
  }
  const key=(a,b)=>a<b?a+'|'+b:b+'|'+a;
  /** Dijkstra with stale-entry rejection; O((V+E) log V), nonnegative costs only. */
  function shortest(nodes,start,end,options={}){
    
    if(!nodes.has(start)||!nodes.has(end))
    {
      
      return null;
    }
    let queue=new MinHeap(),distance=new Map([[start,0]]),previous=new Map();
    queue.push([0,start]);
    while(queue.size){
      
      let [cost,id]=queue.pop();
      if(cost!==distance.get(id))
      {
        
        continue;
      }
      if(id===end){
        
        let path=[id];
        while(previous.has(id)){
          
          id=previous.get(id);
          path.push(id)
        }
        return {ids:path.reverse(),cost}
      }
      let node=nodes.get(id);
      for(const edge of node.edges){
        
        let target=nodes.get(edge.to);
        if(!target||!Number.isFinite(edge.cost)||edge.cost<0)
        {
          
          continue;
        }
        if(options.stepFree&&edge.type==='stairs'||!options.stepFree&&edge.type==='lift')
        {
          
          continue;
        }
        if(node.f!==target.f&&!edge.verified)
        {
          
          continue;
        }
        if(options.banned?.has(key(id,edge.to))||options.bannedNodes?.has(edge.to)||options.blocked?.(node,target))
        {
          
          continue;
        }
        let next=cost+edge.cost+(options.penalties?.get(key(id,edge.to))||0);
        if(next<(distance.get(edge.to)??Infinity)){
          
          distance.set(edge.to,next);
          previous.set(edge.to,id);
          queue.push([next,edge.to])
        }
      }
    }
    return null;
  }
  /** One genuine alternative: ban each edge of the optimum and retain the cheapest distinct path. */
  function alternatives(nodes,start,end,options={}){
    
    const first=shortest(nodes,start,end,options);
    if(!first||first.ids.length<2)
    {
      
      return first?[first]:[];
    }
    let second=null;
    for(let i=1;i<first.ids.length;i++){
      
      let banned=new Set(options.banned||[]);
      banned.add(key(first.ids[i-1],first.ids[i]));
      let candidate=shortest(nodes,start,end,{...options,banned});
      if(candidate&&(!second||candidate.cost<second.cost))
      {
        
        second=candidate
      }
    }
    return second?[first,second]:[first];
  }
  return {shortest,alternatives,MinHeap,key};
})();
if(typeof module!=='undefined'&&module.exports)
{
  
  module.exports=Routing;
}
