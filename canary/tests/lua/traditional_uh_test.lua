-- Executes the real rune formula callback with isolated registration stubs.
-- Run from the repository root with LuaJIT/Lua 5.1.
local modern = true
configKeys = { MODERN_COMBAT_SYSTEM = 1 }
configManager = {
	getBoolean = function(key)
		assert(key == configKeys.MODERN_COMBAT_SYSTEM)
		return modern
	end,
}

local function registrationStub()
	return setmetatable({}, {
		__index = function()
			return function() end
		end,
	})
end
Combat = registrationStub
Spell = registrationStub

dofile("data/scripts/runes/ultimate_healing_rune.lua")

local function check(level, ml, expectedMin, expectedMax)
	local min, max = onGetFormulaValues(nil, level, ml)
	assert(math.abs(min - expectedMin) < 0.000001, "unexpected minimum")
	assert(math.abs(max - expectedMax) < 0.000001, "unexpected maximum")
	assert(min <= max, "inverted healing interval")
end

modern = false
check(1, 0, 250, 250)
check(25, 4, 250, 250)
check(50, 0, 250, 250)
check(100, 8, 560, 560)
check(100, 60, 950, 950)
check(1000, 100, 5750, 5750)

modern = true
check(100, 8, 120.4, 209.2)
check(100, 60, 500, 854)

modern = false
check(100, 8, 560, 560)
modern = true
check(100, 8, 120.4, 209.2)

print("UH formula tests passed: floor, scaling, modern restoration and mode cycles")
