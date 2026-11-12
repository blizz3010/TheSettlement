from pathlib import Path
import argparse
cli=argparse.ArgumentParser(description="Replay audited Atlas sleeve patch; default verifies without writes")
cli.add_argument("--output",type=Path,help="New GLB path; refuses existing files")
args=cli.parse_args()
import struct,json,hashlib,math
r=Path(__file__).resolve().parent;src=r.parent/'structural-fit/models/Atlas-Boot-Fix-Native-Verified.glb';b=bytearray(src.read_bytes());jn=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+jn]);start=20+jn+8;d=json.loads((r/'static-deltas.json').read_text());assert hashlib.sha256(b).hexdigest() == 'e7053373088b18a20cb415803dc2ef68e6556239c7110a71117fb68acdbfba76', 'Wrong baseline';assert d['source_sha256']==hashlib.sha256(b).hexdigest();mapping={tuple(round(v,5) for v in x['old_blender']):x['new_blender'] for x in d['rows']};allowed=set();matched=0
sizes={5126:4,5125:4,5123:2,5121:1};formats={5126:'f',5125:'I',5123:'H',5121:'B'}
def accessor(ai):
 a=j['accessors'][ai];v=j['bufferViews'][a['bufferView']];n={'VEC3':3,'SCALAR':1}[a['type']];fmt='<'+formats[a['componentType']]*n;stride=v.get('byteStride',sizes[a['componentType']]*n);off=start+v.get('byteOffset',0)+a.get('byteOffset',0);return [struct.unpack_from(fmt,b,off+i*stride) for i in range(a['count'])],off,stride,fmt
for mesh in j['meshes']:
 if mesh.get('name')!='male_worksuit01':continue
 for prim in mesh['primitives']:
  ps,off,stride,fmt=accessor(prim['attributes']['POSITION']);changed=set()
  for i,(x,y,z) in enumerate(ps):
   key=tuple(round(v,5) for v in (x/1.08,-z/1.08,y/1.08))
   if key not in mapping:
    co=(x/1.08,-z/1.08,y/1.08);matches=[r for r in d['rows'] if sum((co[k]-r['old_blender'][k])**2 for k in range(3))<4e-12]
    if not matches:continue
    q=matches[0]['new_blender']
   else:q=mapping[key]
   new=(q[0]*1.08,q[2]*1.08,-q[1]*1.08);struct.pack_into(fmt,b,off+i*stride,*new);allowed.update(range(off+i*stride,off+i*stride+12));ps[i]=new;changed.add(i);matched+=1
  if not changed:continue
  indices,_,_,_=accessor(prim['indices']);ids=[v[0] for v in indices];tris=[ids[i:i+3] for i in range(0,len(ids),3)];affected=set(v for t in tris if any(i in changed for i in t) for v in t);acc={i:[0,0,0] for i in affected}
  for t in tris:
   a,c,e=[ps[i] for i in t];u=[c[k]-a[k] for k in range(3)];v=[e[k]-a[k] for k in range(3)];n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
   for i in t:
    if i in acc:acc[i]=[acc[i][k]+n[k] for k in range(3)]
  ns,no,st,nfmt=accessor(prim['attributes']['NORMAL'])
  for i,n in acc.items():
   mag=math.sqrt(sum(x*x for x in n))
   if mag<1e-12:continue
   struct.pack_into(nfmt,b,no+i*st,*[x/mag for x in n]);allowed.update(range(no+i*st,no+i*st+12))
assert matched==101
original=src.read_bytes();actualdiff={i for i,(x,y) in enumerate(zip(original,b)) if x!=y};assert actualdiff<=allowed
digest=hashlib.sha256(b).hexdigest()
assert digest=='4d73a8688b5840dacafaa6fbb188c57c21960d6cff3c63641a182ff86a93bbe4', 'Replay differs from native-tested candidate'
assert len(actualdiff)==2435
if args.output:
 with args.output.open('xb') as f:f.write(b)
print(json.dumps({'verified':True,'output_sha256':digest,'matched_positions':matched,'edited_bytes':len(actualdiff),'mode':'new file' if args.output else 'read-only verification','output':str(args.output) if args.output else None},indent=2))
