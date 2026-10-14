local combat = Combat()
local traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)
combat:setParameter(COMBAT_PARAM_TYPE, traditional and COMBAT_PHYSICALDAMAGE or COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, traditional and 351 or CONST_ME_BIGCLOUDS)
combat:setArea(createCombatArea(AREA_CIRCLE6X6))

function onGetFormulaValues(player, level, maglevel)
	if not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) then
		-- Nostalrius Ultimate Explosion damage, with the approved 1.13 factor.
		local base = 2 * level + 3 * maglevel
		return -2.26 * base, -3.39 * base
	end

	local min = (level / 5) + (maglevel * 7)
	local max = (level / 5) + (maglevel * 14)
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack", "focus")
spell:id(119)
spell:name("Rage of the Skies")
spell:words("exevo gran mas vis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_RAGE_OF_THE_SKIES)
spell:level(55)
spell:mana(600)
spell:isSelfTarget(true)
spell:isPremium(false)
spell:cooldown(40 * 1000)
spell:groupCooldown(4 * 1000, 40 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
