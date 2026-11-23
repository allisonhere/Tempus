-- Tempus UI: the notice shown before the gear data report is opened (the button lives on the Gear Report page).
local _, T = ...

local DISCLAIMER = "Gear Reporter\n\nThis opens a text report for the Tempus author, to help improve Gear Advisor. It contains your class and level, "
    .. "the talents you have points in, the talent tree, and the stat names on your gear, with the names of a few items you wear or carry as examples.\n\n"
    .. "It contains no account, e-mail or password details. Nothing is sent unless you press Whisper or send the mail yourself, "
    .. "and whoever receives it sees your character's name. You can edit the text first."

function T:StartGearReport()
    T:Confirm(DISCLAIMER, function() T:ShowShare("gearreport") end, "I understand, continue")
end

T.GEAR_REPORT_DISCLAIMER = DISCLAIMER
