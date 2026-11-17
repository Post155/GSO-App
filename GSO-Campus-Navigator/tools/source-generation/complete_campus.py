from pathlib import Path
import json,re,math
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as nd
root=Path(__file__).resolve().parents[2]
im=np.array(Image.open(root/'dist/assets/Referenz-Karte.png').convert('RGB'))
h,w=im.shape[:2]
mapdata=json.loads((root/'dist/assets/map-data.json').read_text());m=np.array(mapdata['registration']['matrix']);off=np.array(mapdata['registration']['offset'])
src=np.array([[793,464],[830,483],[810,520],[773,500]],float)
dst=np.array([m@p+off for p in [[1930,125],[1930,670],[1358,670],[1358,125]]])
coef=np.array([[2.48,0],[0,2.48],[-1750,-840]],float)
def world(p):return [round(float(x),2) for x in np.r_[p,1]@coef]
# Remove map UI and tiny label details before colour classification.
a=nd.median_filter(im,size=(3,3,1)).astype(float)
colors=np.array([[55,77,100],[0,88,88],[0,95,91],[75,100,130],[64,103,128],[82,96,116],[79,90,109],[77,78,64],[38,93,86],[21,84,101]],float)
dist=np.sum((a[:,:,None,:]-colors[None,None,:,:])**2,axis=3)
labels=np.argmin(dist,axis=2)
valid=np.min(dist,axis=2)<12**2
nearest=nd.distance_transform_edt(~valid,return_distances=False,return_indices=True)
labels=labels[tuple(nearest)]
# School geometry is supplied by the PDFs; do not duplicate the screenshot footprint.
school=Image.new('1',(w,h));draw=ImageDraw.Draw(school);draw.polygon([(790,457),(837,481),(817,516),(870,525),(850,565),(822,628),(728,586),(769,508)],fill=1)
sm=np.array(school,dtype=bool);labels[sm & np.isin(labels,[3,4])]=2
# Remove UI buttons and attribution without fabricating neighbouring geometry.
labels[:155,1630:]=0;labels[815:,1625:]=0;labels[845:,:65]=0;labels[875:,1300:]=0

def rdp(points,eps):
 if len(points)<3:return points
 p=np.array(points,float);v=p[-1]-p[0];den=np.dot(v,v)
 ds=np.sum((p-p[0])**2,axis=1) if den==0 else np.sum((p-(p[0]+np.clip(((p-p[0])@v)/den,0,1)[:,None]*v))**2,axis=1)
 i=int(np.argmax(ds))
 if ds[i]>eps*eps:return rdp(points[:i+1],eps)[:-1]+rdp(points[i:],eps)
 return [points[0],points[-1]]
def loops_of(mask,x0,y0):
 a=np.pad(mask,1);edges={}
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[:-2,1:-1])):edges[(x,y)]=(x+1,y)
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[1:-1,2:])):edges[(x+1,y)]=(x+1,y+1)
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[2:,1:-1])):edges[(x+1,y+1)]=(x,y+1)
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[1:-1,:-2])):edges[(x,y+1)]=(x,y)
 loops=[]
 while edges:
  start=next(iter(edges));p=start;pts=[]
  while p in edges:
   pts.append(p);p=edges.pop(p)
   if p==start:break
  if len(pts)<12:continue
  # Split the closed ring at its farthest vertex before line simplification.
  k=max(range(len(pts)),key=lambda i:(pts[i][0]-pts[0][0])**2+(pts[i][1]-pts[0][1])**2)
  ring=rdp(pts[:k+1],1.25)[:-1]+rdp(pts[k:]+[pts[0]],1.25)[:-1]
  if len(ring)>=3:loops.append([world([x+x0,y+y0]) for x,y in ring])
 return loops
Image.fromarray(np.where(labels==5,255,0).astype('uint8')).save(root/'context-roads-mask.png')
areas=[];specs=[(1,'#005858','green','Grünfläche'),(2,'#005f5b','green','Park / Grünfläche'),(8,'#265d56','green','Grünanlage'),(9,'#155465','green','Freifläche'),(7,'#4d4e40','paving','Sport / Freifläche'),(6,'#4f5a6d','parking','Hof / Parkplatz'),(3,'#4b6482','building','Gebäude'),(4,'#406780','building','Gebäude')]
for cl,color,kind,name in specs:
 mask=labels==cl
 # Fill label-sized holes, retaining buildings and actual courtyards.
 if cl in [1,2,5,6,8]:
  holes=nd.binary_fill_holes(mask)&~mask;rr,n=nd.label(holes);sizes=np.bincount(rr.ravel());mask|=holes&(sizes[rr]<70)
 pieces=[]
 if cl==5:
  for y in range(0,h,200):
   for x in range(0,w,200):pieces.append((x,y,mask[y:y+200,x:x+200]))
 else:pieces=[(0,0,mask)]
 count=0
 for ox,oy,part in pieces:
  regions,n=nd.label(part);sizes=np.bincount(regions.ravel())
  for k,sl in enumerate(nd.find_objects(regions),1):
   if sl is None or sizes[k]<(28 if cl in [3,4] else 180 if cl==7 else 45):continue
   yy,xx=sl;loops=loops_of(regions[sl]==k,xx.start+ox,yy.start+oy)
   if not loops:continue
   count+=1;title=name+' '+str(count)
   cx=ox+(xx.start+xx.stop)/2;cy=oy+(yy.start+yy.stop)/2
   if cl==6 and 840<cx<925 and 520<cy<656:title='Autoparkplatz GSO'
   areas.append({'id':f'dev-context-{cl}-{count}','name':title,'f':'Gelände','kind':kind,'loops':loops,'color':color,'opacity':1,'blocked':False,'builtin':False,'completionLayer':'background','completionSource':'Neue Region – Karte','role':'road' if cl==5 else 'context'})
 print(cl,count)
# Street labels are read from the supplied image, rather than inferred from older sketches.
texts=[('AM GRAUEN STEIN',700,493,-59),('WESTERWALDSTRASSE',751,336,29),('SINGHOFENER STRASSE',988,620,15),('ROLSHOVER STRASSE',1077,681,-89),('ÖSTLICHE ZUBRINGERSTRASSE',1391,859,-8),('ÖSTLICHE ZUBRINGERSTRASSE',342,452,32),('DEUTZER RING',214,234,-25),('GREMBERGERSTRASSE',625,151,28),('ODENWALDSTRASSE',1045,232,12),('RHÖNER WEG',532,253,31),('LÜDDERICHSTRASSE',1244,379,-4),('HUMBOLDTPARK',652,73,0),('FRIEDHOF DEUTZ',351,792,0)]
texts=[{'name':t,'pos':world([x,y]),'angle':ang,'kind':'park' if 'PARK'in t or 'FRIEDHOF'in t else 'road'} for t,x,y,ang in texts]
result={'areas':areas,'labels':texts,'imageToWorld':coef.tolist(),'bounds':[world([0,0]),world([w,h])],'source':'Neue Region – Karte (Referenz-Karte.png) only; user-authored coordinates retained'}
(root/'dist/assets/completion-context.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
print('areas',len(areas),'vertices',sum(len(l) for a in areas for l in a['loops']),'matrix',coef.tolist())
from html import escape
xs=[p[0] for a in areas for l in a['loops'] for p in l];ys=[p[1] for a in areas for l in a['loops'] for p in l]
box=[min(xs)-10,min(ys)-10,max(xs)-min(xs)+20,max(ys)-min(ys)+20]
body='<rect x="-10000" y="-10000" width="20000" height="20000" fill="#374d64"/>'
for a in areas:
 d=' '.join('M'+'L'.join(f'{x},{y}' for x,y in l)+'Z' for l in a['loops']);body+=f'<path d="{d}" fill="{a["color"]}" fill-rule="evenodd"/>'
(root/'dist/assets/completion-context.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="'+' '.join(map(str,box))+'">'+body+'</svg>')
result['viewBox']=box
(root/'dist/assets/completion-context.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
