const {performance}=require('node:perf_hooks'),{boot}=require('../tests/application.cjs'),Routing=require('../dist/js/navigation/engine.js');
(async()=>{const b=await boot(),nodes=new Map(JSON.parse(b.run('JSON.stringify([...graph])'))),targets=[...nodes.values()].filter(n=>n.f==='EG'&&n.edges.length>0).slice(0,80),pairs=targets.map((n,i)=>[n.id,targets[(i+37)%targets.length].id]);
function linear(a,z){let costs=new Map([[a,0]]),open=new Set([a]);while(open.size){let cur=[...open].reduce((x,y)=>costs.get(x)<costs.get(y)?x:y);open.delete(cur);if(cur===z)return costs.get(cur);for(const e of nodes.get(cur).edges){if(e.type==='lift')continue;let c=costs.get(cur)+e.cost;if(c<(costs.get(e.to)??Infinity)){costs.set(e.to,c);open.add(e.to)}}}return Infinity}
function time(fn){let start=performance.now();for(let i=0;i<8;i++)for(const p of pairs)fn(...p);return performance.now()-start}
// Warm-up followed by identical workloads. This is a local kernel measurement, not browser latency.
for(const p of pairs){linear(...p);Routing.shortest(nodes,...p)}const linearMs=time(linear),heapMs=time((...p)=>Routing.shortest(nodes,...p));console.log(JSON.stringify({queries:pairs.length*8,nodes:nodes.size,linearMs:+linearMs.toFixed(2),heapMs:+heapMs.toFixed(2),ratio:+(linearMs/heapMs).toFixed(2)},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
