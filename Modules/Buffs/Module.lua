-- Tempus UI: the buffs module (the original Tempus buff timers).
local _, T = ...

T:NewModule("buffs", {
    label = "Buffs & Debuffs",
    desc = "Buff, debuff and weapon-enchant timers with bars, alerts, recasting and missing-buff reminders.",
    OnEnable = function()
        T.Display:Init()
        T:InitAlerts()
    end,
    OnSettings = function()
        T.Display:Rebuild()
    end,
})
