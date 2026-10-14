local combat = Combat()
local traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)
combat:setParameter(COMBAT_PARAM_TYPE, traditional and COMBAT_PHYSICALDAMAGE or COMBAT_EARTHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, traditional and CONST_ME_POISONAREA or CONST_ME_SMALLPLANTS)
combat:setArea(createCombatArea(AREA_CIRCLE6X6))

function onGetFormulaValues(player, level, maglevel)
	if not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) then
		local base = 2 * level + 3 * maglevel
		local druidDamageFactor = 0.70
		return -2.26 * base * druidDamageFactor, -3.39 * base * druidDamageFactor
	end

	local min = (level / 5) + (maglevel * 5)
	local max = (level / 5) + (maglevel * 10)
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack", "focus")
spell:id(56)
spell:name("Wrath of Nature")
spell:words("exevo gran mas tera")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_WRATH_OF_NATURE)
spell:level(55)
spell:mana(700)
spell:isPremium(false)
spell:isSelfTarget(true)
spell:cooldown(40 * 1000)
spell:groupCooldown(4 * 1000, 40 * 1000)

spell:vocation("druid;true", "elder druid;true")
spell:register()
