from pathlib import Path
import json,math,copy,hashlib
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as nd
root=Path(__file__).resolve().parents[2]
original=json.loads((root/'dist/assets/manual-original.json').read_text());result=copy.deepcopy(original)
context=json.loads((root/'dist/assets/completion-context.json').read_text())
# User drawings take precedence over the context layer; no user geometry is recomputed.
for a in context['areas']:
 if a['id']=='dev-context-9-1':a['name']='Schulhof';a['kind']='paving';a['color']='#718492'
result['areas']+=context['areas']
# Thin the reference's street surface to find only missing drawing sections.
mask=np.array(Image.open(root/'context-roads-mask.png'))>0
mask=nd.binary_closing(mask,iterations=1)
def thin(img):
 a=np.pad(img.astype(np.uint8),1)
 for _ in range(85):
  changes=0
  for step in (0,1):
   p=[a[:-2,1:-1],a[:-2,2:],a[1:-1,2:],a[2:,2:],a[2:,1:-1],a[2:,:-2],a[1:-1,:-2],a[:-2,:-2]];n=sum(p);trans=sum((p[i]==0)&(p[(i+1)%8]==1) for i in range(8));c=a[1:-1,1:-1]
   cut=(c==1)&(n>=2)&(n<=6)&(trans==1)
   if step==0:cut&=(p[0]*p[2]*p[4]==0)&(p[2]*p[4]*p[6]==0)
   else:cut&=(p[0]*p[2]*p[6]==0)&(p[0]*p[4]*p[6]==0)
   count=int(cut.sum());c[cut]=0;changes+=count
  if not changes:break
 return a[1:-1,1:-1].astype(bool)
sk=thin(mask)
# Extract whole polylines first, then discard those already represented by a user street.
H,W=sk.shape
pixels=set(zip(*np.where(sk)))
def adjacent(p):
 y,x=p;return [(y+dy,x+dx)for dy in(-1,0,1)for dx in(-1,0,1)if(dx or dy)and(y+dy,x+dx)in pixels]
neigh={p:adjacent(p)for p in pixels};junctions={p for p in pixels if len(neigh[p])!=2};visited=set();lines=[]
for start in sorted(junctions):
 for nxt in neigh[start]:
  key=tuple(sorted((start,nxt)))
  if key in visited:continue
  pts=[start];prev=start;cur=nxt;visited.add(key)
  while True:
   pts.append(cur)
   if cur in junctions:break
   options=[q for q in neigh[cur]if q!=prev]
   if not options:break
   nxt=options[0];key=tuple(sorted((cur,nxt)))
   if key in visited:break
   visited.add(key);prev,cur=cur,nxt
  if len(pts)>3:lines.append(pts)
def world(p):return [p[1]*2.48-1750,p[0]*2.48-840]
def project(p,a,b):
 p=np.array(p);a=np.array(a);b=np.array(b);v=b-a;t=float(np.dot(p-a,v)/max(np.dot(v,v),1e-9));q=a+np.clip(t,0,1)*v;return float(np.linalg.norm(p-q)),q.tolist()
segments=[(a,b)for s in original['scenery']for a,b in zip(s.get('points',[]),s.get('points',[])[1:])]
def nearest(p):return min((project(p,a,b)for a,b in segments),key=lambda q:q[0])
cover=Image.new('1',(W,H));draw=ImageDraw.Draw(cover)
for s in original['scenery']:
 pts=[((p[0]+1750)/2.48,(p[1]+840)/2.48)for p in s.get('points',[])];
 if len(pts)>1:draw.line(pts,fill=1,width=max(14,round(s.get('width',20)/2.48+12)))
covered=np.array(cover,dtype=bool)
# Suppress road extraction inside the user-authored campus and near map controls.
Y,X=np.indices((H,W));wx=X*2.48-1750;wy=Y*2.48-840
campus=(wx>-60)&(wx<610)&(wy>130)&(wy<820)
covered|=campus;covered[:155,1620:]=True;covered[810:,1620:]=True;covered[870:,1250:]=True
widths=nd.distance_transform_edt(mask)
def rdp(p,eps=2.4):
 if len(p)<3:return p
 a=np.array(p);v=a[-1]-a[0];l=float(v@v);t=np.clip(((a-a[0])@v)/max(l,1e-9),0,1);d=np.linalg.norm(a-(a[0]+t[:,None]*v),axis=1);i=int(np.argmax(d))
 if d[i]>eps:return rdp(p[:i+1],eps)[:-1]+rdp(p[i:],eps)
 return [p[0],p[-1]]
added=[]
for line in lines:
 chunks=[];current=[]
 for p in line:
  if covered[p]:
   if len(current)>3:chunks.append(current)
   current=[]
  else:current.append(p)
 if len(current)>3:chunks.append(current)
 for chunk in chunks:
  pts=[world(p)for p in chunk];length=sum(math.dist(a,b)for a,b in zip(pts,pts[1:]))
  if length<55:continue
  pts=rdp(pts)
  for k in(0,-1):
   distance,q=nearest(pts[k])
   if distance<38:pts[k]=q
  width=float(np.median([widths[p]for p in chunk])*2*2.48)
  kind='footway'if width<10 else'road';width=max(4,min(34,width))
  added.append({'id':f'dev-completed-line-{len(added)+1}','kind':kind,'name':'','points':pts,'width':round(width,2),'color':'#526b7c'if kind=='road'else'#88958c','f':'Gelände','builtin':False,'label':False,'completionSource':'Neue Region – Karte'})
result['scenery']+=added
# The marked smoking area already contains a walk node; add its missing destination without changing routes.
smoke_area=next(a for a in original['areas'] if a['name']=='Raucherbereich')
def inside(p,loop):
 hit=False
 for i,a in enumerate(loop):
  b=loop[i-1]
  if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:hit=not hit
 return hit
smoke_node=next((n for n in original['nodes']if n['f']=='Gelände' and inside(n['pos'],smoke_area['loops'][0])),None)
if smoke_node:
 pid='dev-place-completed-smoking';meta={'code':'Raucherbereich','name':'Im eingezeichneten Raucherbereich','category':'smoking'}
 result['customPlaces'].append({'id':pid,**meta,'floor':'Gelände','outdoor':True});result['points'][pid]=copy.deepcopy(smoke_node['pos']);result['pointNodes'][pid]=smoke_node['id'];result['pointMeta'][pid]=meta
# Every existing value that affects a route remains exactly as supplied.
for k in ['points','pointNodes','pointMeta']:
 for id,value in original[k].items():assert result[k][id]==value,(k,id)
for k in ['hiddenPoints','nodes']:assert result[k]==original[k],k
assert result['customPlaces'][:len(original['customPlaces'])]==original['customPlaces']
assert result['scenery'][:len(original['scenery'])]==original['scenery']
assert result['areas'][:len(original['areas'])]==original['areas']
result['completionInfo']={'source':'Neue Region – Karte','sourceAsset':'Referenz-Karte.png','sourceSHA256':hashlib.sha256((root/'dist/assets/Referenz-Karte.png').read_bytes()).hexdigest(),'imageToWorld':[[2.48,0],[0,2.48],[-1750,-840]],'viewBox':[-1800,-890,4350,2380],'addedAreas':len(context['areas']),'addedLines':len(added),'protectedUserScenery':[s['id']for s in original['scenery']]}
(root/'dist/assets/completed-map.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
print('Completed',len(context['areas']),'context areas and',len(added),'missing drawing segments; all user points, nodes, edges, areas and existing scene records unchanged.')
