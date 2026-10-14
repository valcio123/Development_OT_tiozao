local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_FIREDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) and CONST_ME_HITBYFIRE or 359)

local area = createCombatArea(AREA_WAVE4, AREADIAGONAL_WAVE4)
combat:setArea(area)

function onGetFormulaValues(player, level, maglevel)
	if not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) then
		local power = math.max(100, 2 * level + 3 * maglevel)
		return -0.20 * power, -0.40 * power
	end
	local min = (level / 5) + (maglevel * 1.25) + 4
	local max = (level / 5) + (maglevel * 2) + 12
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(19)
spell:name("Fire Wave")
spell:words("exevo flam hur")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_FIRE_WAVE)
spell:level(18)
spell:mana(25)
spell:isPremium(false)
spell:needDirection(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
