-- Run from custom/otclient with LuaJIT. Exercise the actual event handlers.
local file = assert(io.open("modules/game_actionbar/game_actionbar.lua", "r"))
local source = file:read("*a")
file:close()
local function loadHandler(startMarker, endMarker)
    local first = assert(source:find(startMarker, 1, true))
    local last = assert(source:find(endMarker, first + #startMarker, true))
    assert(loadstring(source:sub(first, last - 1)))()
end

modules = {client_options = {getOption = function() return true end}}
g_clock = {millis = function() return 0 end}
MarketCategory = {Potions = 1, Runes = 2, Tools = 3}
table.contains = function(t, value)
    for _, entry in ipairs(t) do if entry == value then return true end end
    return false
end
table.empty = function(t) return next(t) == nil end
spellGroupCooldownCache = {}
Spells = {}
local spellFile = assert(io.open("modules/gamelib/spells.lua", "r"))
local spellSource = spellFile:read("*a")
spellFile:close()
local helpersStart = assert(spellSource:find("function Spells.getCooldownByGroup(", 1, true))
local helpersEnd = assert(spellSource:find("function Spells.getIconFileByProfile(", helpersStart, true))
assert(loadstring(spellSource:sub(helpersStart, helpersEnd - 1)))()
assert(Spells.getCooldownByGroup({group = {[1] = 2000, [3] = 1000}}, 1) == 2000)
assert(Spells.getCooldownBySecondaryGroup({group = {[1] = 2000, [3] = 1000}}, 3) == 1000)
assert(Spells.getCooldownByGroup({group = 1, exhaustion = 2000}, 1) == 2000)
assert(Spells.getCooldownBySecondaryGroup({group = 1, exhaustion = 2000}, 1) == nil)
assert(Spells.getCooldownByGroup({}, 1) == nil)
assert(Spells.getGroupIds({group = 1})[1] == 1)
assert(Spells.getPrimaryGroup({group = 1}) == 1)
assert(Spells.getPrimaryGroup({group = {[1] = 2000, [3] = 1000}}) == 1)
assert(Spells.getPrimaryGroup({}) == -1)
getButtonCache = function(button) return button.cache end
updateButtonState = function() end
schedulePendingMultiButtonUpdate = function() end
removeEvent = function() end
scheduleEvent = function(callback, delay) return {callback = callback, delay = delay} end
removeCooldown = function(button) button.duration = 0 end
updateCooldown = function(button, delay) button.duration = delay; button.elapsed = 0 end

local function button(category, isRune, group)
    local b = {duration = 0, elapsed = 0, cache = {itemId = 3191, isRuneSpell = isRune}}
    if group then b.cache.spellData = {group = group, exhaustion = 2000} end
    b.isDestroyed = function() return b.destroyed or false end
    b.cooldown = {
        getDuration = function() return b.duration end,
        getTimeElapsed = function() return b.elapsed end,
    }
    b.item = {getItem = function() return {
        isMultiUse = function() return true end,
        getMarketData = function() return {category = category} end,
    } end}
    return b
end

local gfb = button(MarketCategory.Runes, true, 1)
local uh = button(MarketCategory.Runes, true, 2)
local potion = button(MarketCategory.Potions, false)
activeActionBars = {{tabBar = {getChildren = function() return {gfb, uh, potion} end}}}
loadHandler("function onSpellGroupCooldown(", "--- Handles passive ability data updates")
loadHandler("function onMultiUseCooldown(", "function updateInventoryItems(")

onSpellGroupCooldown(1, 2000)
onSpellGroupCooldown(2, 2000)
assert(gfb.duration == 2000 and uh.duration == 2000, "rune group cooldown ignored")
assert(potion.duration == 0, "spell exhaustion applied to ordinary potion")
gfb.elapsed = 100
uh.elapsed = 100
onMultiUseCooldown(1000)
assert(gfb.duration == 2000 and gfb.elapsed == 100, "GFB cooldown shortened or restarted")
assert(uh.duration == 2000 and uh.elapsed == 100, "UH cooldown shortened or restarted")
assert(potion.duration == 1000, "ordinary potion item cooldown changed")
gfb.elapsed = 1900
onMultiUseCooldown(1000)
assert(gfb.duration == 1000, "longer remaining item cooldown must still apply")
assert(gfb.cache.removeCooldownEvent.delay == 1000, "old group timer would remove the extended cooldown early")
gfb.destroyed = true
gfb.cache.removeCooldownEvent.callback()
assert(gfb.duration == 1000, "expired callback touched a destroyed button")
-- Once the attack lock expires, a healing cast advertises 1s to every group.
gfb.destroyed = false
gfb.duration = 0
uh.duration = 0
onSpellGroupCooldown(1, 1000)
onSpellGroupCooldown(2, 1000)
assert(gfb.duration == 1000 and uh.duration == 1000, "healing shared lock must display 1s")
gfb.elapsed = 100
uh.elapsed = 100
onMultiUseCooldown(1000)
assert(gfb.duration == 1000 and uh.duration == 1000, "item packet changed healing lock duration")
gfb.duration = 0
uh.duration = 0
onSpellGroupCooldown(1, 2000)
onSpellGroupCooldown(2, 2000)
assert(gfb.duration == 2000 and uh.duration == 2000, "next attack must restore the 2s shared lock")
print("Actionbar cooldown tests passed: attack/healing shared timers, packet overwrite and potion independence")
