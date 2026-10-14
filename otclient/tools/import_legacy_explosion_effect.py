"""Create an independent 15-phase Explosion effect from the installed legacy Mas Vis.
Reuses immutable sprite IDs; retains original appearance records byte-for-byte.
"""
import json
from pathlib import Path
from import_legacy_sd_effect import fields, identity, scalar, message, digest, backup

root = Path(__file__).resolve().parents[2]
assets = root / 'otclient/data/things/1525'
catpath = assets / 'catalog-content.json'
cat = json.loads(catpath.read_bytes())
entry = next(e for e in cat if e['type'] == 'appearances')
original = (assets / entry['file']).read_bytes()
effects = {identity(v): v for n,w,v,r in fields(original) if n == 3}
newid = max(effects) + 1
source = effects[351]
group = next(v for n,w,v,r in fields(source) if n == 2)
info = next(v for n,w,v,r in fields(group) if n == 3)
sprites = [v for n,w,v,r in fields(info) if n == 5]
assert len(sprites) == 16
indices = [round(i*15/14) for i in range(15)]
assert len(set(indices)) == 15 and indices[0] == 0 and indices[-1] == 15
animation = next(v for n,w,v,r in fields(info) if n == 6)
newanim = b''.join(r for n,w,v,r in fields(animation) if n != 6)
durations = [round((i+1)*800/15)-round(i*800/15) for i in range(15)]
newanim += b''.join(message(6,scalar(1,d)+scalar(2,d)) for d in durations)
newinfo = b''.join(r for n,w,v,r in fields(info) if n not in (5,6))
newinfo += b''.join(scalar(5,sprites[i]) for i in indices) + message(6,newanim)
newgroup = b''.join(r for n,w,v,r in fields(group) if n != 3) + message(3,newinfo)
newrecord = scalar(1,newid) + b''.join(r for n,w,v,r in fields(source) if n not in (1,2)) + message(2,newgroup)
result = original + message(3,newrecord)
assert result[:len(original)] == original
name = 'appearances-' + digest(result) + '.dat'
dest = assets/name
assert not dest.exists()
dest.write_bytes(result)
backup(catpath)
entry['file'] = name
catpath.write_text(json.dumps(cat,indent=2)+'\n',encoding='utf-8')
ignore = assets.parent/'.gitignore'
backup(ignore)
with ignore.open('a',encoding='utf-8') as f:
    f.write('!1525/'+name+'\n')
rune = root/'canary/data/scripts/runes/explosion.lua'
backup(rune)
text = rune.read_text(encoding='utf-8')
text = text.replace('local combat = Combat()', 'local combat = Combat()\nlocal traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)',1)
text = text.replace('combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_EXPLOSIONAREA)',f'combat:setParameter(COMBAT_PARAM_EFFECT, traditional and {newid} or CONST_ME_EXPLOSIONAREA)',1)
text = text.replace('function onGetFormulaValues(player, level, maglevel)\n', 'function onGetFormulaValues(player, level, maglevel)\n\tif traditional then\n\t\t-- Nostalrius Explosion: same scaling for all vocations.\n\t\tlocal base = 2 * level + 3 * maglevel\n\t\treturn -0.20 * base, -base\n\tend\n',1)
rune.write_text(text,encoding='utf-8')
report = dict(effectId=newid,sourceEffectId=351,frames=15,durationMs=sum(durations),selectedSourceFrames=[i+1 for i in indices],spriteIds=[sprites[i] for i in indices],appearance=name)
(root/'.tools/explosion-effect-import.json').write_text(json.dumps(report,indent=2)+'\n')
for p in [root/'canary/docs/systems/traditional-combat.md',root/'.agents/pipeline/OT_Tiozao_CONTINUIDADE.md']:
    backup(p)
    with p.open('a',encoding='utf-8') as f:
        f.write(f'\n## Explosion tradicional (2026-10-14)\nMinimo = 0.20 * (2L + 3ML); maximo = 2L + 3ML, sem fator de classe. Moderno preservado. Efeito exclusivo {newid}, derivado do Mas Vis antigo 351 com 15 fases e duracao total 800 ms (53/54 ms por fase). Reutiliza sprites existentes sem substituir IDs. Area, projetil, requisitos, cooldown e bloqueio por armadura preservados. Sem commit; teste no jogo pendente.\n')
print(json.dumps(report,indent=2))
