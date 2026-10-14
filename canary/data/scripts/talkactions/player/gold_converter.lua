local configFile = assert(io.open("config.lua", "r"), "Cannot read gold converter configuration")
local configText = configFile:read("*a")
configFile:close()
local vipSetting = ("\n" .. configText):match("\n%s*goldConverterVipOnly%s*=%s*(%a+)")
assert(vipSetting == "true" or vipSetting == "false", "goldConverterVipOnly must be true or false in config.lua")

local config = {
	vipOnly = vipSetting == "true", -- No items or charges are consumed.
	interval = 1000,
}

local preferenceKey = "talkaction.goldconverter.enabled"

local function canConvert(player)
	return player:kv():get(preferenceKey) == true and (not config.vipOnly or player:isVip())
end

local cursors = {}
local playerOffset = 0
local function convertCoins(player)
	if not canConvert(player) then
		return
	end
	local guid = player:getGuid()
	local state = cursors[guid]
	if not state or state.runtimeId ~= player:getId() then
		state = { runtimeId = player:getId(), root = 0, positions = {} }
		cursors[guid] = state
	end
	local inspected, changed = 0, 0
	local candidates = {}
	local function convertStack(item, nextId)
		local parent = item:getParent()
		if parent and parent:isContainer() then
			-- Inspect only this container, within the shared per-tick budget.
			for index = 0, parent:getSize() - 1 do
				if inspected >= 128 then
					break
				end
				inspected = inspected + 1
				local target = parent:getItem(index)
				if target and target ~= item and target:getId() == nextId and target:getCount() > 0 and target:getCount() < 100 then
					local previousCount = target:getCount()
					target:transform(nextId, previousCount + 1)
					if target:getCount() ~= previousCount + 1 then
						return
					end
					if not item:remove(100) then
						target:transform(nextId, previousCount)
						return
					end
					changed = changed + 1
					return
				end
			end
		end
		-- Reuse the source slot when no suitable destination stack was found.
		item:transform(nextId, 1)
		changed = changed + 1
	end
	local function visit(item, path, depth)
		if not item or inspected >= 128 or changed >= 8 or depth > 32 then
			return
		end
		inspected = inspected + 1
		if item:isContainer() then
			local size = item:getSize()
			if size == 0 then
				return
			end
			local start = (state.positions[path] or 0) % size
			for offset = 0, size - 1 do
				if inspected >= 128 or changed >= 8 then
					break
				end
				local index = (start + offset) % size
				state.positions[path] = index + 1
				visit(item:getItem(index), path .. "/" .. index, depth + 1)
			end
			return
		end
		local id = item:getId()
		local nextId = id == ITEM_GOLD_COIN and ITEM_PLATINUM_COIN or (id == ITEM_PLATINUM_COIN and ITEM_CRYSTAL_COIN)
		if not nextId then
			return
		end
		local count = item:getCount()
		if count == 100 then
			convertStack(item, nextId)
			return
		end
		if count <= 0 or count > 100 then
			return
		end
		local target = candidates[id]
		if not target or target:getId() ~= id or target:getCount() >= 100 then
			candidates[id] = item
			return
		end
		if target == item then
			return
		end
		local originalCount = target:getCount()
		local transfer = math.min(count, 100 - originalCount)
		target:transform(id, originalCount + transfer)
		if target:getCount() ~= originalCount + transfer then
			return
		end
		if not item:remove(transfer) then
			target:transform(id, originalCount)
			return
		end
		changed = changed + 1
		if target:getCount() == 100 then
			candidates[id] = nil
			if changed < 8 then
				convertStack(target, nextId)
			end
		end
	end
	-- Rotate roots and container indices; no recursive inventory snapshots.
	for offset = 0, CONST_SLOT_AMMO do
		if inspected >= 128 or changed >= 8 then
			break
		end
		local slot = state.root
		state.root = (slot + 1) % (CONST_SLOT_AMMO + 1)
		visit(slot == 0 and player:getStoreInbox() or player:getSlotItem(slot), tostring(slot), 0)
	end
end

local command = TalkAction("!goldconverter")

function command.onSay(player, words, param)
	param = param:trim():lower()
	if param ~= "on" and param ~= "off" then
		player:sendCancelMessage("Usage: !goldconverter on/off")
		return true
	end
	if param == "on" and config.vipOnly and not player:isVip() then
		player:sendCancelMessage("You need VIP to use the gold converter.")
		return true
	end
	player:kv():set(preferenceKey, param == "on")
	convertCoins(player)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Gold converter " .. param .. ".")
	return true
end

command:separator(" ")
command:setDescription("[Usage]: !goldconverter on/off - Automatically combines and converts gold to platinum and platinum to crystal for free. VIP may be required by server configuration.")
command:groupType("normal")
command:register()

local converter = GlobalEvent("FreeGoldConverter")

function converter.onThink(interval)
	local players = Game.getPlayers()
	local online = {}
	for _, player in ipairs(players) do
		online[player:getGuid()] = true
	end
	for guid in pairs(cursors) do
		if not online[guid] then
			cursors[guid] = nil
		end
	end
	for index = 1, math.min(#players, 16) do
		convertCoins(players[(playerOffset + index - 1) % #players + 1])
	end
	if #players > 0 then
		playerOffset = (playerOffset + 16) % #players
	end
	return true
end

converter:interval(config.interval)
converter:register()
