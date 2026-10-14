
local modern = false
configKeys = { MODERN_COMBAT_SYSTEM = 1 }
configManager = { getBoolean = function() return modern end }
COMBAT_PARAM_TYPE = "type"
COMBAT_PARAM_EFFECT = "effect"
COMBAT_PARAM_DISTANCEEFFECT = "projectile"
COMBAT_PHYSICALDAMAGE = "physical"
COMBAT_DEATHDAMAGE = "death"
CONST_ME_MORTAREA = 18
CONST_ANI_SUDDENDEATH = "sd-projectile"
CALLBACK_PARAM_LEVELMAGICVALUE = "formula"
local params
Combat = function()
    params = {}
    return {
        setParameter = function(_, key, value) params[key] = value end,
        setCallback = function() end,
        execute = function() return true end
    }
end
Spell = function()
    return setmetatable({}, { __index = function() return function() end end })
end
local function loadMode(value)
    modern = value
    dofile("data/scripts/runes/sudden_death.lua")
    assert(params.type == (modern and COMBAT_DEATHDAMAGE or COMBAT_PHYSICALDAMAGE))
    assert(params.effect == (modern and 18 or 352))
    assert(params.projectile == (modern and CONST_ANI_SUDDENDEATH or 69))
end
local function check(vocationId, level, ml, expectedMin, expectedMax)
    local baseId = vocationId > 4 and vocationId - 4 or vocationId
    local player = { getVocation = function() return { getBaseId = function() return baseId end } end }
    local min, max = onGetFormulaValues(player, level, ml)
    assert(math.abs(min + expectedMin) < 0.000001, "unexpected minimum")
    assert(math.abs(max + expectedMax) < 0.000001, "unexpected maximum")
end
loadMode(false)
check(1, 300, 90, 1131, 1479)
check(2, 300, 90, 1131, 1479)
check(3, 300, 28, 889.2, 1162.8)
check(4, 300, 15, 251.55, 328.95)
check(8, 300, 15, 251.55, 328.95)
check(4, 50, 15, 56.55, 73.95)
check(4, 300, 16, 252.72, 330.48)
check(4, 301, 15, 252.33, 329.97)
loadMode(true)
check(4, 300, 15, 157.075, 216.925)
check(1, 300, 90, 502.45, 771.55)
loadMode(false)
check(8, 300, 15, 251.55, 328.95)
print("SD tests passed: old bounds, 0.3 Knight/promoted factor, own effective ML, level scaling, elements, effects and modern restoration")
