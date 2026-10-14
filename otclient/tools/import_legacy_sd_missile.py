
"""Import the 7.60 SD projectile as missile 69 without replacing existing missiles."""
import argparse, io, json, lzma, struct, zipfile
from pathlib import Path
from PIL import Image
from import_legacy_sd_effect import fields, identity, scalar, message, varint, digest, backup, legacy_sprite

def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    assets = Path(__file__).resolve().parents[1] / "data/things/1525"
    catalog_path = assets / "catalog-content.json"
    catalog = json.loads(catalog_path.read_bytes())
    entry = next(e for e in catalog if e["type"] == "appearances")
    original = (assets / entry["file"]).read_bytes()
    missiles = {identity(v): v for n,w,v,r in fields(original) if n == 4 and w == 2}
    assert 69 > max(missiles), "Missile 69 must be unused"
    first = max(e["lastspriteid"] for e in catalog if e["type"] == "sprite") + 1
    with zipfile.ZipFile(args.source / "missiles/missile_11.otobj") as archive:
        manifest = json.loads(archive.read("manifest.json"))
        group = manifest["frameGroups"][0]
        assert manifest["category"] == "missile" and manifest["source"]["id"] == 11
        assert (group["width"],group["height"],group["layers"],group["patternX"],group["patternY"],group["patternZ"],group["frames"]) == (1,1,1,3,3,1,1)
        source_sheet = Image.open(io.BytesIO(archive.read(group["sheet"]))).convert("RGBA")
        assert source_sheet.size == (96,96)
    tiles = [source_sheet.crop(((i%3)*32,(i//3)*32,(i%3+1)*32,(i//3+1)*32)) for i in range(9)]
    # Identify the source sprites against Tibia.spr; normalize invisible RGB.
    def visible_key(image):
        return bytes(c for p in image.getdata() for c in (p if p[3] else (0,0,0,0)))
    spr = (args.source / "Tibia.spr").read_bytes()
    wanted = {visible_key(tile) for tile in tiles}
    source_ids = {}
    for i in range(1,struct.unpack_from("<H",spr,4)[0]+1):
        key = visible_key(legacy_sprite(spr,i))
        if key in wanted:
            source_ids.setdefault(key,[]).append(i)
    assert all(visible_key(tile) in source_ids for tile in tiles)
    sheet = Image.new("RGBA",(384,384),(255,0,255,0))
    ids = b""
    for i,tile in enumerate(tiles):
        sheet.paste(tile,(i*32,0))
        ids += scalar(5,first+i)
    info = scalar(1,3)+scalar(2,3)+scalar(3,1)+scalar(4,1)+ids+scalar(7,32)+scalar(8,0)
    template = missiles[11]
    template_group = next(v for n,w,v,r in fields(template) if n == 2)
    new_group = b"".join(r for n,w,v,r in fields(template_group) if n != 3)+message(3,info)
    missile = scalar(1,69)+b"".join(r for n,w,v,r in fields(template) if n not in (1,2))+message(2,new_group)
    result = original+message(4,missile)
    assert b"".join(r for n,w,v,r in list(fields(result))[:-1]) == original
    bmp = io.BytesIO()
    sheet.save(bmp,format="BMP")
    compressed = lzma.compress(bmp.getvalue(),format=lzma.FORMAT_ALONE)
    size = varint(len(compressed))
    cip = bytes(32-5-len(size))+bytes.fromhex("700afa8024")+size+compressed
    assert lzma.decompress(cip[32:],format=lzma.FORMAT_ALONE) == bmp.getvalue()
    appearance = "appearances-"+digest(result)+".dat"
    spritefile = "sprites-"+digest(cip)+".bmp.lzma"
    report = dict(missileId=69,legacyMissileId=11,sourceSpriteIdsByDirection=[source_ids[visible_key(tile)] for tile in tiles],
                  newSpriteIds=[first,first+8],directionPatterns=[3,3],appearance=appearance,sheet=spritefile,
                  unchangedExistingMissiles=len(missiles))
    print(json.dumps(report,indent=2))
    if not args.apply:
        return
    backup(catalog_path)
    (assets/appearance).write_bytes(result)
    (assets/spritefile).write_bytes(cip)
    entry["file"] = appearance
    catalog.append(dict(type="sprite",file=spritefile,spritetype=0,firstspriteid=first,lastspriteid=first+143,area=0))
    catalog_path.write_text(json.dumps(catalog,indent=2)+"\n",encoding="utf-8")
    assert (assets/appearance).read_bytes() == result
    project = assets.parents[3]
    (project/".tools/sd-missile-import.json").write_text(json.dumps(report,indent=2)+"\n")
    ignore = assets.parent/".gitignore"
    backup(ignore)
    with ignore.open("a",encoding="utf-8") as f:
        f.write("\n# Legacy SD projectile and active appearance catalog.\n!1525/"+appearance+"\n!1525/"+spritefile+"\n")
if __name__ == "__main__":
    run()
