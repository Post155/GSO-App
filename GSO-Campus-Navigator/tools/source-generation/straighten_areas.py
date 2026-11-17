from geometry import signed,rdp,simplify,proper_cross,simple,orthogonal,hash_loops
from pathlib import Path
import json,math,copy
import numpy as np
root=Path(__file__).resolve().parents[2]
p=root/'dist/assets/completed-map.json'
data=json.loads(p.read_text())
source_context={a['id']:a for a in json.loads((root/'dist/assets/completion-context.json').read_text())['areas']}
for a in data['areas']:
 if a.get('completionLayer')=='background' and a['id'] in source_context:
  a['loops']=copy.deepcopy(source_context[a['id']]['loops'])
  for key in ['outlineVersion','edgeStyle','cornerRadius']:a.pop(key,None)
before=copy.deepcopy(data)





changes={};stats={'building':0,'orthogonal':0,'other':0,'before':0,'after':0}
for a in data['areas']:
 if a.get('completionLayer')!='background':continue
 old=copy.deepcopy(a['loops']);clean=[];is_building=a['kind']=='building';ortho=0;curved=False
 for loop in old:
  bounds=np.ptp(np.array(loop),axis=0);eps=min(6.0,max(3.2,float(bounds.min())*.1)) if is_building else 8.0
  new=simplify(loop,eps)
  if is_building:
   ok=False
   for tolerance in [eps,min(12,eps*1.35),min(12,eps*1.7),min(12,eps*2)]:
    trial=simplify(loop,tolerance);candidate,matched=orthogonal(trial)
    ratio_original=abs(signed(candidate))/max(abs(signed(loop)),1)
    if matched and .72<ratio_original<1.28 and simple(candidate):new=candidate;ok=True;break
   ortho+=int(ok)
   if not ok:
    new=simplify(loop,min(10,eps*1.4))
    v=np.roll(np.array(new),-1,axis=0)-new;lengths=np.linalg.norm(v,axis=1);angles=np.arctan2(v[:,1],v[:,0]);coherence=abs(np.sum(lengths**2*np.exp(4j*angles)))/max(np.sum(lengths**2),1)
    if len(new)>20 and coherence<.45:curved=True
  ratio=abs(signed(new))/max(abs(signed(loop)),1)
  if not(.65<ratio<1.35)or not simple(new):new=simplify(loop,eps*.5)
  if not simple(new):new=loop
  if signed(new)*signed(loop)<0:new.reverse()
  clean.append([[round(float(x),3),round(float(y),3)]for x,y in new])
 stats['before']+=sum(map(len,old));stats['after']+=sum(map(len,clean));stats['building'if is_building else'other']+=1;stats['orthogonal']+=int(ortho>0)
 a['loops']=clean;a['outlineVersion']=1;a['edgeStyle']='straight'if (is_building and not curved) or a['kind'] in ['paving','parking'] else'rounded';a['cornerRadius']=0 if a['edgeStyle']=='straight' else 6
 changes[a['id']]={'beforeHash':hash_loops(old),'loops':clean,'outlineVersion':1,'edgeStyle':a['edgeStyle'],'cornerRadius':a['cornerRadius']}
# Original manual work and the school are intentionally not regenerated.
for key in ['points','pointNodes','pointMeta','customPlaces','hiddenPoints','nodes','scenery']:assert data[key]==before[key],key
for a,b in zip(data['areas'],before['areas']):
 if a.get('completionLayer')!='background':assert a==b,a['id']
data['completionInfo']['cleanOutlines']=stats
p.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
(root/'dist/assets/outline-migration.json').write_text(json.dumps(changes,separators=(',',':')))
print(stats)