local combat = Combat()
local traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, traditional and 354 or CONST_ME_ENERGYAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, traditional and 71 or CONST_ANI_ENERGY)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 1.403) + 8
	local max = (level / 5) + (maglevel * 2.203) + 13
	if traditional then
		-- User balance: reduce both bounds of the current Canary formula by 20%.
		return -min * 0.80, -max * 0.80
	end
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(88)
spell:name("Energy Strike")
spell:words("exori vis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_OR_RUNE)
spell:impactSound(SOUND_EFFECT_TYPE_SPELL_ENERGY_STRIKE)
spell:level(12)
spell:mana(20)
spell:range(3)
spell:isPremium(false)
spell:needCasterTargetOrDirection(true)
spell:blockWalls(true)
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("druid;true", "elder druid;true", "sorcerer;true", "master sorcerer;true")
spell:register()
