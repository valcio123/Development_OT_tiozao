
"""Import the legacy 7.60 SD impact into new 15.25 effect/sprite IDs.
Requires Pillow. Original appearance entries and sprites are never replaced.
"""
import argparse, datetime, hashlib, io, json, lzma, shutil, struct, zipfile
from pathlib import Path
from PIL import Image

def varint(n):
    b = bytearray()
    while n > 127:
        b.append((n & 127) | 128)
        n >>= 7
    b.append(n)
    return bytes(b)

def readvar(data, pos):
    n = shift = 0
    while True:
        b = data[pos]
        pos += 1
        n |= (b & 127) << shift
        if b < 128:
            return n, pos
        shift += 7
        if shift > 63:
            raise ValueError("Invalid protobuf varint")

def fields(data):
    pos = 0
    while pos < len(data):
        start = pos
        key, pos = readvar(data, pos)
        wire = key & 7
        if wire == 0:
            value, pos = readvar(data, pos)
        elif wire == 2:
            length, pos = readvar(data, pos)
            value = data[pos:pos + length]
            pos += length
        elif wire in (1, 5):
            length = 8 if wire == 1 else 4
            value = data[pos:pos + length]
            pos += length
        else:
            raise ValueError("Unsupported protobuf wire type")
        assert pos <= len(data)
        yield key >> 3, wire, value, data[start:pos]

def scalar(n, value):
    return varint(n << 3) + varint(value)

def message(n, value):
    return varint((n << 3) | 2) + varint(len(value)) + value

def identity(data):
    return next(v for n, w, v, r in fields(data) if n == 1 and w == 0)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def backup(path):
    suffix = ".old." + datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    dest = path.with_name(path.name + suffix)
    shutil.copy2(path, dest)
    assert dest.read_bytes() == path.read_bytes()
    return dest

def legacy_sprite(data, sprite_id):
    count = struct.unpack_from("<H", data, 4)[0]
    assert 1 <= sprite_id <= count
    offset = struct.unpack_from("<I", data, 6 + 4 * (sprite_id - 1))[0]
    pixels = bytearray(32 * 32 * 4)
    if offset:
        size = struct.unpack_from("<H", data, offset + 3)[0]
        cursor, end, pixel = offset + 5, offset + 5 + size, 0
        while cursor < end:
            transparent, colored = struct.unpack_from("<HH", data, cursor)
            cursor += 4
            pixel += transparent
            assert pixel + colored <= 1024
            for _ in range(colored):
                pixels[pixel * 4:pixel * 4 + 4] = data[cursor:cursor + 3] + bytes([255])
                cursor += 3
                pixel += 1
        assert cursor == end
    return Image.frombytes("RGBA", (32, 32), bytes(pixels))

def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--assets", type=Path, default=Path(__file__).resolve().parents[1] / "data/things/1525")
    parser.add_argument("--effect-id", type=int, default=352)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    catalog_path = args.assets / "catalog-content.json"
    catalog = json.loads(catalog_path.read_bytes())
    appearance_entry = next(e for e in catalog if e["type"] == "appearances")
    original = (args.assets / appearance_entry["file"]).read_bytes()
    existing = {identity(v): v for n, w, v, raw in fields(original) if n == 3 and w == 2}
    assert args.effect_id > max(existing), "The new effect ID must be unused and above existing IDs"
    first = max(e["lastspriteid"] for e in catalog if e["type"] == "sprite") + 1
    spr = (args.source / "Tibia.spr").read_bytes()
    frames = [legacy_sprite(spr, i) for i in range(3244, 3252)]
    with zipfile.ZipFile(args.source / "effects/effect_18.otobj") as archive:
        manifest = json.loads(archive.read("manifest.json"))
        fg = manifest["frameGroups"][0]
        assert manifest["source"]["id"] == 18 and fg["frames"] == 8
        old_sheet = Image.open(io.BytesIO(archive.read(fg["sheet"]))).convert("RGBA")
        for i, frame in enumerate(frames):
            columns = old_sheet.width // 32
            exported = old_sheet.crop(((i % columns) * 32, (i // columns) * 32,
                                       (i % columns + 1) * 32, (i // columns + 1) * 32))
            # Compare visible pixels; exporters may keep RGB under transparent pixels.
            assert frame.convert("RGB").tobytes() == exported.convert("RGB").tobytes() or all(
                a[3] == b[3] and (a[3] == 0 or a == b)
                for a, b in zip(frame.getdata(), exported.getdata())
            ), f"Original sprite {3244 + i} does not match exported SD frame"
    sheet = Image.new("RGBA", (384, 384), (255, 0, 255, 0))
    animation = scalar(1, 0) + scalar(2, 0) + scalar(3, 0) + scalar(4, 1) + scalar(5, 1)
    sprites = b""
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * 32, 0))
        sprites += scalar(5, first + i)
        animation += message(6, scalar(1, 100) + scalar(2, 100))
    info = scalar(1, 1) + scalar(2, 1) + scalar(3, 1) + scalar(4, 1) + sprites + message(6, animation) + scalar(7, 32) + scalar(8, 0)
    # Retain flags/other metadata from modern effect 18, while using a new identity.
    template = existing[18]
    new_effect = scalar(1, args.effect_id) + b"".join(
        raw for n, w, v, raw in fields(template) if n not in (1, 2)
    ) + message(2, scalar(1, 2) + scalar(2, 0) + message(3, info))
    result = original + message(3, new_effect)
    result_fields = list(fields(result))
    assert b"".join(raw for n, w, v, raw in result_fields[:-1]) == original
    assert identity(result_fields[-1][2]) == args.effect_id
    bmp = io.BytesIO()
    sheet.save(bmp, format="BMP")
    compressed = lzma.compress(bmp.getvalue(), format=lzma.FORMAT_ALONE)
    size = varint(len(compressed))
    cip = bytes(32 - 5 - len(size)) + bytes.fromhex("700afa8024") + size + compressed
    assert lzma.decompress(cip[32:], format=lzma.FORMAT_ALONE) == bmp.getvalue()
    appearance_name = "appearances-" + digest(result) + ".dat"
    sheet_name = "sprites-" + digest(cip) + ".bmp.lzma"
    report = dict(effectId=args.effect_id, sourceSpriteIds=[3244, 3251], newSpriteIds=[first, first + 7],
                  frames=8, frameDurationMs=100, totalDurationMs=800,
                  appearance=appearance_name, sheet=sheet_name,
                  unchangedExistingEffects=len(existing))
    print(json.dumps(report, indent=2))
    if not args.apply:
        return
    backup(catalog_path)
    for name, data in ((appearance_name, result), (sheet_name, cip)):
        dest = args.assets / name
        assert not dest.exists() or dest.read_bytes() == data
        dest.write_bytes(data)
        assert dest.read_bytes() == data
    appearance_entry["file"] = appearance_name
    catalog.append(dict(type="sprite", file=sheet_name, spritetype=0, firstspriteid=first,
                        lastspriteid=first + 143, area=0))
    catalog_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    project = Path(__file__).resolve().parents[2]
    local_tools = project / ".tools"
    if local_tools.exists():
        (local_tools / "sd-effects-import.json").write_text(json.dumps(report, indent=2) + "\n")
        preview = Image.new("RGBA", (256, 32), (0, 0, 0, 0))
        for i, frame in enumerate(frames):
            preview.paste(frame, (i * 32, 0))
        preview.resize((1024, 128), Image.Resampling.NEAREST).save(local_tools / "sd-effects-preview.png")

if __name__ == "__main__":
    run()
