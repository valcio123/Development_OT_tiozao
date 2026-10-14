"""Correct traditional HMM: legacy fire missile + shock sprites 330/331."""
from pathlib import Path
import argparse,sys,json,zipfile,io,lzma
from PIL import Image

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project',type=Path,required=True)
parser.add_argument('--source',type=Path,required=True)
args=parser.parse_args()
root=args.project
sys.path.insert(0,str(root/'otclient/tools'))
from import_legacy_sd_effect import fields,identity,scalar,message,varint,digest,backup,legacy_sprite
assets=root/'otclient/data/things/1525'
catalog_path=assets/'catalog-content.json'
catalog=json.loads(catalog_path.read_bytes())
entry=next(e for e in catalog if e['type']=='appearances')
original=(assets/entry['file']).read_bytes()
effects={identity(v):v for n,w,v,r in fields(original) if n==3 and w==2}
effect_id=max(effects)+1
assert effect_id==357, 'Review current catalog before allocating the expected new ID'
first=max(e['lastspriteid'] for e in catalog if e['type']=='sprite')+1
with zipfile.ZipFile(args.source/'effects/effect_12.otobj') as z:
    manifest=json.loads(z.read('manifest.json'));group=manifest['frameGroups'][0]
    assert group['frames']==4 and all(group[k]==1 for k in ('width','height','layers','patternX','patternY','patternZ'))
    image=Image.open(io.BytesIO(z.read(group['sheet']))).convert('RGBA')
cols=image.width//32
frames=[image.crop(((i%cols)*32,(i//cols)*32,(i%cols+1)*32,(i//cols+1)*32)) for i in range(4)]
def key(image):
    return bytes(c for p in image.getdata() for c in (p if p[3] else (0,0,0,0)))
spr=(args.source/'Tibia.spr').read_bytes()
original_ids={key(legacy_sprite(spr,i)):i for i in (330,331)}
source_ids=[original_ids[key(frame)] for frame in frames]
sheet=Image.new('RGBA',(384,384),(255,0,255,0))
anim=scalar(1,0)+scalar(2,0)+scalar(3,0)+scalar(4,1)+scalar(5,1)
for i,frame in enumerate(frames):
    sheet.paste(frame,(i*32,0))
    anim+=message(6,scalar(1,100)+scalar(2,100))
info=scalar(1,1)+scalar(2,1)+scalar(3,1)+scalar(4,1)
info+=b''.join(scalar(5,first+i) for i in range(4))+message(6,anim)+scalar(7,32)+scalar(8,0)
template=effects[12]
old_group=next(v for n,w,v,r in fields(template) if n==2)
new_group=b''.join(r for n,w,v,r in fields(old_group) if n!=3)+message(3,info)
effect=scalar(1,effect_id)+b''.join(r for n,w,v,r in fields(template) if n not in (1,2))+message(2,new_group)
addition=message(3,effect)
result=original+addition
assert result[:len(original)]==original
bmp=io.BytesIO();sheet.save(bmp,format='BMP')
compressed=lzma.compress(bmp.getvalue(),format=lzma.FORMAT_ALONE)
length=varint(len(compressed))
cip=bytes(32-5-len(length))+bytes.fromhex('700afa8024')+length+compressed
assert lzma.decompress(cip[32:],format=lzma.FORMAT_ALONE)==bmp.getvalue()
appearance='appearances-'+digest(result)+'.dat'
spritefile='sprites-'+digest(cip)+'.bmp.lzma'
backup(catalog_path)
for name,data in ((appearance,result),(spritefile,cip)):
    path=assets/name;assert not path.exists() or path.read_bytes()==data;path.write_bytes(data)
entry['file']=appearance
catalog.append(dict(type='sprite',file=spritefile,spritetype=0,firstspriteid=first,lastspriteid=first+143,area=0))
catalog_path.write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
server_path=root/'canary/data/items/appearances.dat'
server=server_path.read_bytes()
assert effect_id not in {identity(v) for n,w,v,r in fields(server) if n==3 and w==2}
backup(server_path);server_path.write_bytes(server+addition)
assert server_path.read_bytes()[:len(server)]==server
ignore=assets.parent/'.gitignore';backup(ignore)
with ignore.open('a',encoding='utf-8') as f:f.write('\n# Corrected legacy HMM shock impact.\n!1525/'+appearance+'\n!1525/'+spritefile+'\n')
script=root/'canary/data/scripts/runes/heavy_magic_missile.lua'
s=script.read_text(encoding='utf-8')
assert 'traditional and 355' in s and 'traditional and 71' in s
backup(script)
s=s.replace('traditional and 355','traditional and 357').replace('traditional and 71','traditional and 70')
s=s.replace('energy damage, energy projectile and fiery explosion impact.','energy damage, legacy fire projectile and shock impact (sprites 330/331).')
script.write_text(s,encoding='utf-8')
test=root/'canary/tests/lua/traditional_ih_hmm_strikes_test.lua'
s=test.read_text(encoding='utf-8');assert '"runes/heavy_magic_missile",COMBAT_ENERGYDAMAGE,355,71' in s
backup(test);test.write_text(s.replace('"runes/heavy_magic_missile",COMBAT_ENERGYDAMAGE,355,71','"runes/heavy_magic_missile",COMBAT_ENERGYDAMAGE,357,70'),encoding='utf-8')
report=dict(effectId=357,projectileId=70,legacyEffectId=12,sourceSpriteIds=source_ids,newSpriteIds=[first,first+3],frames=4,durationMs=400,appearance=appearance,sheet=spritefile)
for rel in ('canary/docs/systems/traditional-combat.md','.agents/pipeline/OT_Tiozao_CONTINUIDADE.md'):
    p=root/rel;backup(p)
    with p.open('a',encoding='utf-8') as f:
        f.write('\n### HMM visual correction (2026-10-14)\nUser correction supersedes the previous HMM visual: traditional HMM now uses legacy fire projectile 70 (missile 4/760) and new shock effect 357 (effect 12/760). Original sprites 330/331, original four-frame sequence '+str(source_ids)+', 100 ms per phase, 400 ms total. New sprites '+str(first)+'-'+str(first+3)+'. Formula, energy damage and modern behavior unchanged. Client/server metadata synchronized; no commit. Restart Canary and OTClient to test.\n')
(root/'.tools/hmm-shock-import.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
