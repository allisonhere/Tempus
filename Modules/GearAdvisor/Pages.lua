-- Tempus UI: the Gear Reporter settings page, and the notice shown before a report is opened.
local _, T = ...

local DISCLAIMER = "Gear Reporter\n\nThis opens a text report for the Tempus author, to help improve Gear Advisor. It contains your class and level, "
    .. "the talents you have points in, the talent tree, and the stat names on your gear, with the names of a few items you wear or carry as examples.\n\n"
    .. "It contains no account, e-mail or password details. Nothing is sent unless you press Whisper or send the mail yourself, "
    .. "and whoever receives it sees your character's name. You can edit the text first."

function T:StartGearReport()
    T:Confirm(DISCLAIMER, function() T:ShowShare("gearreport") end, "I understand, continue")
end

T.GEAR_REPORT_DISCLAIMER = DISCLAIMER

T:RegisterPage("convenience", { key = "gearreport", label = "Gear Reporter", order = 4.15, build = function(p)
    p:Section("Gear Reporter", "Help improve Gear Advisor by sending the author a short report from your character: your class and level, your talent points and tree, and the stat names on your gear. Nothing is sent by itself. A notice explains what the report holds before you see it, and you copy it, whisper it or queue it as mail to the character for your faction.")
    p:Add(T.UI.W.Button("Share my gear data", function() T:StartGearReport() end, "Shows what the report contains, then opens it. Nothing is sent unless you press Whisper or send the mail yourself.", 200))
end })
