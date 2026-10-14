-- Loaded once before datapack libraries. Settings are startup-only.
-- Read config into an isolated environment: do not expose credentials/globals.
local chunk, err = loadfile("config.lua")
assert(chunk, err)
local settings = setmetatable({}, { __index = _G })
setfenv(chunk, settings)
chunk()

CreatureRebalance = {}
local policy = CreatureRebalance
policy.enabled = settings.rebalanceSystemEnabled == true
policy.damageMultiplier = settings.rebalanceCreatureDamageMultiplier or 1.3
policy.lootMultiplier = settings.rebalanceLootMultiplier or 0.8
policy.healthMultiplier = settings.rebalanceModernCreatureHealthMultiplier or 1.2
policy.seeInvisible = settings.rebalanceModernCreaturesSeeInvisible ~= false
policy.manaPotionPrice = settings.rebalanceManaPotionPrice or 100
policy.legacy = dofile("data/libs/functions/rebalance_legacy_creatures.lua")
policy.rookgaard = dofile("data/libs/functions/rebalance_rookgaard_creatures.lua")
assert(policy.lootMultiplier > 0 and policy.lootMultiplier <= 1, "rebalanceLootMultiplier must be in (0,1]")
assert(policy.healthMultiplier >= 1, "rebalanceModernCreatureHealthMultiplier must be >= 1")
assert(policy.manaPotionPrice > 0 and policy.manaPotionPrice == math.floor(policy.manaPotionPrice), "rebalanceManaPotionPrice must be a positive integer")

function policy.isExcluded(name)
    return policy.rookgaard[(name or ""):lower()] == true
end

-- config.lua already applies the global damage multiplier. Excluded types
-- use the configured base rate directly, avoiding per-hit rounding compensation.
function policy.attackMultiplierOverride(name, boss)
    if not policy.enabled or not policy.isExcluded(name) then return -1 end
    local rate = boss and settings.rateBossAttack or settings.rateMonsterAttack
    return (rate or policy.damageMultiplier) / policy.damageMultiplier
end

function policy.isModern(mask, monsterName)
    if mask.introducedVersion then return mask.introducedVersion > 7.6 end
    return not policy.legacy[(monsterName or mask.name or ""):lower()]
end

-- Traditional starter fauna: species-wide, matching the Rookgaard exclusion scope.
-- Strong enemies (minotaurs, skeletons, goblins, ghouls, spearmen, bosses) are omitted.
local starterDefenseSpecies = {
    ["rat"]=true, ["cave rat"]=true, ["spider"]=true, ["poison spider"]=true,
    ["snake"]=true, ["bug"]=true, ["cockroach"]=true, ["wolf"]=true,
    ["bear"]=true, ["troll"]=true, ["young troll"]=true, ["island troll"]=true,
    ["orc"]=true, ["wasp"]=true, ["cat"]=true, ["chicken"]=true,
    ["deer"]=true, ["pig"]=true, ["rabbit"]=true, ["sheep"]=true,
    ["seagull"]=true, ["silver rabbit"]=true, ["blue butterfly"]=true,
    ["red butterfly"]=true,
}
function policy.starterDefenseDefinition(mask, monsterName)
    if not policy.enabled or settings.modernCombatSystem ~= false
        or not starterDefenseSpecies[(monsterName or mask.name or ""):lower()]
        or not mask.defenses then return mask end
    local adjusted, defenses = {}, {}
    for key, value in pairs(mask) do adjusted[key] = value end
    for key, value in pairs(mask.defenses) do defenses[key] = value end
    -- Round base values once; retain at least 1 armor when originally positive.
    if defenses.defense then defenses.defense = math.floor(defenses.defense * 0.60 + 0.5) end
    if defenses.armor and defenses.armor > 0 then
        defenses.armor = math.max(1, math.floor(defenses.armor * 0.50 + 0.5))
    end
    defenses.mitigation = 0
    adjusted.defenses = defenses
    return adjusted
end
function policy.monsterDefinition(mask, monsterName)
    mask = policy.starterDefenseDefinition(mask, monsterName)
    if not policy.enabled or policy.isExcluded(monsterName or mask.name) or not policy.isModern(mask, monsterName) then return mask end
    -- Copy rather than mutating script/shared tables: reload cannot compound HP.
    local adjusted = {}
    for key, value in pairs(mask) do adjusted[key] = value end
    for _, key in ipairs({ "health", "maxHealth" }) do
        if mask[key] then
            adjusted[key] = math.min(2147483647, math.floor(mask[key] * policy.healthMultiplier + 0.5))
        end
    end
    if policy.seeInvisible then
        adjusted.immunities = {}
        local found = false
        for _, immunity in pairs(mask.immunities or {}) do
            local entry = {}
            for key, value in pairs(immunity) do entry[key] = value end
            if entry.type == "invisible" then entry.condition = true; found = true end
            table.insert(adjusted.immunities, entry)
        end
        if not found then table.insert(adjusted.immunities, { type = "invisible", condition = true }) end
    end
    return adjusted
end

-- Native attack rates scale direct combat. Attached poison/bleed damage does
-- not use that multiplier, so adjust only its definition (never the direct hit).
function policy.attackDefinition(attack, monsterName)
    if not policy.enabled or policy.isExcluded(monsterName) or not attack.condition or not attack.condition.totalDamage then return attack end
    local copy, condition = {}, {}
    for key, value in pairs(attack) do copy[key] = value end
    for key, value in pairs(attack.condition) do condition[key] = value end
    condition.totalDamage = math.floor(condition.totalDamage * policy.damageMultiplier + 0.5)
    copy.condition = condition
    return copy
end

function policy.buyPrice(itemId, itemName, originalPrice)
    if policy.enabled and originalPrice and (itemId == 268 or (itemName or ""):lower() == "mana potion") then
        return policy.manaPotionPrice
    end
    return originalPrice
end

if policy.enabled then
    logger.info("Creature rebalance enabled: attack x{}, post-7.6 health x{}, see invisible {}, loot x{}, mana potion {} gp. Restart required to toggle.",
        settings.rebalanceCreatureDamageMultiplier or 1.3, policy.healthMultiplier, policy.seeInvisible, policy.lootMultiplier, policy.manaPotionPrice)
end