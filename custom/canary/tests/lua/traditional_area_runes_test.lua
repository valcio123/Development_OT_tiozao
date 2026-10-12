local modern = false
configKeys = { MODERN_COMBAT_SYSTEM = 1 }
configManager = { getBoolean = function() return modern end }
local stub = { __index = function() return function() end end }
Combat = setmetatable({}, { __call = function() return setmetatable({}, stub) end })
Spell = function() return setmetatable({}, stub) end
createCombatArea = function() return {} end
dofile("data/libs/functions/combat.lua")

local function player(baseId)
	return { getVocation = function() return { getBaseId = function() return baseId end } end }
end
local function check(callback, id, level, ml, expectedMin, expectedMax)
	local min, max = callback(player(id), level, ml)
	assert(math.abs(min + expectedMin) < 0.000001, "minimum mismatch")
	assert(math.abs(max + expectedMax) < 0.000001, "maximum mismatch")
end

for _, name in ipairs({ "great_fireball", "avalanche", "thunderstorm" }) do
	dofile("data/scripts/runes/" .. name .. ".lua")
	local callback = onGetFormulaValues
	modern = false
	check(callback, 1, 50, 45, 82.25, 152.75)
	check(callback, 2, 50, 45, 82.25, 152.75)
	check(callback, 3, 50, 12, 35.7, 66.3)
	check(callback, 4, 50, 4, 23.52, 43.68)
	check(callback, 1, 200, 80, 224, 416)
	check(callback, 3, 200, 24, 123.9, 230.1)
	check(callback, 4, 200, 8, 89.04, 165.36)
	check(callback, 3, 400, 32, 235.2, 436.8)
	check(callback, 4, 400, 10, 174.3, 323.7)
	-- Both level and the caster's own ML must contribute.
	check(callback, 3, 201, 24, 124.425, 231.075)
	check(callback, 3, 200, 25, 124.6875, 231.5625)
	modern = true
	if name == "thunderstorm" then
		check(callback, 3, 100, 18, 44, 82.8)
	else
		check(callback, 3, 100, 18, 48.6, 87.4)
	end
	modern = false
	check(callback, 4, 200, 8, 89.04, 165.36)
end
print("Area rune tests passed: all three callbacks, class factors, level/ML scaling and modern restoration")
