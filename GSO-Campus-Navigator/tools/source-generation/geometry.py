"""Reusable geometry; importing does not regenerate assets."""
import math
import numpy as np

def signed(a):
 return .5*sum(a[i][0]*a[(i+1)%len(a)][1]-a[(i+1)%len(a)][0]*a[i][1] for i in range(len(a)))

def rdp(p,eps):
 if len(p)<3:return p
 a=np.array(p,float);v=a[-1]-a[0];l=float(v@v);t=np.clip(((a-a[0])@v)/max(l,1e-9),0,1);dist=np.linalg.norm(a-(a[0]+t[:,None]*v),axis=1);i=int(np.argmax(dist))
 if dist[i]>eps:return rdp(p[:i+1],eps)[:-1]+rdp(p[i:],eps)
 return [p[0],p[-1]]

def simplify(loop,eps):
 p=[list(x) for x in loop]
 if len(p)<=4:return p
 start=max(range(len(p)),key=lambda i:(p[i][0],p[i][1]));p=p[start:]+p[:start]
 k=max(range(len(p)),key=lambda i:math.dist(p[i],p[0]));out=rdp(p[:k+1],eps)[:-1]+rdp(p[k:]+[p[0]],eps)[:-1]
 return out if len(out)>=3 else p

def proper_cross(a,b,c,d):
 def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
 return cross(a,b,c)*cross(a,b,d)<-1e-7 and cross(c,d,a)*cross(c,d,b)<-1e-7

def simple(p):
 if len(p)<3 or abs(signed(p))<2:return False
 for i,a in enumerate(p):
  b=p[(i+1)%len(p)]
  if math.dist(a,b)<.1:return False
  for j in range(i+2,len(p)):
   if i==0 and j==len(p)-1:continue
   if proper_cross(a,b,p[j],p[(j+1)%len(p)]):return False
 return True

def orthogonal(loop):
 p=np.array(loop,float);vec=np.roll(p,-1,axis=0)-p;lens=np.linalg.norm(vec,axis=1);angs=np.arctan2(vec[:,1],vec[:,0]);z=np.sum(lens**2*np.exp(4j*angs));theta=np.angle(z)/4
 confidence=float(np.sum(lens*(np.cos(4*(angs-theta))>.85))/max(lens.sum(),1))
 if confidence<.30:return loop,False
 center=p.mean(axis=0);c,s=math.cos(theta),math.sin(theta);R=np.array([[c,-s],[s,c]]);q=(p-center)@R
 # Collapse sub-pixel facade steps into shared wall coordinates.
 tol=min(6.0,max(2.5,float(np.ptp(q,axis=0).min())*.12))
 for axis in range(2):
  order=sorted(range(len(q)),key=lambda i:q[i,axis]);groups=[];g=[]
  for i in order:
   if g and q[i,axis]-q[g[0],axis]>tol:groups.append(g);g=[]
   g.append(i)
  if g:groups.append(g)
  for g in groups:
   weights=np.array([max(lens[i],lens[i-1],1) for i in g]);value=float(np.average(q[g,axis],weights=weights));q[g,axis]=value
 # Axis-aligned wall constraints intersect at true corners.
 walls=[]
 for i,a in enumerate(q):
  b=q[(i+1)%len(q)];dx,dy=b-a
  if math.hypot(dx,dy)<.5:continue
  kind='H' if abs(dx)>=abs(dy) else 'V';offset=float((a[1]+b[1])/2 if kind=='H' else(a[0]+b[0])/2);weight=math.hypot(dx,dy)
  if walls and walls[-1][0]==kind:
   prev=walls[-1];walls[-1]=(kind,(prev[1]*prev[2]+offset*weight)/(prev[2]+weight),prev[2]+weight)
  else:walls.append((kind,offset,weight))
 if len(walls)>1 and walls[0][0]==walls[-1][0]:
  a,b=walls[0],walls.pop();walls[0]=(a[0],(a[1]*a[2]+b[1]*b[2])/(a[2]+b[2]),a[2]+b[2])
 if len(walls)<4:return loop,False
 out=[]
 for i,wall in enumerate(walls):
  prev=walls[i-1]
  if prev[0]==wall[0]:return loop,False
  x=prev[1] if prev[0]=='V' else wall[1];y=prev[1] if prev[0]=='H' else wall[1];out.append([x,y])
 out=(np.array(out)@R.T+center).tolist();ratio=abs(signed(out))/max(abs(signed(loop)),1)
 if not(.68<ratio<1.32)or not simple(out):return loop,False
 # Avoid swapping the winding used for hole semantics.
 if signed(out)*signed(loop)<0:out.reverse()
 return out,True

def hash_loops(loops):
 text=';'.join('|'.join(','.join(str(int(round(v*1000)))for v in p)for p in loop)for loop in loops)
 h=2166136261
 for c in text:h=((h^ord(c))*16777619)&0xffffffff
 return str(h)
