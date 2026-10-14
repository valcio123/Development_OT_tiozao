local function read(path) local f=assert(io.open(path)); local s=f:read('*a');f:close();return s end
local function extract(path, first, last)
 local s=read(path); local a=assert(s:find(first,1,true)); local b=assert(s:find(last,a+#first,true));return s:sub(a,b-1)
end
modules={game_hotkeys={isHotkeyUsedByManager=function(k) return k=='F3' end}}
local helper=assert(loadstring(extract('modules/game_actionbar/logics/ApiJson.lua','local function ensureFunctionKeyDefaults','local function rebuildStateFromArray')..' return ensureFunctionKeyDefaults'))()
local profile={chatOn={{actionsetting={action='Other'},keysequence='F2'},{actionsetting={action='TriggerActionButton_1.4'},keysequence=''}},chatOff={}}
helper({Default=profile});helper({Default=profile})
assert(#profile.actionBarOptions.mappings==12)
for _,mode in ipairs({'chatOn','chatOff'}) do
 local seen={}; for _,e in ipairs(profile[mode]) do local k=e.keysequence;if k~='' then assert(not seen[k]);seen[k]=true end end
 assert(seen.F1 and seen.F12 and not seen.F3)
 if mode=='chatOn' then assert(not seen.F4) end
end
local data={profiles={'Default'},hotkeyOptions={currentHotkeySetName='Default',hotkeySets={Default=profile}}}
g_resources={fileExists=function() return true end,readFileContents=function() return '' end}
json={decode=function() return data end}
g_settings={getBoolean=function() return false end}
modules.game_console={isChatEnabled=function() return true end}
local api=dofile('modules/game_actionbar/logics/ApiJson.lua')
assert(api.loadData('test'));assert(api.refreshState())
api.removeHotkey('1.10');assert(api.refreshState())
local f1,f10=false,false
for _,e in ipairs(api.getHotkeyEntries('chatOn')) do
 if e.actionsetting.action=='TriggerActionButton_1.1' then f1=e.keysequence=='F1' end
 if e.actionsetting.action=='TriggerActionButton_1.10' then f10=e.keysequence=='' end
end
assert(f1 and f10,'Clearing F10 must not clear F1 or restore F10')
local meaningful=assert(loadstring(extract('modules/game_hotkeys/hotkeys_manager.lua','local function hasHotkeyAction','end')..'end return hasHotkeyAction'))()
assert(not meaningful({value=''}));assert(meaningful({value='exura'}));assert(meaningful({itemId=3160}))
local loadCalls,static=0,false
Controller={new=function() return {setUI=function() end} end}
modules.game_interface={getMainRightPanel=function() end}
g_game={getClientVersion=function() return 1525 end}
LocalPlayer={}
g_minimap={clean=function() end}
g_resources.fileExists=function() return false end
g_satelliteMap={loadFloors=function(path,a,b) assert(path=='/data/things/1525' and a==0 and b==15);loadCalls=loadCalls+1 end}
assert(loadstring(read('modules/game_minimap/minimap.lua')))()
mapController.registerEvents=function() return {execute=function() end} end
mapController.ui={minimapBorder={minimap={load=function() end,setUseStaticMinimap=function(_,v) static=v end}}}
mapController:onGameStart();assert(static and loadCalls==1)
assert(not read('modules/game_cyclopedia/tab/map/map.lua'):find('g_satelliteMap.clear()',1,true))
print('Default F1-F12, custom conflicts, explicit clear F10, blank Ctrl+K and full minimap startup: PASS')