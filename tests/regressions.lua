-- Run from the addon directory with: luajit tests/regressions.lua
function GetAddOnMetadata() return '2.1.0' end
function GetTime() return 100 end
function UnitName() return 'Reviewer' end
function GetRealmName() return 'Realm' end
local inCombat = false
function InCombatLockdown() return inCombat end
function date(fmt) return fmt == '%H' and '13' or '05' end
function UnitXP() return 25 end
function UnitXPMax() return 100 end
function GetXPExhaustion() return 0 end
function IsInGuild() return true end
function GetNumGuildMembers() return 5, 3 end
C_FriendList = {GetNumOnlineFriends = function() return 2 end}
SlashCmdList = {}
local function noop() end
local frames = {}
function CreateFrame()
    local frame = {RegisterEvent = noop}
    function frame:SetScript(event, callback) self[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
C_Timer = {After = noop}
local T = {}
assert(loadfile('Core/Core.lua'))('Tempus', T)
local loader = assert(frames[2], 'core event frame')
T.Style = {C = {}, Backdrop = function() return {} end}
T.Options = {Refresh = noop}
assert(loadfile('Modules/Minimap/DataBar.lua'))('Tempus', T)
T.DataBar.db = {time24 = false}
for _, accent in ipairs({'ff5757', 'b377ff'}) do
    T.accentHex = accent
    local texts = T.DataBar.texts
    assert(texts.time.text() == '1:05 |cff' .. accent .. 'pm|r')
    assert(texts.xp.text() == 'XP |cff' .. accent .. '25.0%|r')
    assert(texts.friends.text() == 'Friends |cff' .. accent .. '2|r')
    assert(texts.guild.text() == 'Guild |cff' .. accent .. '3|r')
end
print('PASS: all info-bar accents follow current settings')

local retired = {dpstrack = {peak = 5}, modules = {dpstrack = true, swing = true}, swing = {}}
T.PruneRetired(retired)
assert(retired.dpstrack == nil and retired.modules.dpstrack == nil and retired.modules.swing and retired.swing)
T.PruneRetired({})
print('PASS: settings of the retired DPS track module are dropped')

-- A keyed out-of-combat job keeps its queue position but uses the newest callback.
local deferred = {}
inCombat = true
T:RunOOC(function() deferred[#deferred + 1] = 'old' end, 'layout')
T:RunOOC(function() deferred[#deferred + 1] = 'new' end, 'layout')
T:RunOOC(function() deferred[#deferred + 1] = 'last' end, 'last')
inCombat = false
loader.OnEvent(loader, 'PLAYER_REGEN_ENABLED')
assert(table.concat(deferred, ',') == 'new,last', 'keyed out-of-combat jobs are replaced and ordered')

TempusDB = {debug = {}}
inCombat = true
T:RunOOC(function() error('deferred failure') end, 'failure')
inCombat = false
loader.OnEvent(loader, 'PLAYER_REGEN_ENABLED')
assert(TempusDB.debug.lastError.err:find('deferred failure', 1, true), 'deferred errors reach diagnostics')
print('PASS: out-of-combat jobs replace duplicates, preserve order and report errors')

local oldCfg = {width = 100}
local activeCfg = oldCfg
local inactiveCalls = 0
T:NewModule('active', {OnSettings = function() activeCfg = T.db.active end})
T:NewModule('inactive', {OnSettings = function() inactiveCalls = inactiveCalls + 1 end})
T.modules.active.enabled = true
TempusDB = {chars = {}, debug = {}, profiles = {
    Old = {modules = {active = true, inactive = false}, active = oldCfg},
    New = {modules = {active = false, inactive = true}, active = {width = 200}},
}}
T.db = TempusDB.profiles.Old
T:SetProfile('New')
assert(activeCfg.width == 200 and activeCfg == T.db.active)
assert(T.modules.active.enabled and not T:ModuleEnabled('active'))
assert(inactiveCalls == 0 and not T.modules.inactive.enabled)
assert(T.Options.needsReload == true)
T.Options.needsReload = false
T:CopyProfile('Old')
assert(activeCfg.width == 100 and T.Options.needsReload)
T.Options.needsReload = false
T:ResetProfile()
assert(T.Options.needsReload)
print('PASS: profile switch, copy and reset update active settings and request reload')

-- Reset keeps a copy that /tempus undo brings back; the confirm dialog runs at once without popups.
TempusDB.profiles.New = {modules = {active = true}, active = {width = 321}}
T:SetProfile('New')
T:ConfirmReset()
assert(next(TempusDB.profiles.New.active or {}) == nil or TempusDB.profiles.New.active.width ~= 321, 'reset cleared the profile')
local undone, undoName = T:UndoProfileChange()
assert(undone and undoName == 'New' and T.db.active.width == 321, 'undo restores the profile from before the reset')
assert(not T:UndoProfileChange(), 'undo only works once')
T:ConfirmCopy('Old')
assert(T.db.active.width == 100, 'copy replaced the active profile')
assert(T:UndoProfileChange() and T.db.active.width == 321, 'undo restores the profile from before a copy')
T:ConfirmDelete('New')
assert(TempusDB.profiles.New, 'the active profile is never deleted')
print('PASS: reset and copy ask first and can be undone')

local printed = {}
local realPrint = T.Print
T.Print = function(_, msg, ...) printed[#printed + 1] = msg:format(...) end
SlashCmdList.TEMPUS('help')
local helpText = table.concat(printed, '\n')
assert(#printed > 10 and helpText:find('shop', 1, true) and not helpText:find('bagdump', 1, true), 'help lists everyday commands only')
printed = {}
SlashCmdList.TEMPUS('help dev')
assert(table.concat(printed, '\n'):find('bagdump', 1, true), 'help dev lists troubleshooting commands')
T.Print = realPrint
print('PASS: slash help is one command per line with troubleshooting separate')

assert(loadfile('Modules/Skins/Skins.lua'))('Tempus', T)
local SK = T.Skins
T.db.skins = {
    windows = false, parchment = false, tooltips = false, tooltipHealth = false,
    chat = false, bagnon = false, dbm = false, chatAlpha = 0.5, trackerAlpha = 0.5,
}
T.modules.skins.OnEnable()
T.Options.needsReload = false
T.db.skins.chatAlpha = 0.7
T.db.skins.trackerAlpha = 0.7
T.modules.skins.OnSettings()
assert(not T.Options.needsReload)
for _, key in ipairs({'windows', 'parchment', 'tooltips', 'tooltipHealth', 'chat', 'bagnon', 'dbm'}) do
    T.db.skins[key] = true
    T.modules.skins.OnSettings()
    assert(T.Options.needsReload, key .. ' must request reload')
    T.db.skins[key] = false
    T.Options.needsReload = false
end
print('PASS: structural skin settings request reload; opacity changes stay live')

SK.InitChat = function() error('chat initialization failure') end
SK.db.chat = true
T.modules.skins.OnEnable()
assert(TempusDB.debug.skinErrors.chat:find('chat initialization failure', 1, true))
assert(T.log[#T.log].kind == 'skin')
SK.db.chat = false
print('PASS: skin initialization errors reach diagnostics')

local function window(name)
    return {
        GetObjectType = function() return 'Frame' end,
        GetName = function() return name end,
        GetRegions = noop, GetChildren = noop,
        HookScript = function(self, event, callback)
            self.hooks = (self.hooks or 0) + 1
            self[event] = callback
        end,
    }
end
local attempts = 0
MerchantFrame = window('MerchantFrame')
MerchantFrame.GetRegions = function()
    attempts = attempts + 1
    if attempts == 1 then error('transient merchant failure') end
end
SK.db.windows = true
SK:SkinWindows()
assert(not SK.skinned[MerchantFrame] and TempusDB.debug.skinErrors.MerchantFrame)
assert(T.log[#T.log].kind == 'skin' and T.log[#T.log].msg:find('transient merchant failure', 1, true))
SK:SkinWindows()
assert(SK.skinned[MerchantFrame] and MerchantFrame.hooks == 1)
assert(TempusDB.debug.skinErrors.MerchantFrame == nil)
local completedAttempts = attempts
SK:SkinWindows()
assert(attempts == completedAttempts and MerchantFrame.hooks == 1)
MerchantFrame.GetChildren = function() error('late merchant failure') end
MerchantFrame.OnShow(MerchantFrame)
assert(TempusDB.debug.skinErrors.MerchantFrame:find('late merchant failure', 1, true))
print('PASS: failed skins retry, successful skins run once, late failures reach diagnostics')

InspectFrame = window('InspectFrame')
local slotAttempts = 0
HeadSlot = window('HeadSlot')
InspectHeadSlot = HeadSlot
HeadSlot.GetRegions = function()
    slotAttempts = slotAttempts + 1
    if slotAttempts == 1 then error('transient inspect slot failure') end
end
SK:SkinWindows()
assert(SK.skinned[InspectFrame] and not SK.extrasSkinned[InspectFrame])
assert(InspectFrame.hooks == 1 and TempusDB.debug.skinErrors.InspectFrame)
SK:SkinWindows()
assert(SK.extrasSkinned[InspectFrame] and InspectFrame.hooks == 1)
assert(TempusDB.debug.skinErrors.InspectFrame == nil)
print('PASS: extra skin failure retries without repeating base setup')

MerchantFrame, InspectFrame, InspectHeadSlot, HeadSlot = nil, nil, nil, nil
assert(loadfile('tests/reward-text.lua'))()
assert(loadfile('tests/tracker-panel.lua'))()
