from pathlib import Path
import fitz,json,math,heapq,collections,copy
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as nd
ROOT=Path(__file__).resolve().parents[2];ASSETS=ROOT/'dist/assets';S=2100/1190.52001953125;STEP=2
base=json.loads((ASSETS/'map-data.json').read_text());current=json.loads((ASSETS/'completed-map.json').read_text());M=np.array(base['registration']['matrix']);OFF=np.array(base['registration']['offset'])
def world(xy):return [round(float(v),4)for v in M@np.array(xy)+OFF]
def inv(p):return np.linalg.solve(M,np.array(p)-OFF)
def edge_cells(a,b):
 a=np.array(a,float);b=np.array(b,float);n=max(1,int(np.max(np.abs(b-a))*5));prev=None
 for t in np.linspace(0,1,n+1):
  p=tuple(np.rint(a+(b-a)*t).astype(int))
  if prev and p[0]!=prev[0]and p[1]!=prev[1]:yield (prev[0],p[1]);yield(p[0],prev[1])
  if p!=prev:yield p
  prev=p

def visible(a,b,free):
 for x,y in edge_cells(a,b):
  if y<0 or x<0 or y>=free.shape[0]or x>=free.shape[1]or not free[y,x]:return False
 return True

def snap(xy,free,maxdist=30):
 q=np.array(xy)/STEP-.5;x,y=np.rint(q).astype(int);best=None
 for r in range(maxdist+1):
  for yy in range(max(0,y-r),min(free.shape[0],y+r+1)):
   for xx in range(max(0,x-r),min(free.shape[1],x+r+1)):
    if abs(xx-x)!=r and abs(yy-y)!=r:continue
    if free[yy,xx]:
     d=(xx-q[0])**2+(yy-q[1])**2
     if best is None or d<best[0]:best=(d,(xx,yy))
  if best and best[0]<(r+.5)**2:return best[1]
 return best[1]if best else None

def astar(a,b,free):
 if a is None or b is None:return None
 heap=[(0,0,a)];cost={a:0};parent={}
 while heap:
  _,g,p=heapq.heappop(heap)
  if g!=cost[p]:continue
  if p==b:
   path=[p]
   while p in parent:p=parent[p];path.append(p)
   return path[::-1]
  x,y=p
  for q in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
   xx,yy=q
   if xx<0 or yy<0 or yy>=free.shape[0]or xx>=free.shape[1]or not free[yy,xx]:continue
   ng=g+1
   if ng<cost.get(q,10**9):cost[q]=ng;parent[q]=p;heapq.heappush(heap,(ng+abs(xx-b[0])+abs(yy-b[1]),ng,q))
 return None

def simplify_path(path,free):
 if not path:return []
 out=[path[0]];i=0
 while i<len(path)-1:
  best=i+1
  for j in range(i+2,min(len(path),i+100)):
   if visible(path[i],path[j],free):best=j
  out.append(path[best]);i=best
 return out

def render_walls(drawings,dx):
 im=Image.new('L',(2100,1488),255);d=ImageDraw.Draw(im)
 def xy(p):return(p.x*S+dx,p.y*S)
 for v in drawings:
  if v.get('layer')not in ['Wand','Wand Trockenbau','Stütze','Fenster']:continue
  for it in v['items']:
   if it[0]=='l':d.line([xy(it[1]),xy(it[2])],fill=0,width=1)
   elif it[0]=='c':
    p=np.array([xy(q)for q in it[1:]]);points=[]
    for t in np.linspace(0,1,7):points.append(tuple((1-t)**3*p[0]+3*(1-t)**2*t*p[1]+3*(1-t)*t*t*p[2]+t**3*p[3]))
    d.line(points,fill=0,width=1)
   elif it[0]=='re':
    r=it[1];d.rectangle([r.x0*S+dx,r.y0*S,r.x1*S+dx,r.y1*S],fill=0 if v['type']=='f'else None,outline=0,width=1)
   elif it[0]=='qu':d.polygon([xy(q)for q in it[1]],fill=0 if v['type']=='f'else None,outline=0)
 return im

def doors_from_pdf(drawings,dx):
 lines=[];arcs=[]
 for v in drawings:
  if 'Tür' not in v.get('layer',''):continue
  for it in v['items']:
   if it[0]=='l'and 2<abs(it[2]-it[1])<18:lines.append((it[1],it[2]))
   if it[0]!='c':continue
   p0,p1,p2,p3=it[1:];sx=abs(p3.x-p0.x);sy=abs(p3.y-p0.y)
   if not(2.7<sx<15 and 2.7<sy<15 and abs(sx-sy)<.15):continue
   vertical=abs(p1.x-p0.x)<.1 and abs(p3.y-p2.y)<.1
   horizontal=abs(p1.y-p0.y)<.1 and abs(p3.x-p2.x)<.1
   if not(vertical or horizontal):continue
   center=fitz.Point(p3.x,p0.y)if vertical else fitz.Point(p0.x,p3.y)
   scores=[]
   for endpoint in [p0,p3]:scores.append(min((min(abs(a-center)+abs(b-endpoint),abs(b-center)+abs(a-endpoint))for a,b in lines),default=1e6))
   # Score after collecting all lines, since leaf and arc can occur in either order.
   arcs.append((center,p0,p3,v.get('layer')))
 doors=[]
 for center,p0,p3,layer in arcs:
  scores=[min((min(abs(a-center)+abs(b-p),abs(b-center)+abs(a-p))for a,b in lines),default=1e6)for p in [p0,p3]]
  leaf=0 if scores[0]<scores[1]else 1;closed=[p0,p3][1-leaf]
  a=np.array([center.x*S+dx,center.y*S]);b=np.array([closed.x*S+dx,closed.y*S]);mid=(a+b)/2
  if any(np.linalg.norm(mid-np.array(d['xy']))<2 for d in doors):continue
  doors.append({'xy':mid.tolist(),'opening':[a.tolist(),b.tolist()],'leafMatched':min(scores)<1,'layer':layer})
 return doors

nodes={};floor_data={};all_doors=[];validation=[]
def node_id(f,p):return f'dev-indoor-{f.lower()}-p-{p[0]}-{p[1]}'
def add_node(id,f,p,**extra):
 xy=[p[0]*STEP+STEP/2,p[1]*STEP+STEP/2]
 if id not in nodes:nodes[id]={'id':id,'f':f,'pos':world(xy),'xy':xy,'grid':list(p),'edges':[],**extra}
 return id

def add_edge(a,b,kind='walk',verified=False):
 if a==b:return
 for x,y in [(a,b),(b,a)]:
  if not any(e['to']==y for e in nodes[x]['edges']):nodes[x]['edges'].append({'to':y,'type':kind,'verified':verified})

def append_path(f,path,free,role='corridor',first=None):
 pts=simplify_path(path,free);ids=[]
 for i,p in enumerate(pts):
  id=first if i==0 and first else node_id(f,p);ids.append(add_node(id,f,p,role=role))
 for a,b in zip(ids,ids[1:]):
  assert visible(nodes[a]['grid'],nodes[b]['grid'],free),(a,b)
  validation.append([a,b]);add_edge(a,b)
 return ids

for f in ['EG','OG']:
 page=fitz.open(ASSETS/f'GSO_{f}.pdf')[0];drawings=page.get_drawings();dx=0 if f=='EG'else 78.5
 walls=render_walls(drawings,dx);doors=doors_from_pdf(drawings,dx)
 # Explicit door openings are traversable; their symbols are not wall obstacles.
 painter=ImageDraw.Draw(walls)
 for d in doors:
  a,b=map(np.array,d['opening']);delta=b-a;length=np.linalg.norm(delta)
  if length<3:continue
  unit=delta/length;normal=np.array([-unit[1],unit[0]]);a=a+unit*1.0;b=b-unit*1.0;pad=7.5
  painter.polygon([tuple(a+normal*pad),tuple(b+normal*pad),tuple(b-normal*pad),tuple(a-normal*pad)],fill=255)
 raw=np.array(walls);blocked=(raw<190).reshape(744,2,1050,2).any(axis=(1,3));Y,X=np.indices(blocked.shape);xx=X*2+1;yy=Y*2+1
 floor_mask=((xx>=345)&(xx<=1358)&(((yy>=125)&(yy<=340))|((yy>=1125)&(yy<=1340))))|((xx>=380)&(xx<=640)&(yy>=340)&(yy<=1125))|((xx>=1358)&(xx<=1930)&(yy>=125)&(yy<=670))|((xx>=1358)&(xx<=1620)&(yy>=798)&(yy<=1340))
 if f=='OG':
  floor_mask&=~(((xx>=500)&(xx<=640)&(((yy>=474)&(yy<=690))|((yy>=943)&(yy<=991))))|((xx>=628)&(xx<=640)&(yy>=690)&(yy<=943)))
 free=floor_mask&~blocked
 # Main hall polygons restrict the backbone to public passageways.
 public=(((xx>=435)&(xx<=1358)&(yy>=208)&(yy<=263))|((xx>=435)&(xx<=1358)&(yy>=1208)&(yy<=1268))|((xx>=462)&(xx<=500)&(yy>=225)&(yy<=1240)))
 if f=='EG':public|=(xx>=388)&(xx<=530)&(yy>=475)&(yy<=990)
 public&=free
 # Link the four hallway junctions through wall-checked paths.
 waypoints=[[475,234],[1285,234],[475,407],[475,700],[475,1068],[475,1235],[1285,1235]]
 snapped=[snap(p,public,15)for p in waypoints];seeds=set()
 debug=Image.fromarray(np.where(free,255,0).astype('uint8')).convert('RGB');dd=ImageDraw.Draw(debug)
 for d in doors:
  x,y=np.array(d['xy'])/2;dd.ellipse((x-2,y-2,x+2,y+2),fill='red')
 debug.save(ROOT/f'indoor-{f.lower()}-door-inspect.png')
 print(f,'snap',snapped,'nearA',[(d['xy'],d['leafMatched'])for d in doors if 440<d['xy'][0]<510 and 440<d['xy'][1]<500],flush=True)
 for i,j in [(0,1),(0,2),(2,3),(3,4),(4,5),(5,6)]:
  path=astar(snapped[i],snapped[j],public)
  if not path:raise RuntimeError(f'{f}: no public corridor {i}-{j}')
  append_path(f,path,free);seeds.update(path)
 # One multi-source search connects each drawn door to the public backbone.
 parent=np.full(free.shape,-1,np.int32);queue=collections.deque()
 for x,y in seeds:parent[y,x]=y*1050+x;queue.append((x,y))
 while queue:
  x,y=queue.popleft()
  for nx,ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
   if 0<=nx<1050 and 0<=ny<744 and free[ny,nx]and parent[ny,nx]<0:parent[ny,nx]=y*1050+x;queue.append((nx,ny))
 def trace(p):
  if p is None or parent[p[1],p[0]]<0:return None
  path=[p]
  for _ in range(200000):
   x,y=p;value=int(parent[y,x]);q=(value%1050,value//1050)
   if q==p:return path
   path.append(q);p=q
  return None
 linked=[];unlinked=[]
 for i,d in enumerate(doors):
  p=snap(d['xy'],free,8);path=trace(p);id=f'dev-indoor-{f.lower()}-door-{i+1}';d.update({'id':id,'floor':f,'connected':bool(path),'pos':world(d['xy'])})
  if path:
   ids=append_path(f,path,free,'door-access',first=id);d['anchorPos']=nodes[id]['pos'];d['anchorXY']=nodes[id]['xy'];linked.append((id,p))
  else:
   unlinked.append(i+1)
   add_node(id,f,(int(d['xy'][0]//2),int(d['xy'][1]//2)),role='door-pending')
  all_doors.append(d)
 # Every branch ends on a seed pixel; attach that exact pixel to its corridor segment.
 backbone=[(a,b)for a,b in list(validation)if nodes[a]['f']==f and nodes[a].get('role')=='corridor'and nodes[b].get('role')=='corridor']
 endpoints=[id for id,n in list(nodes.items())if n['f']==f and tuple(n['grid'])in seeds and n.get('role')!='corridor']
 for id in endpoints:
  p=np.array(nodes[id]['grid']);best=None
  for a,b in backbone:
   u=np.array(nodes[a]['grid']);v=np.array(nodes[b]['grid']);delta=v-u;t=float(np.dot(p-u,delta)/max(delta@delta,1));proj=u+np.clip(t,0,1)*delta;dist=np.linalg.norm(p-proj)
   if best is None or dist<best[0]:best=(dist,a,b)
  if best:
   for target in best[1:]:
    if visible(nodes[id]['grid'],nodes[target]['grid'],free):add_edge(id,target);validation.append([id,target])
 # Room labels are assigned to the first reachable door in their own free-space component.
 owner=np.full(free.shape,-1,np.int32);dq=collections.deque()
 for i,(id,p)in enumerate(linked):owner[p[1],p[0]]=i;dq.append(p)
 while dq:
  x,y=dq.popleft()
  for nx,ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
   if 0<=nx<1050 and 0<=ny<744 and free[ny,nx]and owner[ny,nx]<0:owner[ny,nx]=owner[y,x];dq.append((nx,ny))
 attachments={};missing=[]
 for r in base['floors'][f]['rooms']:
  p=snap([r['x'],r['y']],free,35)
  if p and owner[p[1],p[0]]>=0:attachments[r['id']]=linked[int(owner[p[1],p[0]])][0]
  else:missing.append(r['code'])
 Image.fromarray((free*255).astype(np.uint8)).save(ROOT/f'indoor-{f.lower()}-free.png')
 floor_data[f]={'free':free,'parent':parent,'seeds':seeds,'trace':trace,'attachments':attachments,'snapped':snapped,'missing':missing,'unlinkedDoors':unlinked}
 print(f,'doors',len(doors),'connected',len(linked),'unlinked',unlinked,'rooms',len(attachments),'missing',missing,'nodes',sum(n['f']==f for n in nodes.values()),flush=True)
 # Store the wall-checked parent paths for later entrance/stair compilation.
 floor_data[f]['linked']=linked

# Main stair cores align in both floor plans. These are explicit cross-floor transitions.
cores=[]
for name,xy in [('a-nord',[522,407]),('a-sued',[522,1068]),('b-ost',[1285,283]),('c-ost',[1285,1187])]:
 pair=[]
 for f in ['EG','OG']:
  fd=floor_data[f];p=snap(xy,fd['free'],15)
  if p is None or fd['parent'][p[1],p[0]]<0:break
  path=[p]
  while True:
   v=int(fd['parent'][p[1],p[0]]);q=(v%1050,v//1050)
   if q==p:break
   path.append(q);p=q
  id=f'dev-indoor-{f.lower()}-stair-{name}';ids=append_path(f,path,fd['free'],'stair-access',first=id);pair.append(id)
 if len(pair)==2:add_edge(*pair,'stairs',True);cores.append({'name':name,'nodes':pair})
# Attach named stair destinations to their physical stair cores.
for f,fd in floor_data.items():
 for room in base['floors'][f]['rooms']:
  if room['category']=='stairs':
   options=[id for core in cores for id in core['nodes']if nodes[id]['f']==f]
   if options:fd['attachments'][room['id']]=min(options,key=lambda id:math.dist(nodes[id]['xy'],[room['x'],room['y']]))
# The labelled lift is linked only if both shaft landings are reachable through an actual opening.
lift_pair=[]
for f in ['EG','OG']:
 fd=floor_data[f];room=next((r for r in base['floors'][f]['rooms']if r['category']=='lift'),None)
 if not room:break
 p=snap([room['x'],room['y']],fd['free'],5)
 if p is None or fd['parent'][p[1],p[0]]<0:break
 path=[p]
 while True:
  value=int(fd['parent'][p[1],p[0]]);q=(value%1050,value//1050)
  if q==p:break
  path.append(q);p=q
 id=f'dev-indoor-{f.lower()}-lift';append_path(f,path,fd['free'],'lift-access',first=id);fd['attachments'][room['id']]=id;lift_pair.append(id)
if len(lift_pair)==2:add_edge(*lift_pair,'lift',True)

# A room/door path might end at a seed pixel created after backbone assembly; connect all seed aliases.
for f,fd in floor_data.items():
 seeds=fd['seeds'];anchors=[id for id,n in nodes.items()if n['f']==f and n.get('role')=='corridor']
 for id,n in list(nodes.items()):
  if n['f']!=f or tuple(n['grid'])not in seeds or n.get('role')=='corridor':continue
  nearest=sorted(anchors,key=lambda x:math.dist(nodes[x]['grid'],n['grid']))
  for target in nearest[:8]:
   if visible(n['grid'],nodes[target]['grid'],fd['free']):add_edge(id,target);validation.append([id,target]);break

# User-confirmed facade entrances keep their exact outdoor positions. Access paths start in the opening/landing.
entrances=[]
for p in current['customPlaces']:
 if p['category']!='entrance' or p['code']in ['Autoeinfahrt','Haupteingang']:continue
 xy=inv(current['points'][p['id']]);fd=floor_data['EG'];start=snap(xy,fd['free'],12)
 if start is None or fd['parent'][start[1],start[0]]<0:entrances.append({'place':p['id'],'code':p['code'],'connected':False});continue
 path=[start];q=start
 while True:
  value=int(fd['parent'][q[1],q[0]]);n=(value%1050,value//1050)
  if n==q:break
  path.append(n);q=n
 id='dev-indoor-eg-entry-'+p['id'].replace('dev-place-','');append_path('EG',path,fd['free'],'entry-access',first=id)
 # Connect the new terminal on the corridor to a visible backbone anchor.
 last=node_id('EG',path[-1]);anchors=[k for k,n in nodes.items()if n['f']=='EG'and n.get('role')=='corridor']
 for a in sorted(anchors,key=lambda k:math.dist(nodes[k]['grid'],path[-1]))[:8]:
  if visible(path[-1],nodes[a]['grid'],fd['free']):add_edge(last,a);validation.append([last,a]);break
 entrances.append({'place':p['id'],'outsideNode':current['pointNodes'][p['id']],'insideNode':id,'code':p['code'],'connected':True,'planDistance':round(math.dist(xy,nodes[id]['xy']),2)})

# Final independent segment check against the carved wall-only raster.
for a,b in validation:assert visible(nodes[a]['grid'],nodes[b]['grid'],floor_data[nodes[a]['f']]['free']),(a,b)
# Drop construction-only fields from the deployed graph, retain semantic labels in the catalogue.
nav_nodes=[{k:v for k,v in n.items()if k not in ['grid']}for n in nodes.values()]
result={'revision':1,'nodes':nav_nodes,'doors':all_doors,'rooms':{k:v for fd in floor_data.values()for k,v in fd['attachments'].items()},'entrances':entrances,'stairs':cores,'lift':lift_pair,'stats':{'doors':len(all_doors),'connectedDoors':sum(d['connected']for d in all_doors),'rooms':sum(len(fd['attachments'])for fd in floor_data.values()),'nodes':len(nav_nodes),'checkedSegments':len(validation),'entrances':sum(e['connected']for e in entrances)},'missingRooms':{f:[r['code']for r in base['floors'][f]['rooms']if r['id']not in fd['attachments']]for f,fd in floor_data.items()},'source':'GSO EG/OG PDF layers Wand, Wand Trockenbau, Stütze, Fenster and Türen; confirmed entrance positions from user JSON'}
(ASSETS/'indoor-navigation.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
print('TOTAL',result['stats'],'entrances',entrances,flush=True)

# Keep deployment inputs synchronized; indoor graph promotion remains explicit.
import base64
( ROOT/'dist/config/indoor-navigation.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
walk={'width':1050,'height':744,'step':2,'registration':base['registration'],'floors':{}}
for floor,fd in floor_data.items():
 walk['floors'][floor]=base64.b64encode(np.packbits(fd['free'].ravel(),bitorder='little').tobytes()).decode()
(ROOT/'dist/config/walkability.json').write_text(json.dumps(walk,separators=(',',':')))
