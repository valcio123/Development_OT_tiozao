local combat = Combat()
local traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)
combat:setParameter(COMBAT_PARAM_TYPE, traditional and COMBAT_PHYSICALDAMAGE or COMBAT_DEATHDAMAGE)
-- Dedicated legacy impact: original 7.60 sprites 3244-3251, eight 100 ms frames.
combat:setParameter(COMBAT_PARAM_EFFECT, traditional and 352 or CONST_ME_MORTAREA)
-- Dedicated legacy death ball; modern projectile remains unchanged.
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, traditional and 69 or CONST_ANI_SUDDENDEATH)

function onGetFormulaValues(player, level, maglevel)
	if traditional then
		-- Nostalrius SD: 130%-170% of level/ML power; use the caster's effective ML.
		local base = 2 * level + 3 * maglevel
		local factor = player:getVocation():getBaseId() == 4 and 0.30 or 1.00
		return -1.30 * base * factor, -1.70 * base * factor
	end

	local min = (level / 5) + (maglevel * 4.605) + 28
	local max = (level / 5) + (maglevel * 7.395) + 46
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local rune = Spell("rune")

function rune.onCastSpell(creature, var, isHotkey)
	return combat:execute(creature, var)
end

rune:id(21)
rune:group("attack")
rune:name("sudden death rune")
rune:castSound(SOUND_EFFECT_TYPE_SPELL_OR_RUNE)
rune:impactSound(SOUND_EFFECT_TYPE_SPELL_SUDDENDEATH_RUNE)
rune:runeId(3155)
rune:allowFarUse(true)
rune:charges(3)
rune:level(45)
rune:magicLevel(15)
rune:cooldown(2 * 1000)
rune:groupCooldown(2 * 1000)
rune:needTarget(true)
rune:isBlocking(true) -- True = Solid / False = Creature
rune:register()
