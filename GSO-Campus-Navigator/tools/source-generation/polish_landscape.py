from pathlib import Path
import json,copy,math
import numpy as np
root=Path(__file__).resolve().parents[2];p=root/'dist/assets/completed-map.json';data=json.loads(p.read_text());before=copy.deepcopy(data)
from geometry import simplify,signed,simple,hash_loops
source={a['id']:a for a in json.loads((root/'dist/assets/completion-context.json').read_text())['areas']};existing=json.loads((root/'dist/assets/landscape-migration.json').read_text())if(root/'dist/assets/landscape-migration.json').exists()else{}
migrations={};counts={'areas':0,'before':0,'after':0}
for a in data['areas']:
 if a.get('completionLayer')!='background' or a['kind']!='green':continue
 old=copy.deepcopy(a['loops']);new=[]
 for loop in old:
  bounds=np.ptp(np.array(loop),axis=0);epsilon=min(12,max(3.5,float(bounds.min())*.12));q=simplify(loop,epsilon)
  ratio=abs(signed(q))/max(abs(signed(loop)),1)
  if not simple(q)or not(.72<ratio<1.28):q=simplify(loop,epsilon*.5)
  if not simple(q):q=loop
  new.append(q)
 a['loops']=new;a['outlineVersion']=2;a['landscapeVersion']=1;a['edgeStyle']='rounded';a['cornerRadius']=18
 hashes={hash_loops(old),hash_loops(source[a['id']]['loops'])}
 if a['id']in existing:hashes.update(existing[a['id']]['beforeHashes'])
 migrations[a['id']]={'beforeHashes':sorted(hashes),'loops':new,'cornerRadius':18}
 counts['areas']+=1;counts['before']+=sum(map(len,old));counts['after']+=sum(map(len,new))
for k in ['points','pointNodes','pointMeta','customPlaces','hiddenPoints','nodes','scenery']:assert data[k]==before[k]
for a,b in zip(data['areas'],before['areas']):
 if a.get('kind')!='green' or a.get('completionLayer')!='background':assert a==b
p.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')));(root/'dist/assets/landscape-migration.json').write_text(json.dumps(migrations,separators=(',',':')));print(counts)
