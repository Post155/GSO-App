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
result={'floors':{},'registration':{'matrix':M.tolist(),'offset':o.tolist()},'source':'GSO EG / OG, Nutzerpläne'}
for floor in ['EG','OG']:
 p=fitz.open(str(Path(__file__).resolve().parents[2]/'dist/assets'/('GSO_'+floor+'.pdf')))[0]
 dx=0 if floor=='EG' else 78.5
 # Text-free original drawing for segmentation; dimensions are outside the map footprint.
 doc=fitz.open();q=doc.new_page(width=p.rect.width,height=p.rect.height);shape=q.new_shape()
 for d in p.get_drawings():
  for it in d['items']:
   if it[0]=='l':shape.draw_line(it[1],it[2])
   elif it[0]=='c':shape.draw_bezier(*it[1:])
   elif it[0]=='re':shape.draw_rect(it[1])
   elif it[0]=='qu':shape.draw_quad(it[1])
  shape.finish(color=(0,0,0),fill=(0,0,0) if d['type'] in ('f','fs') else None,width=.36,closePath=d['closePath'])
 shape.commit()
 pix=q.get_pixmap(matrix=fitz.Matrix(S/2,S/2),colorspace=fitz.csGRAY)
 raw=np.frombuffer(pix.samples,dtype=np.uint8).reshape(pix.height,pix.width)
 canvas=np.ones((744,1050),dtype=np.uint8)*255
 shift=round(dx/2); hh=min(744,raw.shape[0]);ww=min(1050-shift,raw.shape[1]);canvas[:hh,shift:shift+ww]=raw[:hh,:ww]
 wall=canvas<190
 # Close tiny drafting gaps, not the building's doors.
 wall=ndi.binary_closing(wall,iterations=1)
 regions,n=ndi.label(~wall)
 slices=ndi.find_objects(regions);counts=np.bincount(regions.ravel())
 paths=[]; region_meta={}
 for k,sl in enumerate(slices,1):
  if sl is None or counts[k]<65 or counts[k]>65000:continue
  yy,xx=sl;cx=(xx.start+xx.stop);cy=(yy.start+yy.stop)
  inside=(345<cx<1358 and 125<cy<1340) or (1358<cx<1930 and 125<cy<670) or (1358<cx<1620 and 798<cy<1340)
  if not inside:continue
  loops=outline(regions[sl]==k,xx.start,yy.start)
  if not loops:continue
  path=' '.join('M'+' '.join(f'{x},{y}' for x,y in l)+'Z' for l in loops)
  paths.append({'id':k,'d':path,'area':int(counts[k])*4})
  region_meta[k]=(cx,cy)
 rooms=[];seen=set()
 # Split PDF blocks into lines so labels in adjacent rooms are kept separate.
 for block in p.get_text('dict')['blocks']:
  if 'lines' not in block:continue
  lines=[]
  for line in block['lines']:
   txt=''.join(s['text'] for s in line['spans']).strip();box=line['bbox'];lines.append((txt,box))
  for i,(txt,box) in enumerate(lines):
   matches=list(re.finditer(r'\b([ABCD])\s*(\d{3})(?:\s*/\s*(?:[ABCD]\s*)?(\d{3}))?',txt,re.I))
   for m in matches:
    code=m[1].upper()+' '+m[2]
    if code in seen:continue
    seen.add(code)
    x=(box[0]+box[2])/2*S+dx;y=(box[1]+box[3])/2*S
    desc=[]
    for t,b in lines[i+1:]:
     if re.search(r'\b[ABCD]\s*\d{3}',t):break
     if t not in ('LUFTRAUM',):desc.append(t)
    name=' '.join(desc).replace('VORBEREI- TUNGSR.','Vorbereitungsraum').replace('VORBEREI- TUNG','Vorbereitung').replace('LAAGER','Lager')
    if not name:name='Raum'
    cat='classroom'
    if 'WC' in name:cat='wc'
    elif 'TRH' in name:cat='stairs';name='Treppenhaus'
    elif 'AUFZUG' in name:cat='lift';name='Aufzug'
    elif 'FLUR' in name:cat='corridor';name='Flur'
    elif any(t in name for t in ['TECHNIK','LAGER','MATERIAL','VORBEREIT','REINIG']):cat='service'
    elif any(t in name for t in ['SEKRETARIAT','LEHRER','SCHULLEIT','BESPRECH']):cat='office'
    region=int(regions[min(743,round(y/2)),min(1049,round(x/2))])
    rooms.append({'id':floor+'-'+code.replace(' ',''),'code':code,'name':name.title() if name.isupper() else name,'floor':floor,'category':cat,'x':round(x,1),'y':round(y,1),'pos':world(x,y),'region':region if region in region_meta else None})
    if m[3]:
     alias=m[1].upper()+' '+m[3];seen.add(alias);rooms[-1]['code']=code+' / '+alias
 # Add labels without room numbers, including sports hall and foyer.
 for label,x,y,cat in [('Foyer',455,750,'corridor'),('Sporthalle',1650,410,'classroom')]:
  if floor=='OG' and label=='Foyer':continue
  rooms.append({'id':floor+'-'+label,'code':label,'name':label,'floor':floor,'category':cat,'x':x,'y':y,'pos':world(x,y),'region':None})
 # Export simplified original lines for thin architectural detail.
 svg=q.get_svg_image(text_as_path=False)
 inner=svg[svg.index('>')+1:svg.rfind('</svg>')]
 inner=re.sub(r'<defs>.*?</defs>','',inner,flags=re.S)
 # Keep drawing in original PDF coordinates; clip out peripheral dimension strings.
 clip=f'<clipPath id="clip{floor}"><path d="M345 125H1930V670H1358V798H1620V1340H345Z"/></clipPath>'
 walls=f'<g clip-path="url(#clip{floor})"><g transform="translate({dx} 0) scale({S})">{inner}</g></g>'
 (out/(floor.lower()+'-walls.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2100 1486">'+clip+walls+'</svg>')
 result['floors'][floor]={'rooms':rooms,'regions':paths}
 print(floor,len(rooms),'labels',len(paths),'regions')
 # Conservative occupancy map for validation of proposed corridor connections.
 Image.fromarray((~wall*255).astype('uint8')).save(out/(floor.lower()+'-free.png'))
(out/'map-data.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
