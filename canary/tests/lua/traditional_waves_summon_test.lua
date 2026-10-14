local modern=false
configKeys={MODERN_COMBAT_SYSTEM=1}
configManager={getBoolean=function() return modern end}
local function constant(name) _G[name]=name end
for _,name in ipairs({'COMBAT_PARAM_EFFECT','COMBAT_PARAM_DISTANCEEFFECT','COMBAT_PARAM_TYPE','COMBAT_ENERGYDAMAGE','COMBAT_FIREDAMAGE','CONST_ME_ENERGYAREA','CONST_ME_HITBYFIRE','CONST_ANI_ENERGY','CALLBACK_PARAM_LEVELMAGICVALUE','AREA_SQUAREWAVE5','AREADIAGONAL_SQUAREWAVE5','AREA_WAVE7','AREADIAGONAL_WAVE7','AREA_WAVE4','AREADIAGONAL_WAVE4','CONST_ME_POFF','CONST_ME_MAGIC_BLUE','CONST_ME_TELEPORT','RETURNVALUE_NOTPOSSIBLE','RETURNVALUE_NOTENOUGHMANA','RETURNVALUE_NOTENOUGHROOM','PlayerFlag_CanSummonAll','PlayerFlag_HasInfiniteMana'}) do constant(name) end
createCombatArea=function(a,b) return {a,b} end
local combats,spell,executed
Combat=function()
    local c={params={}}
    function c:setParameter(k,v) self.params[k]=v end
    function c:setCallback(k,name) self.callback=_G[name] end
    function c:setArea(area) self.area=area end
    function c:execute() executed=self; return true end
    combats[#combats+1]=c
    return c
end
Spell=function()
    spell=setmetatable({metadata={}}, {__index=function(t,k) return function(_,...) t.metadata[k]={...} end end})
    return spell
end
local player={getWheelSpellAdditionalArea=function() return true end}
function player:getPlayer() return self end
for _,mode in ipairs({true,false,true}) do
    modern=mode
    for _,wave in ipairs({'energy','fire'}) do
        combats={}
        dofile('data/scripts/spells/attack/'..wave..'_wave.lua')
        for _,profile in ipairs({{1,0},{8,1},{50,45},{80,55},{100,65},{200,80},{300,90},{400,100}}) do
            local l,m=profile[1],profile[2]
            local min,max=combats[1].callback(player,l,m)
            local a,b
            if modern then
                if wave=='energy' then a,b=l/5+m*4.5,l/5+m*9 else a,b=l/5+m*1.25+4,l/5+m*2+12 end
            else
                local p=math.max(100,2*l+3*m)
                if wave=='energy' then a,b=p,2*p else a,b=.2*p,.4*p end
            end
            assert(math.abs(min+a)<1e-8 and math.abs(max+b)<1e-8)
        end
        assert(spell.onCastSpell(player,{}))
        assert(executed==combats[modern and wave=='energy' and 2 or 1], 'Traditional wave used modern wheel area')
        local params=combats[1].params
        if not modern then
            assert(params[COMBAT_PARAM_EFFECT]==(wave=='energy' and 358 or 359))
            assert(params[COMBAT_PARAM_DISTANCEEFFECT]==nil)
        end
        assert(spell.metadata.mana[1]==(wave=='energy' and 170 or 25))
    end
end
local mana,summons,valid,summonable,room,infinite,created,spent,notice
local pos={sendMagicEffect=function() end}
local caster={getPosition=function() return pos end,getMana=function() return mana end,
    getSummons=function() return summons end,sendCancelMessage=function(_,text) notice=text end,
    hasFlag=function(_,flag) return flag==PlayerFlag_HasInfiniteMana and infinite or false end,
    addMana=function(_,n) mana=mana+n end,addManaSpent=function(_,n) spent=spent+n end}
MonsterType=function(name)
    if not valid then return nil end
    assert(name=='Monk')
    return {isSummonable=function() return summonable end,getManaCost=function() return 600 end}
end
Game={createMonster=function(name,position,extended,force,master)
    assert(name=='Monk' and master==caster and not force)
    created=created+1
    if room then return {getPosition=function() return pos end} end
end}
for _,mode in ipairs({false,true}) do
    modern=mode; dofile('data/scripts/spells/support/summon_creature.lua')
    assert(spell.metadata.isAggressive[1]==modern)
    for _,case in ipairs({'success','empty','unknown','forbidden','limit','mana','room'}) do
        mana,summons,valid,summonable,room,infinite,created,spent=1000,{},true,true,true,false,0,0
        local text=' Monk '
        if case=='empty' then text='' elseif case=='unknown' then valid=false elseif case=='forbidden' then summonable=false elseif case=='limit' then summons={1,2} elseif case=='mana' then mana=599 elseif case=='room' then room=false end
        local before=mana
        local ok=spell.onCastSpell(caster,{getString=function() return text end})
        assert(ok==(case=='success'),case)
        assert(mana==before-(ok and 600 or 0) and spent==(ok and 600 or 0), 'Failed summon consumed mana')
    end
end
print('Wave formulas/modes/visuals/area and summon success/limits/failures: PASS')
