function Combat:getPositions(creature, variant)
	local positions = {}
	function onTargetTile(creature, position)
		positions[#positions + 1] = position
	end

	self:setCallback(CALLBACK_PARAM_TARGETTILE, "onTargetTile")
	self:execute(creature, variant)
	return positions
end

-- Base vocation IDs also cover promoted characters via Vocation:getBaseId().
local traditionalAreaRuneFactors = {
	[1] = 1.00, -- Sorcerer
	[2] = 1.00, -- Druid
	[3] = 0.75, -- Paladin
	[4] = 0.60, -- Knight
}

function getTraditionalAreaRuneDamage(player, level, magicLevel)
	local factor = traditionalAreaRuneFactors[player:getVocation():getBaseId()] or 1.00
	local base = 2 * level + 3 * magicLevel
	return -base * 0.35 * factor, -base * 0.65 * factor
end

function Combat:getTargets(creature, variant)
	local targets = {}
	function onTargetCreature(creature, target)
		targets[#targets + 1] = target
	end

	self:setCallback(CALLBACK_PARAM_TARGETCREATURE, "onTargetCreature")
	self:execute(creature, variant)
	return targets
end
