local unpack = unpack or table.unpack
local function font(color, flags)
    return {
        color = color, flags = flags or '', shadow = {0, 0, 0, 1},
        GetObjectType = function() return 'FontString' end,
        GetTextColor = function(self) return unpack(self.color) end,
        SetTextColor = function(self, ...) self.color = {...} end,
        SetShadowColor = function(self, ...) self.shadow = {...} end,
        SetShadowOffset = function() end,
        GetFont = function(self) return 'font.ttf', 12, self.flags end,
        SetFont = function(self, _, _, flags) self.flags = flags end,
        CopyFontObject = function(self, other)
            self.color = {unpack(other.color)}
            self.flags = other.flags
        end,
    }
end
function CreateFont() return font({1, 1, 1}) end
local function frame(regions, children)
    return {
        GetRegions = function() return unpack(regions or {}) end,
        GetChildren = function() return unpack(children or {}) end,
        IsShown = function() return true end,
    }
end
local T = {Style = {C = {}}, Num = function(n) return type(n) == 'number' end, NewModule = function() end}
assert(loadfile('Modules/Skins/Skins.lua'))('Tempus', T)
local money = font({0, 0, 0}, 'OUTLINE')
local xp = font({0, 0, 0}, 'THICKOUTLINE,MONOCHROME')
local white = font({1, 1, 1}, 'OUTLINE')
local quality = font({0, 0.44, 0.87}, 'OUTLINE')
local boxed = font({1, 1, 1}, 'OUTLINE')
local box = frame({boxed})
box.tempusSkinPanel = {}
local original = font({0, 0, 0}, 'OUTLINE')
local button = frame()
button.GetObjectType = function() return 'Button' end
button.GetNormalFontObject = function(self) return self.normal end
button.SetNormalFontObject = function(self, value) self.normal = value end
button.normal = original
QuestFrame = frame({money, xp, white, quality}, {box, button})
local SK = T.Skins
SK.db = {windows = true, parchment = true}
SK.parchmentWindows = {QuestFrame = true}
SK:BrightenText()
assert(money.flags == '' and money.shadow[4] == 0 and money.color[1] == 0, 'money must be clean dark ink')
assert(xp.flags == 'MONOCHROME' and xp.shadow[4] == 0, 'XP must retain monochrome without outline')
assert(white.color[1] == 0.24 and white.shadow[4] == 0 and white.flags == '', 'light text must become clean ink')
assert(quality.color[2] == 0.44 and quality.color[3] == 0.87, 'quality color must be preserved')
assert(boxed.flags == 'OUTLINE' and boxed.shadow[4] == 1 and boxed.color[1] == 1, 'boxed text must stay unchanged')
assert(button.normal ~= original and button.normal.flags == '' and button.normal.shadow[4] == 0, 'button font must use clean clone')
assert(original.flags == 'OUTLINE' and original.shadow[4] == 1, 'shared Blizzard font must stay unchanged')
local clone = button.normal
SK:BrightenText()
assert(button.normal == clone, 'repeated styling must reuse clone')
SK.db.parchment = false
SK:BrightenText()
assert(money.color[1] == 0.9 and money.shadow[4] == 1, 'dark panels must still brighten text')
print('PASS: reward ink, outline flags, colors, boxed text, font clones, repeat styling, dark panels')
