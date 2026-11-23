-- Gear Advisor: how far to trust a score. Pure logic. The stat weights are community estimates, so a
-- scored result is at best Medium; it is never presented as exact.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local C = {}
GA.Confidence = C

-- in: { hasStats, legacy, roleWhy ("chosen", "form", "talents", "last form", "default"), unscored (count of
-- stats that changed but have no weight), age (days, may be nil), staleDays }.
-- Returns label ("Medium", "Low" or "Item level only") and the reasons, as short phrases.
function C.Of(a)
    if a.legacy then return "Item level only", { "item-level ranking" } end
    if not a.hasStats then return "Item level only", { "the game gave no stats to score" } end
    local reasons = { "weights are estimates" }
    local label = "Medium"
    if a.roleWhy == "default" then
        label = "Low"
        reasons[#reasons + 1] = "build is assumed"
    end
    if type(a.unscored) == "number" and a.unscored > 0 then
        label = "Low"
        reasons[#reasons + 1] = ("%d stat%s not scored"):format(a.unscored, a.unscored == 1 and "" or "s")
    end
    if type(a.age) == "number" and type(a.staleDays) == "number" and a.age > a.staleDays then
        label = "Low"
        reasons[#reasons + 1] = ("price is %d days old"):format(a.age)
    end
    return label, reasons
end
