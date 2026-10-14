local combat = Combat()
local traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, traditional and 353 or CONST_ME_EXPLOSIONAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, traditional and 70 or CONST_ANI_EXPLOSION)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, 1)
combat:setArea(createCombatArea(AREA_CIRCLE1X1))

function onGetFormulaValues(player, level, maglevel)
	if traditional then
		-- Nostalrius Explosion: same scaling for all vocations.
		local base = 2 * level + 3 * maglevel
		return -0.20 * base, -base
	end
	local min = 0
	local max = (level / 5) + (maglevel * 4.8)
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local rune = Spell("rune")

function rune.onCastSpell(creature, var, isHotkey)
	return combat:execute(creature, var)
end

rune:id(18)
rune:group("attack")
rune:name("explosion rune")
rune:castSound(SOUND_EFFECT_TYPE_SPELL_OR_RUNE)
rune:impactSound(SOUND_EFFECT_TYPE_SPELL_EXPLOSION_RUNE)
rune:runeId(3200)
rune:allowFarUse(true)
rune:charges(6)
rune:level(31)
rune:magicLevel(6)
rune:cooldown(2 * 1000)
rune:groupCooldown(2 * 1000)
rune:isBlocking(true) -- True = Solid / False = Creature
rune:register()
