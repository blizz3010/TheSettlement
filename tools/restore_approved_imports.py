"""Restore pinned approved runtime resources after Godot import. Never weakens guards."""
from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[1]
pin=root/'vendor/approved-runtime-imports'
records=json.loads((pin/'manifest.json').read_text())
for item in records:
 p=pin/item['path']
 assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],str(p)
for item in records:
 p=pin/item['path'];dest=root/'.godot/imported'/item['path']
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
print('Restored',len(records),'hash-verified approved import resources')

pin=root/'vendor/approved-import-metadata'
records=json.loads((pin/'manifest.json').read_text())
for item in records:
 p=pin/item['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256']
for item in records:
 p=pin/item['path'];dest=root/item['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
print('Restored',len(records),'approved import descriptors')

large=json.loads((root/'vendor/large-assets/manifest.json').read_text())
for record in large:
 blocks=[]
 for item in record['parts']:
  b=(root/item['path']).read_bytes();assert hashlib.sha256(b).hexdigest()==item['sha256'];blocks.append(b)
 b=b''.join(blocks);assert hashlib.sha256(b).hexdigest()==record['sha256']
 dest=root/record['destination'];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
print('Reassembled',len(large),'hash-verified large assets')
