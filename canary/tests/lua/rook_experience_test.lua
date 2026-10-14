SERVER_NAME = 'Test'
Player = {}
Condition = function() return {} end
configKeys = {STAMINA_SYSTEM=1, LOW_LEVEL_BONUS_EXP=2}
configManager = {
    getBoolean=function() return true end,
    getNumber=function() return 50 end
}
dofile('data/libs/functions/player.lua')
local p = setmetatable({level=1, vocation=0, stamina=2520, premium=true}, {__index=Player})
function p:getLevel() return self.level end
function p:getVocation() return {getId=function() return self.vocation end} end
function p:getStamina() return self.stamina end
function p:isPremium() return self.premium end
function p:setGrindingXpBoost(v) self.bonus=v end
function p:getGrindingXpBoost() return self.bonus end
for _, case in ipairs({{1,0,true},{7,1,true},{8,0,true},{8,1,false},{50,4,false},{300,2,false},{100,0,true}}) do
    p.level,p.vocation=case[1],case[2]
    assert(p:hasRookieExperienceBonuses()==case[3])
    for _, stamina in ipairs({0,840,841,2340,2341,2520}) do
        p.stamina=stamina
        local expected = not case[3] and 1 or (stamina > 2340 and 1.5 or stamina <= 840 and .5 or 1)
        assert(p:getFinalBonusStamina()==expected)
        assert(p:getFinalLowLevelBonus()==(case[3] and 50 or 0))
    end
end
p.level,p.vocation,p.stamina=7,0,2520
assert(p:getFinalLowLevelBonus()==50 and p:getFinalBonusStamina()==1.5)
p.level,p.vocation=8,1
assert(p:getFinalLowLevelBonus()==0 and p:getFinalBonusStamina()==1)
p.vocation=0
assert(p:getFinalLowLevelBonus()==50)
print('Rookie XP: levels 1/7/8/50/100/300, vocations, thresholds, leaving/returning, PASS')
