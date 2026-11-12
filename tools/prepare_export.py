#!/usr/bin/env python3
"""Validate exact source and prepare a guarded PCK using Godot's own PCKPacker.
Usage: python tools/prepare_export.py RAW.pck OUTPUT.pck [--project PATH]
Then run the printed Godot command. No native mask equality is inferred here.
"""
from pathlib import Path
import argparse, hashlib, json, re, struct, shlex

def sha(data): return hashlib.sha256(data).hexdigest()
def read_pack(path):
    b=path.read_bytes()
    if struct.unpack_from('<5I',b,0)!=(0x43504447,3,4,6,3): raise ValueError('Requires unencrypted Godot 4.6.3 PCK v3')
    base=struct.unpack_from('<Q',b,24)[0];i=struct.unpack_from('<Q',b,32)[0]
    count=struct.unpack_from('<I',b,i)[0];i+=4;entries={}
    for _ in range(count):
        length=struct.unpack_from('<I',b,i)[0];i+=4
        name=b[i:i+length].rstrip(b'\0').decode();i+=length
        offset,size=struct.unpack_from('<QQ',b,i);i+=16;md=b[i:i+16];i+=16
        flags=struct.unpack_from('<I',b,i)[0];i+=4;data=b[base+offset:base+offset+size]
        if flags or len(data)!=size or hashlib.md5(data).digest()!=md: raise ValueError('Unsupported/corrupt entry '+name)
        if name in entries or name.startswith('/') or '..' in Path(name).parts: raise ValueError('Unsafe/duplicate entry')
        entries[name]=data
    return entries

def import_remaps(data, name):
    # Only [remap] declares loader targets. Never infer them from [deps]/snapshots.
    text=data.rstrip(b'\0').decode('utf-8')
    if '\0' in text: raise ValueError('Interior NUL in remap '+name)
    section=None;seen_section=False;targets=[];keys=set();fields={}
    for raw_line in text.splitlines():
        line=raw_line.strip()
        if not line or line.startswith(';'): continue
        if line.startswith('['):
            if not re.fullmatch(r'\[[A-Za-z0-9_]+\]',line): raise ValueError('Malformed remap section '+name)
            section=line[1:-1]
            if section=='remap':
                if seen_section: raise ValueError('Duplicate remap section '+name)
                seen_section=True
            continue
        if section!='remap': continue
        if line.startswith('path'):
            match=re.fullmatch(r'(path(?:\.(?:s3tc|bptc|etc2|etc2_astc|astc|basis_universal))?)\s*=\s*"res://([^"\r\n]+)"',line)
            if not match or match[1] in keys: raise ValueError('Unsupported/duplicate path declaration '+name)
            keys.add(match[1]);targets.append((match[1],match[2]))
        elif line.startswith(('type=', 'importer=')):
            key,value=line.split('=',1)
            if key in fields: raise ValueError('Duplicate importer field '+name)
            fields[key]=value
    if not seen_section or not targets: raise ValueError('Missing remap target '+name)
    expected={'type':'"PackedScene"','importer':'"scene"'} if name.endswith('.glb') else {'type':'"CompressedTexture2D"','importer':'"texture"'}
    if any(fields.get(k)!=v for k,v in expected.items()): raise ValueError('Unexpected importer type '+name)
    if name.endswith('.glb') and (len(targets)!=1 or targets[0][0]!='path'): raise ValueError('Ambiguous scene remap '+name)
    return targets

def prepare(project, raw, output):
    project=project.resolve();raw=raw.resolve();output=output.resolve()
    if raw==output or output.exists(): raise ValueError('Use a NEW output PCK path')
    contract=json.loads((project/'tools/build-contract.json').read_text())
    manifest=json.loads((project/'SOURCE-MANIFEST.json').read_text())['files']
    # Import metadata/UIDs can be rewritten by a clean editor import. Runtime
    # source, raw art, config, shaders and JSON must still be the reviewed bytes.
    for name,expected in manifest.items():
        if name.endswith(('.import','.uid')): continue
        if sha((project/name).read_bytes())!=expected: raise ValueError('Source changed; new native authority review required: '+name)
    entries=read_pack(raw)
    for name in contract['required_json']:
        if name not in entries: raise ValueError('Missing required runtime JSON '+name)
        if entries[name]!=(project/name).read_bytes(): raise ValueError('Stale/mismatched exported runtime JSON '+name)
    authority=json.loads((project/'assets/planting_review/verified-native-foliage.json').read_text())
    guards={};mappings=[]
    for source,expected in authority['source_sha256'].items():
        name=source.removeprefix('res://')
        if sha((project/name).read_bytes())!=expected: raise ValueError('Raw source guard mismatch '+name)
        if name.endswith(('.gd','.gdshader')):
            if sha(entries[name])!=expected: raise ValueError('Exported script mismatch '+name)
            guards[source]=expected
        elif name.endswith(('.glb','.png')):
            imp=name+'.import';data=entries[imp]
            remaps=import_remaps(data,name)
            targets=[]
            for key,target in remaps:
                suffix='.scn' if name.endswith('.glb') else '.ctex'
                if not target.startswith('.godot/imported/') or not target.endswith(suffix) or target not in entries:
                    raise ValueError('Missing/unreviewed imported target '+target)
                guards['res://'+target]=sha(entries[target]);targets.append({'key':key,'path':target,'sha256':sha(entries[target])})
            guards['res://'+imp]=sha(data)
            mappings.append({'source':source,'raw_sha256':expected,'remap':imp,'targets':targets})
        elif name=='assets/park_west/binding.json':
            # Sole reviewed JSON guard extension; required JSON bytes were checked
            # against immutable source above. Never accept arbitrary JSON guards.
            if name not in contract['required_json'] or name not in manifest:
                raise ValueError('Missing reviewed west binding contract')
            if sha(entries[name])!=expected:
                raise ValueError('Exported west binding differs from source guard')
            guards[source]=expected
        else: raise ValueError('Unreviewed source guard type '+name)
    authority['source_sha256']=guards
    authority['note']='Fresh export authority: guarded raw source verified; actual remap and imported scene hashes bound. Native mask equivalence MUST pass before use/distribution.'
    work=output.parent/(output.stem+'-build');work.mkdir(parents=True,exist_ok=False)
    (work/'empty-project').mkdir()
    auth=work/'packed-native-authority.json';auth.write_text(json.dumps(authority,separators=(',',':')))
    script=work/'repack.gd'
    lines=['extends SceneTree','func _initialize():',f' assert(ProjectSettings.load_resource_pack({json.dumps(str(raw))},true))',' var pack=PCKPacker.new()',f' assert(pack.pck_start({json.dumps(str(output))})==OK)']
    for name in entries:
        src=str(auth) if name=='assets/planting_review/verified-native-foliage.json' else 'res://'+name
        lines.append(f' assert(pack.add_file({json.dumps(name)},{json.dumps(src)})==OK)')
    lines+=[' assert(pack.flush()==OK)',' print("REBUILT_PCK_READY_NATIVE_VERIFICATION_REQUIRED")',' quit()']
    script.write_text('\n'.join(lines)+'\n')
    (work/'mapping.json').write_text(json.dumps({'raw_pck_sha256':sha(raw.read_bytes()),'guards':guards,'mappings':mappings,'native_verified':False},indent=2))
    print('godot --headless --audio-driver Dummy --path '+shlex.quote(str(work/'empty-project'))+' --script '+shlex.quote(str(script)))
    return script,work
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('raw',type=Path);a.add_argument('output',type=Path);a.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1]);args=a.parse_args();prepare(args.project,args.raw,args.output)
