local modern = false
configKeys = { MODERN_COMBAT_SYSTEM = 1 }
configManager = { getBoolean = function() return modern end }
SKILL_SWORD, SKILL_AXE, SKILL_CLUB = 1, 2, 3
local stub = { __index = function() return function() end end }
Combat = function() return setmetatable({}, stub) end
Spell = function() return setmetatable({}, stub) end
createCombatArea = function() return {} end
dofile('data/scripts/spells/attack/berserk.lua')
local exori = onGetFormulaValues
dofile('data/scripts/spells/attack/rage_of_the_skies.lua')
local masVis = onGetFormulaValues
dofile('data/scripts/spells/attack/wrath_of_nature.lua')
local masTera = onGetFormulaValues
local function values(level, ml, skills, attack)
 local player = {
  getLevel = function() return level end,
  getMagicLevel = function() return ml end,
  getEffectiveSkillLevel = function(_, id) return skills[id] end,
 }
 local min, max = exori(player, 20, attack or 50, 1)
 return -min, -max
end
local function near(a, b) assert(math.abs(a-b) < 0.000001, tostring(a)..' != '..tostring(b)) end
local profiles = {
 {50,45,90,4},{80,55,100,5},{100,65,110,6},
	{200,80,120,8},{300,90,100,9},{400,100,140,10},
}
local previousTargetDps = 0
for _, p in ipairs(profiles) do
 local min, max = values(p[1],p[4],{20,p[3],30})
 local msMin, msMax = masVis(nil,p[1],p[2])
 local edMin, edMax = masTera(nil,p[1],p[2])
 near(edMin,msMin*0.70); near(edMax,msMax*0.70)
	local exoriManaCost = math.max(225, math.ceil(2.8 * p[1]))
	local exoriDps = ((min + max) / 2) / (exoriManaCost / (100 + 2 / 6))
	local edDps = ((-edMin - edMax) / 2) * (100 + 1) / 1200
	local expectedDps = p[1] == 300 and 144 or 0.90 * edDps
	near(exoriDps, expectedDps)
	assert(exoriDps > previousTargetDps, 'reference DPS must rise with level')
	previousTargetDps = exoriDps
 near(-msMin,2.26*(2*p[1]+3*p[2]))
 near(-msMax,3.39*(2*p[1]+3*p[2]))
 assert(min < max and min > 0)
 local otherMin, otherMax = values(p[1],p[4],{p[3],20,30})
 near(min,otherMin); near(max,otherMax)
end
-- Interpolated ranges must stay continuous and rise at fixed stats.
local previousMin,previousMax = values(1,10,{100,20,30})
for level=2,500 do
 local min,max = values(level,10,{100,20,30})
 assert(min > previousMin and max > previousMax, 'level scaling regressed at '..level)
 previousMin,previousMax = min,max
end
local min100,max100 = values(300,10,{100,20,30})
local min120,max120 = values(300,10,{120,20,30})
near(min120/min100,1.21/1.07); near(max120/max100,1.21/1.07)
local weaponMin,weaponMax = values(300,10,{100,20,30},51)
assert(weaponMin > min100 and weaponMax > max100)
local mlMin,mlMax = values(300,11,{100,20,30})
assert(mlMin > min100 and mlMax > max100)
modern = true
local min,max = values(100,6,{90,20,30})
near(min,60.5); near(max,137.5)
min,max = masVis(nil,50,45)
near(min,-325); near(max,-640)
min,max = masTera(nil,50,45)
near(min,-235); near(max,-460)
near(min,-235); near(max,-460)
print('Exori/Mas Tera tests passed: 90% sustained-DPS anchors, level 300 skill 100 at 144 DPS, rising progression, skills/weapon/ML and modern restoration')
