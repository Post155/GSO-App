from pathlib import Path
import numpy as np,json
from PIL import Image
from scipy import ndimage as ndi
from blueprint_geometry import out,outline
p=Path(__file__).resolve().parents[2]/'dist/assets/map-data.json';data=json.loads(p.read_text())
for floor in ['EG','OG']:
 a=np.array(Image.open(out/(floor.lower()+'-free.png')))==0
 # Clip drafting dimensions to the actual building footprint.
 yy,xx=np.indices(a.shape);X=xx*2;Y=yy*2
 footprint=((X>=345)&(X<=1358)&(((Y>=125)&(Y<=340))|((Y>=1125)&(Y<=1340))))|((X>=380)&(X<=640)&(Y>=340)&(Y<=1125))|((X>=1358)&(X<=1930)&(Y>=125)&(Y<=670))|((X>=1358)&(X<=1620)&(Y>=798)&(Y<=1340))
 # Transparent architectural line layer, avoiding tens of MB of CAD path data.
 rgba=np.zeros((*a.shape,4),dtype=np.uint8);rgba[:,:,:3]=[21,42,63];rgba[:,:,3]=np.where(a & footprint,190,0)
 Image.fromarray(rgba).save(out/(floor.lower()+'-walls.png'))
 w=ndi.binary_closing(a,iterations=3);regions,n=ndi.label(~w);counts=np.bincount(regions.ravel());paths=[];meta={}
 for k,sl in enumerate(ndi.find_objects(regions),1):
  if sl is None or counts[k]<65 or counts[k]>65000:continue
  yy,xx=sl;cx=xx.start+xx.stop;cy=yy.start+yy.stop
  regionmask=regions[sl]==k
  if np.count_nonzero(regionmask & ~footprint[sl])/counts[k]>.025:continue
  if not ((345<cx<1358 and 125<cy<1340) or (1358<cx<1930 and 125<cy<670) or (1358<cx<1620 and 798<cy<1340)):continue
  loops=outline(regions[sl]==k,xx.start,yy.start)
  if loops:paths.append({'id':k,'d':' '.join('M'+' '.join(f'{x},{y}' for x,y in l)+'Z' for l in loops),'area':int(counts[k])*4});meta[k]=1
 for room in data['floors'][floor]['rooms']:
  x=round(room['x']/2);y=round(room['y']/2);r=int(regions[y,x]);room['region']=r if r in meta else None
 data['floors'][floor]['regions']=paths
 print(floor,len(paths),'rooms assigned',sum(r['region'] is not None for r in data['floors'][floor]['rooms']))
p.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
