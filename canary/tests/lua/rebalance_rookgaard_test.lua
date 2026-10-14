-- Real policy, isolated synthetic config: no private settings or live DB.
local originalLoadfile = loadfile
loadfile = function(path)
    if path == "config.lua" then
        return assert(loadstring("rebalanceSystemEnabled=true; rebalanceCreatureDamageMultiplier=1.3; rateMonsterAttack=2.6; rateBossAttack=3.9"))
    end
    return originalLoadfile(path)
end
logger = { info = function() end }
dofile("data/libs/functions/creature_rebalance.lua")
loadfile = originalLoadfile
local p = CreatureRebalance
assert(p.isExcluded("Troll Champion") and p.isExcluded("Rat"))
assert(not p.isExcluded("Dragon") and not p.isExcluded("Rat King"))
assert(math.abs(p.attackMultiplierOverride("Rat", false) - 2) < 0.00001)
assert(math.abs(p.attackMultiplierOverride("Munster", true) - 3) < 0.00001)
assert(p.attackMultiplierOverride("Dragon", false) == -1)
local champion = { name="Troll Champion", health=75, maxHealth=75, immunities={{type="invisible",condition=false}} }
assert(p.monsterDefinition(champion) == champion)
local modern = { name="Custom Modern", health=100, maxHealth=100, immunities={{type="invisible",condition=false}} }
local adjusted = p.monsterDefinition(modern)
assert(adjusted.health == 120 and modern.health == 100)
assert(adjusted.immunities[1].condition and not modern.immunities[1].condition)
local atk = { minDamage=-10, maxDamage=-30, interval=2000, chance=100, condition={totalDamage=100} }
assert(p.attackDefinition(atk,"Rat") == atk)
local boosted = p.attackDefinition(atk,"Dragon")
assert(boosted.condition.totalDamage == 130 and atk.condition.totalDamage == 100)
assert(boosted.interval == 2000 and boosted.chance == 100 and boosted.maxDamage == -30)
p.enabled=false
assert(p.monsterDefinition(modern) == modern)
assert(p.attackDefinition(atk,"Dragon") == atk)
assert(p.attackMultiplierOverride("Rat",false) == -1)
print("Rookgaard rebalance policy tests OK")

-- Exercise the actual central loot roll: same random number, exempt vs normal.
p.enabled = true
MonsterType = {}
configKeys = { RATE_LOOT = 1 }
configManager = { getNumber = function() return 1 end }
ItemType = function() return { getId=function() return 2148 end, getCharges=function() return 0 end, isStackable=function() return false end } end
getLootRandom = function() return 90000 end
local random = math.random
math.random = function() return 100 end
dofile("data/libs/functions/monstertype.lua")
local function roll(name)
    local monster = setmetatable({ name=function() return name end,
        getLoot=function() return {{itemId=2148,chance=100000}} end,
        isRewardBoss=function() return false end }, {__index=MonsterType})
    return monster:generateLootRoll({factor=1,gut=false})
end
assert(roll("Rat")[2148].count == 1)
assert(roll("Dragon")[2148] == nil)
p.enabled = false
assert(roll("Dragon")[2148].count == 1)
math.random = random
print("Central loot exemption tests OK")