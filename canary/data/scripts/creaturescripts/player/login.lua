local function sendBoostMessage(player, category, isIncreased)
	return player:sendTextMessage(MESSAGE_BOOSTED_CREATURE, string.format("Event! %s is %screased. Happy Hunting!", category, isIncreased and "in" or "de"))
end

local playerLoginGlobal = CreatureEvent("PlayerLoginGlobal")

function playerLoginGlobal.onLogin(player)
    -- New rookies start in the original Rookgaard, not Dawnport/tutorial.
    -- The sample is migrated once; do not teleport returning rookstayers every login.
    local rookie = player:getVocation():getId() == 0
    local newCharacter = player:getLastLoginSaved() == 0
    local migrateSample = player:getName():lower() == "rook sample" and not player:kv():get("classic-rook-start")
    if rookie and (newCharacter or migrateSample) then
        local rook = Town("Rookgaard")
        if not rook then
            logger.error("[ClassicRookStart] Rookgaard town missing; refusing rookie login for {}", player:getName())
            return false
        end
        local temple = rook:getTemplePosition()
        if not Tile(temple) then
            logger.error("[ClassicRookStart] Rookgaard temple tile missing; refusing rookie login for {}", player:getName())
            return false
        end
        player:setTown(rook)
        player:teleportTo(temple)
        -- Legacy starter equipment: fill empty slots only, never replace sample items.
        local starter = {
            { CONST_SLOT_ARMOR, player:getSex() == 1 and 3561 or 3562 },
            { CONST_SLOT_RIGHT, 3270 }, -- club
            { CONST_SLOT_LEFT, 2920 }, -- torch
        }
        for _, entry in ipairs(starter) do
            if not player:getSlotItem(entry[1]) then
                player:addItem(entry[2], 1, false, 0, entry[1])
            end
        end
        if not player:getSlotItem(CONST_SLOT_BACKPACK) then
            local bag = player:addItem(2853, 1, false, 0, CONST_SLOT_BACKPACK)
            if bag then bag:addItem(3585, 1) end -- red apple
        end
        player:kv():set("classic-rook-start", true)
    end
	-- Welcome
	local loginStr
	if player:getLastLoginSaved() == 0 then
		loginStr = "Please choose your outfit."
		player:sendOutfitWindow()
		local startStreakLevel = configManager.getNumber(configKeys.START_STREAK_LEVEL)
		if startStreakLevel > 0 then
			player:setStreakLevel(startStreakLevel)
		end

		db.query("UPDATE `players` SET `istutorial` = 0 WHERE `id` = " .. player:getGuid())
	else
		loginStr = string.format("Your last visit in %s: %s.", SERVER_NAME, os.date("%d %b %Y %X", player:getLastLoginSaved()))
	end
	player:sendTextMessage(MESSAGE_LOGIN, loginStr)

	-- Promotion
	local vocation = player:getVocation()
	local promotion = vocation:getPromotion()
	if player:isPremium() then
		local hasPromotion = player:kv():get("promoted")
		if not player:isPromoted() and hasPromotion then
			player:setVocation(promotion)
		end
	elseif player:isPromoted() then
		player:setVocation(vocation:getDemotion())
	end

	-- Boosted
	player:sendTextMessage(MESSAGE_BOOSTED_CREATURE, string.format("Today's boosted creature: %s.", Game.getBoostedCreature()))
	player:sendTextMessage(MESSAGE_BOOSTED_CREATURE, string.format("Today's boosted boss: %s.", Game.getBoostedBoss()))

	-- Rewards
	local rewards = #player:getRewardList()
	if rewards > 0 then
		player:sendTextMessage(MESSAGE_LOGIN, string.format("You have %d reward%s in your reward chest.", rewards, rewards > 1 and "s" or ""))
	end

	-- Rate events:
	if SCHEDULE_EXP_RATE ~= 100 then
		sendBoostMessage(player, "Exp Rate", SCHEDULE_EXP_RATE > 100)
	end

	if SCHEDULE_SPAWN_RATE ~= 100 then
		sendBoostMessage(player, "Spawn Rate", SCHEDULE_SPAWN_RATE > 100)
	end

	if SCHEDULE_LOOT_RATE ~= 100 then
		sendBoostMessage(player, "Loot Rate", SCHEDULE_LOOT_RATE > 100)
	end

	if SCHEDULE_BOSS_LOOT_RATE ~= 100 then
		sendBoostMessage(player, "Boss Loot Rate", SCHEDULE_BOSS_LOOT_RATE > 100)
	end

	if SCHEDULE_SKILL_RATE ~= 100 then
		sendBoostMessage(player, "Skill Rate", SCHEDULE_SKILL_RATE > 100)
	end

	-- Send Recruiter Outfit
	local resultId = db.storeQuery("SELECT `recruiter` FROM `accounts` WHERE `id`= " .. Game.getPlayerAccountId(getPlayerName(player)))
	if resultId then
		local recruiterStatus = Result.getNumber(resultId, "recruiter")
		local sex = player:getSex()
		local outfitId = (sex == 1) and 746 or 745
		for outfitAddOn = 0, 2 do
			if recruiterStatus >= outfitAddOn * 3 + 1 then
				if not player:hasOutfit(outfitId, outfitAddOn) then
					if outfitAddOn == 0 then
						player:addOutfit(outfitId)
					else
						player:addOutfitAddon(outfitId, outfitAddOn)
					end
				end
			end
		end
	end

	-- Send Client Exp Display
	if configManager.getBoolean(configKeys.XP_DISPLAY_MODE) then
		local baseRate = player:getFinalBaseRateExperience() * 100
		if configManager.getBoolean(configKeys.VIP_SYSTEM_ENABLED) then
			local vipBonusExp = configManager.getNumber(configKeys.VIP_BONUS_EXP)
			if vipBonusExp > 0 and player:isVip() then
				vipBonusExp = (vipBonusExp > 100 and 100) or vipBonusExp
				baseRate = baseRate * (1 + (vipBonusExp / 100))
				player:sendTextMessage(MESSAGE_BOOSTED_CREATURE, "Normal base xp is: " .. baseRate .. "%, because you are VIP, bonus of " .. vipBonusExp .. "%")
			end
		end

		player:setBaseXpGain(baseRate)
	end

	player:setStaminaXpBoost(player:getFinalBonusStamina() * 100)
	player:getFinalLowLevelBonus()

	-- Updates the player's VIP status and executes corresponding actions if applicable.
	if configManager.getBoolean(configKeys.VIP_SYSTEM_ENABLED) then
		local isCurrentlyVip = player:isVip()
		local hadVipStatus = player:kv():scoped("account"):get("vip-system") or false

		if hadVipStatus ~= isCurrentlyVip then
			if hadVipStatus then
				player:onRemoveVip()
			else
				player:onAddVip(player:getVipDays())
			end
		end

		if isCurrentlyVip then
			player:sendVipStatus()
		end
	end

	-- Set Ghost Mode
	if player:getGroup():getId() >= GROUP_TYPE_GAMEMASTER then
		player:setGhostMode(true)
	end

	-- Resets
	if _G.OnExerciseTraining[player:getId()] then
		stopEvent(_G.OnExerciseTraining[player:getId()].event)
		_G.OnExerciseTraining[player:getId()] = nil
		player:setTraining(false)
	end

	local playerId = player:getId()
	if player.beginQuestTrackerInitialSync then
		player:beginQuestTrackerInitialSync()
	end
	if player.loadTrackedMissions then
		player:loadTrackedMissions(false)
	end

	_G.NextUseStaminaTime[playerId] = 1
	_G.NextUseXpStamina[playerId] = 1
	_G.NextUseConcoctionTime[playerId] = 1
	DailyReward.init(playerId)

	local stats = player:inBossFight()
	if stats then
		stats.playerId = player:getId()
	end

	-- Remove Boss Time
	if GetDailyRewardLastServerSave() >= player:getLastLoginSaved() then
		player:setRemoveBossTime(1)
	end

	-- Change support outfit to a normal outfit to open customize character without crashes
	local playerOutfit = player:getOutfit()
	if table.contains({ 75, 266, 302 }, playerOutfit.lookType) and not player:getGroup():getAccess() then
		playerOutfit.lookType = player:getSex() == PLAYERSEX_FEMALE and 136 or 128
		playerOutfit.lookAddons = 0
		player:setOutfit(playerOutfit)
	end

	player:initializeLoyaltySystem()
	player:registerEvent("PlayerDeath")
	player:registerEvent("DropLoot")
	player:registerEvent("BossParticipation")
	player:registerEvent("UpdatePlayerOnAdvancedLevel")

	-- Load the server-side quest tracker after the client has finished entering the game.
	-- The tracker is persisted in player KV and no longer depends only on client cache.
	addEvent(function(playerId)
		local loginPlayer = Player(playerId)
		if not loginPlayer then
			return
		end

		if loginPlayer.loadTrackedMissions then
			loginPlayer:loadTrackedMissions()
		end

		if loginPlayer.updateQuestTrackerKnownQuests then
			loginPlayer:updateQuestTrackerKnownQuests(false)
		end
	end, QuestTrackerServerConfig.loginLoadDelay, playerId)

	-- Safety fallback: keep a short window where empty client cache packets
	-- cannot wipe the server-side tracker loaded from KV.
	addEvent(function(playerId)
		local loginPlayer = Player(playerId)
		if not loginPlayer then
			return
		end
		if loginPlayer.finishQuestTrackerInitialSync then
			loginPlayer:finishQuestTrackerInitialSync()
		end
	end, QuestTrackerServerConfig.initialSyncWindow, playerId)

	if vocation and vocation:getBaseId() == VOCATION.BASE_ID.MONK then
		local kv = player:kv()
		if (kv:get("monk-basic-atk-bonus") or 0) < 10 then
			logger.info("Setting monk basic attack bonus 10 for player: {}.", player:getName())
			kv:set("monk-basic-atk-bonus", 10)
		end
	end
	return true
end

playerLoginGlobal:register()
