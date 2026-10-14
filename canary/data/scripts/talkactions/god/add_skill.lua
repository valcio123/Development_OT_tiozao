local skills = {
    fist = SKILL_FIST, club = SKILL_CLUB, sword = SKILL_SWORD, axe = SKILL_AXE,
    dist = SKILL_DISTANCE, distance = SKILL_DISTANCE,
    shield = SKILL_SHIELD, shielding = SKILL_SHIELD,
    fish = SKILL_FISHING, fishing = SKILL_FISHING,
}

local function registerSkillCommand(command, direction)
    local action = TalkAction(command)
    local usage = command .. " nome, level|magic|fist|club|sword|axe|distance|shielding|fishing, quantidade"
    function action.onSay(player, words, param)
        param = param:gsub("^%s*,%s*", "")
        local args = param:split(",")
        local amount = tonumber(args[3])
        local name = args[2] and args[2]:trim():lower()
        if #args < 2 or #args > 3 or (name ~= "level" and name ~= "magic" and skills[name] == nil) then
            player:sendCancelMessage("Usage: " .. usage)
            return true
        end
        if #args == 2 and direction == 1 then amount = 1 end
        if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 10000 then
            player:sendCancelMessage("Quantidade deve ser um inteiro entre 1 e 10000.")
            return true
        end
        local target = Player(args[1]:trim())
        if not target then
            player:sendCancelMessage("Player not found (must be online).")
            return true
        end
        local before = name == "level" and target:getLevel() or (name == "magic" and target:getBaseMagicLevel() or target:getSkillLevel(skills[name]))
        local minimum = name == "level" and 1 or (name == "magic" and 0 or 10)
        local after = before + direction * amount
        if after < minimum or after > 65534 then
            player:sendCancelMessage("Resultado fora do limite: minimo " .. minimum .. ", maximo 65534.")
            return true
        end
        logCommand(player, words, param)
        local success
        if name == "level" then
            local exp = Game.getExperienceForLevel(after)
            if direction == 1 then
                success = target:addExperience(exp - target:getExperience(), false)
            else
                success = target:removeExperience(target:getExperience() - exp, false)
            end
        elseif name == "magic" then
            success = target:setMagicLevel(after, 0)
        else
            success = target:setSkillLevel(skills[name], after, 0)
        end
        if not success then
            player:sendCancelMessage("Failed to change player progression.")
            return true
        end
        local actual = name == "level" and target:getLevel() or (name == "magic" and target:getBaseMagicLevel() or target:getSkillLevel(skills[name]))
        local message = string.format("%s: %s %d -> %d (base; progress reset).", target:getName(), name, before, actual)
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, message)
        if target ~= player then target:sendTextMessage(MESSAGE_EVENT_ADVANCE, message) end
        return true
    end
    action:separator(" ")
    action:groupType("god")
    action:setDescription("[Usage]: " .. usage .. " - Ajusta niveis base exatos; zera progresso parcial. Level recalcula XP, vida, mana, capacidade e velocidade.")
    action:register()
end

registerSkillCommand("/addskill", 1)
registerSkillCommand("/removeskill", -1)
