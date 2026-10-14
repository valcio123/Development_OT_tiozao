-- Calibrate sustainable Exori DPS to 90% of ED Mas Tera DPS while using
-- ordinary mana potions. Preserve skill, weapon and own-ML scaling around
-- these progression anchors.
local calibration = {
	{ level = 50, mageML = 45, skill = 90, knightML = 4 },
	{ level = 80, mageML = 55, skill = 100, knightML = 5 },
	{ level = 100, mageML = 65, skill = 110, knightML = 6 },
	{ level = 200, mageML = 80, skill = 120, knightML = 8 },
	{ level = 300, mageML = 90, skill = 100, knightML = 9, targetDps = 144 },
	{ level = 400, mageML = 100, skill = 140, knightML = 10 },
}

for _, point in ipairs(calibration) do
	local bonus = 0.30 * (math.min(point.skill, 90) - 10) + 5 + 0.10 * point.knightML
	local multiplier = 1 + 0.007 * math.max(point.skill - 90, 0)
	local referenceAverage = (4.16 * point.level + bonus) * 1.30 * multiplier
	local masVisAverage = 2.825 * (2 * point.level + 3 * point.mageML)
	local masTeraAverage = 0.70 * masVisAverage
	local edManaRate = 100 + 1 -- 100 average mana/sec from ordinary mana potions plus vocation regen
	local knightManaRate = 100 + (2 / 6) -- potions plus 2 mana every 6 seconds
	local masTeraDps = masTeraAverage * edManaRate / 1200
	local exoriManaCost = math.max(225, math.ceil(2.8 * point.level))
	local targetDps = point.targetDps or (0.90 * masTeraDps)
	local targetExoriAverage = targetDps * exoriManaCost / knightManaRate
	point.factor = targetExoriAverage / referenceAverage
end

local function traditionalLevelFactor(level)
	if level <= calibration[1].level then
		return calibration[1].factor
	end
	for index = 2, #calibration do
		local upper = calibration[index]
		if level <= upper.level then
			local lower = calibration[index - 1]
			local progress = (level - lower.level) / (upper.level - lower.level)
			return lower.factor + (upper.factor - lower.factor) * progress
		end
	end
	return calibration[#calibration].factor
end

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HITAREA)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, 1)
combat:setParameter(COMBAT_PARAM_USECHARGES, 1)
combat:setArea(createCombatArea(AREA_SQUARE1X1))

function onGetFormulaValues(player, skill, attack, factor)
	local level = player:getLevel()
	if not configManager.getBoolean(configKeys.MODERN_COMBAT_SYSTEM) then
		local highestSkill = math.max(player:getEffectiveSkillLevel(SKILL_SWORD), player:getEffectiveSkillLevel(SKILL_AXE), player:getEffectiveSkillLevel(SKILL_CLUB))
		local skillBonus = 0.30 * (math.min(highestSkill, 90) - 10)
		local bonus = skillBonus + 0.10 * attack + 0.10 * player:getMagicLevel()
		local skillMultiplier = 1 + 0.007 * math.max(highestSkill - 90, 0)
		local levelFactor = traditionalLevelFactor(level)
		return -((3.12 * level + bonus) * 1.30 * skillMultiplier * levelFactor), -((5.20 * level + bonus) * 1.30 * skillMultiplier * levelFactor)
	end

	local min = (level / 5) + (skill + attack) * 0.5
	local max = (level / 5) + (skill + attack) * 1.5

	return -min * 1.1, -max * 1.1 -- TODO : Use New Real Formula instead of an %
end

combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(80)
spell:name("Berserk")
spell:words("exori")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_BERSERK)
spell:level(35)
spell:mana(115)
spell:isPremium(false)
spell:needWeapon(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("knight;true", "elite knight;true")
spell:register()
