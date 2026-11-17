"""Shared PDF coordinate registration and polygon extraction."""
import fitz,numpy as np,json,re,html,math
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
from pathlib import Path
out=Path(__file__).resolve().parents[2]/'dist/assets'
S=2100/1190.52001953125
# Registration from the building's western corners and B-wing end.
M=np.array([[109/880,240/1215],[-190/880,130/1215]])
o=np.array([42,600])-M@np.array([345,125])
def world(x,y):return [round(float(v),2) for v in M@np.array([x,y])+o]
def outline(mask,xo,yo):
 # Trace pixel edges of enclosed regions, retaining exact concave geometry.
 ed={}; a=np.pad(mask,1)
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[:-2,1:-1])):ed[(x,y)]=(x+1,y)
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[1:-1,2:])):ed[(x+1,y)]=(x+1,y+1)
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[2:,1:-1])):ed[(x+1,y+1)]=(x,y+1)
 for y,x in zip(*np.where(a[1:-1,1:-1]&~a[1:-1,:-2])):ed[(x,y+1)]=(x,y)
 loops=[]
 while ed:
  start=next(iter(ed));p=start;pts=[]
  while p in ed:
   pts.append(p);p=ed.pop(p)
   if p==start:break
  if len(pts)>10:
   keep=[pts[i] for i in range(len(pts)) if (pts[i][0]-pts[i-1][0],pts[i][1]-pts[i-1][1])!=(pts[(i+1)%len(pts)][0]-pts[i][0],pts[(i+1)%len(pts)][1]-pts[i][1])]
   if len(keep)>2:loops.append([world((x+xo)*2,(y+yo)*2) for x,y in keep])
 return loops
