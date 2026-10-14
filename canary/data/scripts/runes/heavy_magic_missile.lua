local combat = Combat()
local traditional = not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM)
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ENERGYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, traditional and 357 or CONST_ME_ENERGYAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, traditional and 70 or CONST_ANI_ENERGY)

function onGetFormulaValues(player, level, maglevel)
	if traditional then
		-- Classic HMM: energy damage, legacy fire projectile and shock impact (sprites 330/331).
		local power = math.max(100, 2 * level + 3 * maglevel)
		return -0.20 * power, -0.40 * power
	end
	local min = (level / 5) + (maglevel * 0.4) + 2
	local max = (level / 5) + (maglevel * 1.59) + 10
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

if traditional then
	-- Visual overlay only: one HMM damage calculation, GFB explosion plus shock.
	function onHMMTargetCreature(creature, target)
		target:getPosition():sendMagicEffect(350)
	end
	combat:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onHMMTargetCreature")
end

local rune = Spell("rune")

function rune.onCastSpell(creature, var, isHotkey)
	return combat:execute(creature, var)
end

rune:id(8)
rune:group("attack")
rune:name("heavy magic missile rune")
rune:castSound(SOUND_EFFECT_TYPE_SPELL_OR_RUNE)
rune:impactSound(SOUND_EFFECT_TYPE_SPELL_HEAVY_MAGIC_MISSILE_RUNE)
rune:runeId(3198)
rune:allowFarUse(true)
rune:charges(10)
rune:level(25)
rune:magicLevel(3)
rune:cooldown(2 * 1000)
rune:groupCooldown(2 * 1000)
rune:needTarget(true)
rune:isBlocking(true) -- True = Solid / False = Creature
rune:register()
