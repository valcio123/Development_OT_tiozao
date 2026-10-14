"""Import legacy 7.60 strike/HMM visuals using unused 15.25 IDs.

Preserves all existing appearance records and allocates sprites above the catalog.
Flam clones the existing custom GFB effect with 15 phases over 800 ms.
"""
import argparse, io, json, lzma, struct, sys, zipfile
from pathlib import Path
from PIL import Image, ImageDraw


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    sys.path.insert(0, str(args.project / 'otclient/tools'))
    from import_legacy_sd_effect import fields, identity, scalar, message, varint, digest, backup, legacy_sprite
    assets = args.project / 'otclient/data/things/1525'
    catalog_path = assets / 'catalog-content.json'
    catalog = json.loads(catalog_path.read_bytes())
    entry = next(e for e in catalog if e['type'] == 'appearances')
    original = (assets / entry['file']).read_bytes()
    records = {kind: {identity(v): v for n,w,v,r in fields(original) if n == kind and w == 2} for kind in (3,4)}
    effect_vis = max(records[3]) + 1
    effect_hmm, effect_flam = effect_vis + 1, effect_vis + 2
    missile_energy = max(records[4]) + 1
    first = max(e['lastspriteid'] for e in catalog if e['type'] == 'sprite') + 1
    sheet = Image.new('RGBA', (384,384), (255,0,255,0))
    cursor = first
    additions = []
    report = {'effects': {}, 'missiles': {}, 'existingRecordsUnchanged': True}
    preview = Image.new('RGBA', (800,280), (65,65,65,255))
    draw = ImageDraw.Draw(preview)
    spr = (args.source / 'Tibia.spr').read_bytes()

    def visible_key(image):
        return bytes(c for p in image.getdata() for c in (p if p[3] else (0,0,0,0)))

    # Match every imported tile to the actual legacy sprite database.
    source_ids = {}
    for sprite_id in range(1, struct.unpack_from('<H',spr,4)[0]+1):
        source_ids.setdefault(visible_key(legacy_sprite(spr,sprite_id)), sprite_id)

    def import_object(category, legacy_id, new_id, row):
        nonlocal cursor
        kind = 3 if category == 'effect' else 4
        source = args.source / (category + 's') / f'{category}_{legacy_id}.otobj'
        with zipfile.ZipFile(source) as archive:
            manifest = json.loads(archive.read('manifest.json'))
            fg = manifest['frameGroups'][0]
            assert manifest['category'] == category and manifest['source']['id'] == legacy_id
            assert fg['width'] == fg['height'] == fg['layers'] == fg['patternZ'] == 1
            if kind == 3:
                assert fg['patternX'] == fg['patternY'] == 1
            else:
                assert fg['patternX'] == fg['patternY'] == 3 and fg['frames'] == 1
            image = Image.open(io.BytesIO(archive.read(fg['sheet']))).convert('RGBA')
        count = fg['patternX'] * fg['patternY'] * fg['frames']
        assert image.width * image.height == count * 32 * 32
        cols = image.width // 32
        tiles = [image.crop(((i%cols)*32,(i//cols)*32,(i%cols+1)*32,(i//cols+1)*32)) for i in range(count)]
        ids = []
        source_sprite_ids = []
        draw.text((0,row*90), f'{category} {legacy_id} -> {new_id}', fill='white')
        for i,tile in enumerate(tiles):
            key = visible_key(tile)
            assert key in source_ids, f'{source} frame {i} not found in Tibia.spr'
            source_sprite_ids.append(source_ids[key])
            offset = cursor - first
            assert offset < 144
            sheet.paste(tile, ((offset%12)*32,(offset//12)*32))
            preview.alpha_composite(tile.resize((64,64),Image.Resampling.NEAREST),(170+i*64,row*90))
            ids.append(cursor)
            cursor += 1
        info = scalar(1,fg['patternX']) + scalar(2,fg['patternY']) + scalar(3,1) + scalar(4,1)
        info += b''.join(scalar(5,i) for i in ids)
        if kind == 3:
            anim = scalar(1,0) + scalar(2,0) + scalar(3,0) + scalar(4,1) + scalar(5,1)
            for i in range(fg['frames']):
                anim += message(6,scalar(1,100)+scalar(2,100))
            info += message(6,anim)
        info += scalar(7,32) + scalar(8,0)
        template = records[kind][legacy_id]
        group = next(v for n,w,v,r in fields(template) if n == 2)
        new_group = b''.join(r for n,w,v,r in fields(group) if n != 3) + message(3,info)
        obj = scalar(1,new_id) + b''.join(r for n,w,v,r in fields(template) if n not in (1,2)) + message(2,new_group)
        additions.append(message(kind,obj))
        report['effects' if kind == 3 else 'missiles'][str(new_id)] = {
            'legacyId':legacy_id, 'sourceSpriteIds':source_sprite_ids,
            'spriteIds':ids, 'frames':fg['frames'],
            'durationMs':fg['frames']*100 if kind == 3 else None,
        }

    import_object('effect',11,effect_vis,0)
    import_object('effect',6,effect_hmm,1)
    import_object('missile',5,missile_energy,2)

    # Clone the custom GFB: 15 evenly selected phases, preserving start/end.
    gfb = records[3][350]
    group = next(v for n,w,v,r in fields(gfb) if n == 2)
    info = next(v for n,w,v,r in fields(group) if n == 3)
    sprite_ids = [v for n,w,v,r in fields(info) if n == 5]
    assert len(sprite_ids) >= 15
    selected = [round(i*(len(sprite_ids)-1)/14) for i in range(15)]
    assert len(set(selected)) == 15 and selected[0] == 0 and selected[-1] == len(sprite_ids)-1
    anim = scalar(1,0)+scalar(2,0)+scalar(3,0)+scalar(4,1)+scalar(5,1)
    durations = [((i+1)*800//15)-(i*800//15) for i in range(15)]
    for ms in durations:
        anim += message(6,scalar(1,ms)+scalar(2,ms))
    new_info = b''.join(r for n,w,v,r in fields(info) if n not in (5,6))
    new_info += b''.join(scalar(5,sprite_ids[i]) for i in selected) + message(6,anim)
    new_group = b''.join(r for n,w,v,r in fields(group) if n != 3) + message(3,new_info)
    flam = scalar(1,effect_flam) + b''.join(r for n,w,v,r in fields(gfb) if n not in (1,2)) + message(2,new_group)
    additions.append(message(3,flam))
    report['effects'][str(effect_flam)] = {'sourceEffect':350,'frames':15,'durationMs':sum(durations),'sourcePhases':selected,'spriteIds':[sprite_ids[i] for i in selected]}
    result = original + b''.join(additions)
    assert result[:len(original)] == original
    for kind in (3,4):
        updated = {identity(v):v for n,w,v,r in fields(result) if n == kind and w == 2}
        assert all(updated[k] == v for k,v in records[kind].items())
        assert len(updated) == len(records[kind]) + (3 if kind == 3 else 1)
    bmp = io.BytesIO()
    sheet.save(bmp,format='BMP')
    compressed = lzma.compress(bmp.getvalue(),format=lzma.FORMAT_ALONE)
    size = varint(len(compressed))
    cip = bytes(32-5-len(size)) + bytes.fromhex('700afa8024') + size + compressed
    assert lzma.decompress(cip[32:],format=lzma.FORMAT_ALONE) == bmp.getvalue()
    appearance = 'appearances-'+digest(result)+'.dat'
    spritefile = 'sprites-'+digest(cip)+'.bmp.lzma'
    report.update(appearance=appearance,sheet=spritefile,firstSpriteId=first,lastUsedSpriteId=cursor-1)
    # Server safety checks must recognize the new IDs too. Append only metadata;
    # never replace the server's existing item/outfit definitions with client data.
    server_path = args.project / 'canary/data/items/appearances.dat'
    server_original = server_path.read_bytes()
    server_additions = []
    registered = {kind:{identity(v):v for n,w,v,r in fields(server_original) if n == kind and w == 2} for kind in (3,4)}
    for kind,required in ((3,[352,effect_vis,effect_hmm,effect_flam]),(4,[69,70,missile_energy])):
        available = {identity(v):v for n,w,v,r in fields(result) if n == kind and w == 2}
        for object_id in required:
            if object_id not in registered[kind]:
                server_additions.append(message(kind,available[object_id]))
            else:
                assert registered[kind][object_id] == available[object_id], 'Server/client ID collision'
    server_result = server_original + b''.join(server_additions)
    report['serverMetadataRecordsAdded'] = len(server_additions)
    print(json.dumps(report,indent=2))
    tools = args.project / '.tools'
    preview.save(tools / 'legacy-strikes-preview.png')
    if not args.apply:
        return
    backup(catalog_path)
    for name,data in ((appearance,result),(spritefile,cip)):
        target = assets / name
        assert not target.exists() or target.read_bytes() == data
        target.write_bytes(data)
        assert target.read_bytes() == data
    entry['file'] = appearance
    catalog.append(dict(type='sprite',file=spritefile,spritetype=0,firstspriteid=first,lastspriteid=first+143,area=0))
    catalog_path.write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
    if server_result != server_original:
        backup(server_path)
        server_path.write_bytes(server_result)
        assert server_path.read_bytes()[:len(server_original)] == server_original
    ignore = assets.parent / '.gitignore'
    backup(ignore)
    with ignore.open('a',encoding='utf-8') as f:
        f.write('\n# Traditional HMM and strike assets.\n!1525/'+appearance+'\n!1525/'+spritefile+'\n')
    (tools / 'legacy-strikes-import.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    run()
