"""Import original 7.60 Energy/Fire Wave tile effects into unused 15.25 IDs.

Nostalrius uses TELEPORT (760 appearance 11) and HITBYFIRE (appearance 16),
without a distance projectile. Preserve all existing client/server records.
"""
import argparse, io, json, lzma, struct, zipfile
from pathlib import Path
from PIL import Image, ImageDraw
from import_legacy_sd_effect import fields, identity, scalar, message, varint, digest, backup, legacy_sprite


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    assets = args.project / 'otclient/data/things/1525'
    catalog_path = assets / 'catalog-content.json'
    catalog = json.loads(catalog_path.read_bytes())
    entry = next(e for e in catalog if e['type'] == 'appearances')
    original = (assets / entry['file']).read_bytes()
    records = {identity(v): v for n,w,v,r in fields(original) if n == 3 and w == 2}
    assert max(records) < 358, 'Wave IDs already exist; verify existing import instead of allocating twice'
    first = max(e['lastspriteid'] for e in catalog if e['type'] == 'sprite') + 1
    spr = (args.source / 'Tibia.spr').read_bytes()
    def key(im):
        return bytes(c for p in im.getdata() for c in (p if p[3] else (0,0,0,0)))
    source_ids = {}
    for sid in range(1, struct.unpack_from('<H', spr, 4)[0]+1):
        source_ids.setdefault(key(legacy_sprite(spr,sid)),sid)
    sheet = Image.new('RGBA',(384,384),(255,0,255,0))
    preview = Image.new('RGBA',(640,180),(48,48,48,255))
    draw = ImageDraw.Draw(preview)
    additions, report, cursor = [], {}, first
    for row,(old_id,new_id) in enumerate(((11,358),(16,359))):
        with zipfile.ZipFile(args.source / f'effects/effect_{old_id}.otobj') as z:
            manifest = json.loads(z.read('manifest.json'))
            fg = manifest['frameGroups'][0]
            assert manifest['source']['id'] == old_id and manifest['category'] == 'effect'
            assert all(fg[k] == 1 for k in ('width','height','layers','patternX','patternY','patternZ'))
            image = Image.open(io.BytesIO(z.read(fg['sheet']))).convert('RGBA')
        ids, legacy = [], []
        cols = image.width // 32
        assert image.width * image.height == fg['frames'] * 1024
        draw.text((4,row*90+4),f'760 effect {old_id} -> {new_id}',fill='white')
        for i in range(fg['frames']):
            tile = image.crop(((i%cols)*32,(i//cols)*32,(i%cols+1)*32,(i//cols+1)*32))
            legacy.append(source_ids[key(tile)])
            offset = cursor-first
            sheet.paste(tile,((offset%12)*32,(offset//12)*32))
            ids.append(cursor); cursor += 1
            preview.alpha_composite(tile.resize((64,64),Image.Resampling.NEAREST),(i*72,row*90+20))
        anim = scalar(1,0)+scalar(2,0)+scalar(3,0)+scalar(4,1)+scalar(5,1)
        for _ in ids: anim += message(6,scalar(1,100)+scalar(2,100))
        info = scalar(1,1)+scalar(2,1)+scalar(3,1)+scalar(4,1)
        info += b''.join(scalar(5,sid) for sid in ids)+message(6,anim)+scalar(7,32)+scalar(8,0)
        template = records[old_id]
        group = next(v for n,w,v,r in fields(template) if n == 2)
        group = b''.join(r for n,w,v,r in fields(group) if n != 3)+message(3,info)
        obj = scalar(1,new_id)+b''.join(r for n,w,v,r in fields(template) if n not in (1,2))+message(2,group)
        additions.append(message(3,obj))
        report[str(new_id)] = dict(legacyEffect=old_id,sourceSpriteIds=legacy,spriteIds=ids,frames=len(ids),durationMs=len(ids)*100)
    updated = original+b''.join(additions)
    after = {identity(v):v for n,w,v,r in fields(updated) if n == 3 and w == 2}
    assert len(after) == len(records)+2 and all(after[k] == v for k,v in records.items())
    server_path = args.project/'canary/data/items/appearances.dat'
    server = server_path.read_bytes()
    server_ids = {identity(v) for n,w,v,r in fields(server) if n == 3 and w == 2}
    assert not ({358,359} & server_ids)
    server_updated = server+b''.join(additions)
    bmp = io.BytesIO(); sheet.save(bmp,format='BMP')
    compressed = lzma.compress(bmp.getvalue(),format=lzma.FORMAT_ALONE)
    size = varint(len(compressed))
    cip = bytes(32-5-len(size))+bytes.fromhex('700afa8024')+size+compressed
    assert lzma.decompress(cip[32:],format=lzma.FORMAT_ALONE) == bmp.getvalue()
    appearance = 'appearances-'+digest(updated)+'.dat'
    spritefile = 'sprites-'+digest(cip)+'.bmp.lzma'
    report.update(appearance=appearance,sheet=spritefile,existingRecordsUnchanged=True)
    print(json.dumps(report,indent=2))
    if not args.apply: return
    for name,data in ((appearance,updated),(spritefile,cip)):
        dest = assets/name
        assert not dest.exists() or dest.read_bytes() == data
        dest.write_bytes(data)
    backup(catalog_path); backup(server_path)
    entry['file'] = appearance
    catalog.append(dict(type='sprite',file=spritefile,spritetype=0,firstspriteid=first,lastspriteid=first+143,area=0))
    catalog_path.write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
    server_path.write_bytes(server_updated)
    assert server_path.read_bytes()[:len(server)] == server
    ignore = assets.parent/'.gitignore'
    backup(ignore)
    with ignore.open('a',encoding='utf-8') as f:
        f.write('\n# Original 760 Energy Wave and Fire Wave assets.\n!1525/'+appearance+'\n!1525/'+spritefile+'\n')
    preview.save(args.project/'.tools/legacy-waves-preview.png')
    (args.project/'.tools/legacy-waves-import.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    run()
