-- Exercise real scripts, their modern fallback, floors and cast metadata.
local modern = false
configKeys = {MODERN_COMBAT_SYSTEM=1}
configManager = {getBoolean=function() return modern end}
for _, name in ipairs({"COMBAT_PARAM_TYPE","COMBAT_PARAM_EFFECT","COMBAT_PARAM_DISTANCEEFFECT",
    "COMBAT_PARAM_AGGRESSIVE","COMBAT_PARAM_TARGETCASTERORTOPMOST","COMBAT_PARAM_DISPEL",
    "COMBAT_HEALING","COMBAT_ENERGYDAMAGE","COMBAT_DEATHDAMAGE","COMBAT_FIREDAMAGE",
    "CONDITION_PARALYZE","CALLBACK_PARAM_TARGETCREATURE","CALLBACK_PARAM_LEVELMAGICVALUE","CONST_ME_MAGIC_BLUE",
    "CONST_ME_ENERGYAREA","CONST_ME_MORTAREA","CONST_ME_FIREATTACK","CONST_ANI_ENERGY",
    "CONST_ANI_DEATH","CONST_ANI_FIRE","SOUND_EFFECT_TYPE_SPELL_OR_RUNE",
    "SOUND_EFFECT_TYPE_SPELL_INTENSE_HEALING_RUNE","SOUND_EFFECT_TYPE_SPELL_HEAVY_MAGIC_MISSILE_RUNE",
    "SOUND_EFFECT_TYPE_SPELL_ENERGY_STRIKE","SOUND_EFFECT_TYPE_SPELL_DEATH_STRIKE",
    "SOUND_EFFECT_TYPE_SPELL_FLAME_STRIKE"}) do _G[name] = name end
local params, metadata, registered, executions, targetCallback, extraEffects
Combat = function()
    params = {}
    targetCallback = nil
    extraEffects = {}
    return {setParameter=function(_,k,v) params[k]=v end,
        setCallback=function(_,kind,name)
            if kind == CALLBACK_PARAM_TARGETCREATURE then
                assert(name == "onHMMTargetCreature")
                targetCallback = _G[name]
            else assert(name == "onGetFormulaValues") end
        end,
        execute=function()
            executions=executions+1
            if targetCallback then
                targetCallback({}, {getPosition=function()
                    return {sendMagicEffect=function(_,id) extraEffects[#extraEffects+1]=id end}
                end})
            end
            return true
        end}
end
Spell = function(kind)
    registered = setmetatable({}, {__index=function(_,method)
        return function(_,...) metadata[method]={...} end
    end})
    metadata = {kind=kind}
    return registered
end
Monster = function() return nil end
local function close(a,b) assert(math.abs(a-b)<1e-8, tostring(a).." ~= "..tostring(b)) end
local paths = {
    {"runes/intense_healing_rune",COMBAT_HEALING,CONST_ME_MAGIC_BLUE,nil},
    {"runes/heavy_magic_missile",COMBAT_ENERGYDAMAGE,357,70},
    {"spells/attack/energy_strike",COMBAT_ENERGYDAMAGE,354,71},
    {"spells/attack/death_strike",COMBAT_DEATHDAMAGE,352,69},
    {"spells/attack/flame_strike",COMBAT_FIREDAMAGE,356,70},
}
local originalEffects = {CONST_ME_MAGIC_BLUE,CONST_ME_ENERGYAREA,CONST_ME_ENERGYAREA,CONST_ME_MORTAREA,CONST_ME_FIREATTACK}
local originalMissiles = {false,CONST_ANI_ENERGY,CONST_ANI_ENERGY,CONST_ANI_DEATH,CONST_ANI_FIRE}
local snapshots = {}
for _, mode in ipairs({true,false,true}) do
    modern = mode
    for i,p in ipairs(paths) do
        executions = 0
        dofile("data/scripts/"..p[1]..".lua")
        assert(params[COMBAT_PARAM_TYPE] == p[2])
        assert(params[COMBAT_PARAM_EFFECT] == (modern and originalEffects[i] or p[3]))
        local expectedMissile = modern and originalMissiles[i] or p[4]
        assert(params[COMBAT_PARAM_DISTANCEEFFECT] == (expectedMissile or nil))
        local metadataKey = table.concat({metadata.kind,metadata.level[1],metadata.cooldown[1],metadata.groupCooldown[1]},":")
        if snapshots[i] then assert(metadataKey==snapshots[i]) else snapshots[i]=metadataKey end
        if i==1 then
            assert(metadata.magicLevel[1]==1 and metadata.runeId[1]==3152)
        elseif i==2 then
            assert(metadata.magicLevel[1]==3 and metadata.runeId[1]==3198 and metadata.charges[1]==10)
        else
            assert(metadata.mana[1]==20 and metadata.range[1]==3)
        end
        for _, profile in ipairs({{1,0},{8,1},{50,4},{50,12},{50,45},{300,9},{300,28},{300,90},{400,100}}) do
            local level,ml=profile[1],profile[2]
            local a,b=onGetFormulaValues({},level,ml)
            if i==1 then
                if modern then close(a,level/5+ml*3.2+20); close(b,level/5+ml*5.4+40)
                else local power=math.max(100,2*level+3*ml);close(a,.4*power);close(b,power) end
                assert(a>0 and b>=a)
            elseif i==2 then
                if modern then close(a,-(level/5+ml*.4+2));close(b,-(level/5+ml*1.59+10))
                else local power=math.max(100,2*level+3*ml);close(a,-.2*power);close(b,-.4*power) end
                assert(a<0 and b<=a)
            else
                local factor=modern and 1 or .8
                close(a,-(level/5+ml*1.403+8)*factor);close(b,-(level/5+ml*2.203+13)*factor)
                assert(a<0 and b<=a)
            end
        end
        if not modern then
            local a,b=onGetFormulaValues({},300,90)
            if i==1 then close(a,348);close(b,870)
            elseif i==2 then close(a,-174);close(b,-348)
            else close(a,-155.416);close(b,-217.016) end
        end
        assert(registered.onCastSpell({}, {getNumber=function() return 1 end},true))
        assert(executions==1,"Visual changes must not execute damage twice")
        if i==2 and not modern then
            assert(targetCallback and #extraEffects==1 and extraEffects[1]==350,
                "Traditional HMM must combine GFB overlay with shock impact")
        else assert(not targetCallback and #extraEffects==0,"Overlay leaked into another spell/mode") end
    end
end
print("IH/HMM/strike tests passed: both modes, floors, own ML, bounds, visual IDs, metadata, single execution")
