local combat = Combat()
local traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, traditional and 352 or CONST_ME_MORTAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, traditional and 69 or CONST_ANI_DEATH)

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
spell:id(87)
spell:name("Death Strike")
spell:words("exori mort")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_OR_RUNE)
spell:impactSound(SOUND_EFFECT_TYPE_SPELL_DEATH_STRIKE)
spell:level(16)
spell:mana(20)
spell:isPremium(false)
spell:range(3)
spell:needCasterTargetOrDirection(true)
spell:blockWalls(true)
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
