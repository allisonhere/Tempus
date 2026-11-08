-- The bank window must not stay empty when the game reports bank-tab slots only after it opens.
-- Run: lua5.1 tests/bags-bank-retry.lua
local T = { Bags = {}, db = { bags = { trackChars = false } }, NewModule = function() end,
    CharacterKey = function() return "Tester - Realm" end, Print = function() end }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
StaticPopupDialogs = {}
TempusDB = {}
assert(loadfile("Modules/Bags/Bags.lua"))("Tempus", T)
assert(loadfile("Modules/Bags/Inventory.lua"))("Tempus", T)
local B = T.Bags
B.Inventory = T.Inventory or B.Inventory
B.db = T.db.bags

local slots = 0
B.client = {
    Locations = function(_, storage)
        local out = {}
        if storage == "BANK" then for i = 1, slots do out[i] = { storage = "BANK", container = 6, slot = i } end end
        return out
    end,
    Read = function() return {} end,
}
local rendered = 0
B.Render = function() rendered = rendered + 1 end
B.bankOpen, B.bankStorage = true, "BANK"
B.bankWindow = { frame = { IsShown = function() return true end } }

local function RunTimers()
    local list = timers; timers = {}
    for _, fn in ipairs(list) do fn() end
end

B:Snapshot("BANK")
assert(B.snapshots.BANK.capacity == 0, "bank opens before its tabs are known")
B:WaitForBankSlots()
RunTimers(); RunTimers()
assert(B.snapshots.BANK.capacity == 0 and #timers == 1, "keeps looking while the bank is still empty")
slots = 98
RunTimers()
assert(B.snapshots.BANK.capacity == 98, "slots appear once the game knows them")
assert(#timers == 0, "stops looking once slots are there")

-- The tab events also re-read the open bank.
slots = 110
B:OnEvent("BAG_CONTAINER_UPDATE")
assert(B.snapshots.BANK.capacity == 110, "tab size change refreshes the bank")

-- A closed bank stops the retries.
B.snapshots.BANK = nil
slots = 0
B:WaitForBankSlots()
B.bankOpen = false
RunTimers()
assert(#timers == 0, "no retries after the bank closes")
print("PASS: bank waits for late bank-tab slots")


-- The Blizzard bank frame stays shown (the game only fills bank slots while it is on screen),
-- just invisible and shrunk; Manage restores it.
local CT = { Bags = {}, Num = function(v) return type(v) == "number" end, Str = function(v) return type(v) == "string" end }
assert(loadfile("Modules/Bags/Client.lua"))("Tempus", CT)
local UIParentStub = {}
local bank = { parent = "hidden", alpha = 1, scale = 1, shown = 0 }
function bank:GetParent() return self.parent end
function bank:SetParent(p) self.parent = p end
function bank:GetAlpha() return self.alpha end
function bank:SetAlpha(a) self.alpha = a end
function bank:GetScale() return self.scale end
function bank:SetScale(v) self.scale = v end
function bank:Show() self.shown = self.shown + 1 end
local client = CT.Bags.Client.New({ BankFrame = bank, UIParent = UIParentStub })
client:SuppressBank()
assert(bank.parent == UIParentStub and bank.alpha == 0 and bank.scale < 0.01, "kept on screen, invisible")
client:ShowBankManagement(true)
assert(bank.alpha == 1 and bank.scale == 1 and bank.shown == 1, "Manage shows it at full size")
client:ShowBankManagement(false)
assert(bank.alpha == 0 and bank.parent == UIParentStub, "closing manage hides it again, still parented to the screen")
print("PASS: Blizzard bank frame stays shown while ghosted")
