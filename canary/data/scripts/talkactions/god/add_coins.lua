local addCoins = TalkAction("/addcoins")
function addCoins.onSay(player, words, param)
    param = param:gsub("^%s*,%s*", "")
    local args = param:split(",")
    local amount = tonumber(args[2])
    if #args ~= 2 or not amount or amount ~= math.floor(amount) or amount < 1 or amount > 4294967295 then
        player:sendCancelMessage("Usage: /addcoins player, quantidade (inteiro positivo).")
        return true
    end
    local target = Player(args[1]:trim())
    if not target then
        player:sendCancelMessage("Player not found (must be online).")
        return true
    end
    if target:getTransferableCoins() + amount > 4294967295 then
        player:sendCancelMessage("Coin balance would exceed its limit.")
        return true
    end
    logCommand(player, words, param)
    if not target:addTransferableCoins(amount) then
        player:sendCancelMessage("Failed to credit/save Tibia Coins.")
        return true
    end
    local message = string.format("%s: +%d transferable Tibia Coins. Balance: %d. Reopen Store to refresh.", target:getName(), amount, target:getTransferableCoins())
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, message)
    if target ~= player then target:sendTextMessage(MESSAGE_EVENT_ADVANCE, message) end
    return true
end
addCoins:separator(" ")
addCoins:groupType("god")
addCoins:setDescription("[Usage]: /addcoins player, quantidade - Credita Tibia Coins transferiveis na conta de um jogador online.")
addCoins:register()
