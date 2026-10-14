local function formulaFunction(player, level, maglevel)
	if not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) then
		local power = math.max(100, 2 * level + 3 * maglevel)
		return -power, -2 * power
	end
	local min = (level / 5) + (maglevel * 4.5)
	local max = (level / 5) + (maglevel * 9)
	return -min, -max
end

function onGetFormulaValues(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

function onGetFormulaValuesWOD(player, level, maglevel)
	return formulaFunction(player, level, maglevel)
end

local function createCombat(area, areaDiagonal, combatFunc)
	local initCombat = Combat()
	initCombat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, combatFunc)
	initCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
	if configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) then
		initCombat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ENERGYAREA)
		initCombat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_ENERGY)
	else
		-- Legacy wave lights each affected tile; no flying projectile.
		initCombat:setParameter(COMBAT_PARAM_EFFECT, 358)
	end
	initCombat:setArea(createCombatArea(area, areaDiagonal))
	return initCombat
end

local combat = createCombat(AREA_SQUAREWAVE5, AREADIAGONAL_SQUAREWAVE5, "onGetFormulaValues")
local combatWOD = createCombat(AREA_WAVE7, AREADIAGONAL_WAVE7, "onGetFormulaValuesWOD")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local player = creature:getPlayer()
	if creature and player then
		if configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) and player:getWheelSpellAdditionalArea("Energy Wave") then
			return combatWOD:execute(creature, var)
		end
	end
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(13)
spell:name("Energy Wave")
spell:words("exevo vis hur")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_ENERGY_WAVE)
spell:level(38)
spell:mana(170)
spell:needDirection(true)
spell:cooldown(8 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("sorcerer;true", "master sorcerer;true")
spell:register()
