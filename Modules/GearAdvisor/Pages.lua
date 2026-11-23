-- Tempus UI: the notice shown before the gear data report is opened (the button lives on the Gear Report page).
local _, T = ...

local DISCLAIMER = "Gear Reporter\n\nThis opens a text report for the Tempus author, to help improve Gear Advisor. It contains your class and level, "
    .. "the talents you have points in, the talent tree, and the stat names on your gear, with the names of a few items you wear or carry as examples.\n\n"
    .. "It contains no account, e-mail or password details. If you continue, Tempus sends it in the background, as a few whispers to the "
    .. "Tempus author's character for your faction as soon as that character is online. Chat shows the whispers as they go, and whoever receives it sees your character's name. If that character is offline, Tempus checks again every 30 minutes while you are logged in."

function T:StartGearReport()
    T:Confirm(DISCLAIMER, function() if T.Market and T.Market.SendReport then T.Market:SendReport() end end, "I understand, send it")
end

T.GEAR_REPORT_DISCLAIMER = DISCLAIMER
