-- Chat module: links web addresses, leaves hyperlinks and secret lines alone, stores only plain text.
-- Run: lua5.1 tests/chat.lua
local T = { Style = {}, Num = function(v) return type(v) == "number" end, Wrap = function(_, _, fn) return fn end,
    NewModule = function() end, ReportError = function() end }
issecretvalue = function(v) return v == "SECRET" end
assert(loadfile("Modules/Chat/Chat.lua"))("Tempus", T)
local Chat = T.Chat

local L = Chat.Linkify
assert(L("hello world") == "hello world", "no address, no change")
assert(L("see https://example.com/a?b=1 now"):find("|Hurl:https://example.com/a?b=1|h", 1, true), "https linked")
assert(L("go to www.example.org."):find("|Hurl:www.example.org|h", 1, true), "www linked, trailing dot kept outside")
assert(L("go to www.example.org."):sub(-1) == ".", "trailing dot stays outside the link")
local link = "|cff71d5ff|Hitem:1234|h[https://notaurl.com]|h|r"
assert(L(link) == link, "existing hyperlinks are not touched")
assert(L("a |cffff0000https://x.io|r b"):find("|Hurl:https://x.io|h", 1, true), "colour reset is not swallowed")

assert(L("mail me at bob@example.com ok"):find("|Hurl:bob@example.com|h", 1, true), "email linked")
assert(L("check example.com/path."):find("|Hurl:example.com/path|h", 1, true), "bare domain linked")
assert(L("e.g. this and 3.5 stay") == "e.g. this and 3.5 stay", "abbreviations and numbers untouched")
assert(L("see https://x.io/a now"):find("|Hurl:https://x.io/a|h", 1, true) and not L("see https://x.io/a now"):find("|Hurl:x.io", 1, true), "full url not relinked")

-- The filter passes secret and non-string text through unchanged.
Chat.db = { urls = true }
local filter
local filters = {}
ChatFrame_AddMessageEventFilter = function(event, fn) filters[event] = fn; if event == "CHAT_MSG_SAY" then filter = fn end end
hooksecurefunc = function() end
local mod
T.NewModule = function(_, _, def) mod = def end
assert(loadfile("Modules/Chat/Chat.lua"))("Tempus", T)
T.db = { chat = { urls = true, copyButton = false, history = false, historyLines = 150, timestamps = "KEEP", fadeChrome = false } }
UnitName = function() return "Me" end
GetRealmName = function() return "R" end
C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
mod.OnEnable()
assert(filter, "filter registered")
local r1 = filter(nil, "CHAT_MSG_SAY", "SECRET", "Bob")
assert(r1 == false, "secret text not filtered")
local ok, text = filter(nil, "CHAT_MSG_SAY", "visit https://a.b/c", "Bob")
assert(ok == false and text:find("|Hurl:", 1, true), "plain text linked")
local _, sub = filter(nil, "CHAT_MSG_SAY", "see docs.google.com/a and mail a@b.com", "Bob")
assert(sub:find("|Hurl:docs.google.com/a|h", 1, true), "subdomain linked whole")
assert(sub:find("|Hurl:a@b.com|h", 1, true), "mail linked")

-- Select mode text: colours kept, link wrappers and textures dropped.
local K = Chat.CleanKeepColor
assert(K("|cffff0000|Hitem:1|h[Sword]|h|r |TInterface\\x:0|tok") == "|cffff0000[Sword]|r ok", "colour kept, link and texture stripped")

-- Battle.net names (|K codes) never reach an edit box: the game would blank the whole text.
local look = function(id) return id == "10" and "Sam" or nil end
local bn = "|HBNplayer:|Ks8|k:10:921:BN_WHISPER:|Ks8|k|h[|Ks8|k]|h whispers: hi"
assert(Chat.StripProtected(bn, look) == "|HBNplayer:|Ks8|k:10:921:BN_WHISPER:|Ks8|k|h[Sam]|h whispers: hi" or
    not Chat.StripProtected(bn, look):find("[|Ks8|k]", 1, true), "name inside the link replaced")
assert(Chat.StripProtected(bn, look):find("|h[Sam]|h whispers: hi", 1, true), "friend's name shown")
assert(K(bn) == "[friend] whispers: hi", "select text has no protected codes")
assert(not Chat.StripProtected("hello |Ks2|k there", look):find("|K", 1, true), "loose codes replaced too")
assert(Chat.StripProtected("|HBNplayer:|Ks9|k:99:1:BN_WHISPER:|Ks9|k|h[|Ks9|k]|h: yo", look):find("[friend]", 1, true), "unknown friend")

-- Lines: plain lines kept, secret lines counted, missing lines skipped.
local msgs = { "one", "SECRET", nil, "|Hplayer:Bob|h[Bob]|h hi" }
local cf = { GetNumMessages = function() return 4 end, GetMessageInfo = function(_, i) return msgs[i] end }
local lines, hidden = Chat.Lines(cf, K)
assert(#lines == 2 and lines[1] == "one" and lines[2] == "[Bob] hi" and hidden == 1, "lines and hidden count")

-- Read-only guard puts back user edits only.
local box = { tempusText = "keep", text = "keep!", GetText = function(self) return self.text end,
    SetText = function(self, t) self.text = t end }
Chat.GuardText(box, true); assert(box.text == "keep", "user edit undone")
box.text = "code"; Chat.GuardText(box, false); assert(box.text == "code", "code changes left alone")

-- The select box must never look like a chat input box, or spell checkers would hook it.
assert(not Chat.SELECT_BOX_NAME:find("^ChatFrame%d+EditBox$") and not Chat.SELECT_BOX_NAME:find("^WIM"))

-- Typing: only the alt-arrow switch is flipped; Blizzard's handlers are never replaced.
local calls = {}
local function EB(name)
    return { name = name, hooks = {},
        SetAltArrowKeyMode = function(self, v) calls[#calls + 1] = { self.name, v } end,
        HookScript = function(self, ev) self.hooks[ev] = true end,
        SetScript = function() error("SetScript on a chat edit box") end,
        SetPropagateKeyboardInput = function() error("propagation on a chat edit box") end }
end
NUM_CHAT_WINDOWS = 2
ChatFrame1EditBox, ChatFrame2EditBox = EB("1"), EB("2")
Chat.db = { editorKeys = true }
Chat:ApplyInput()
assert(#calls == 2 and calls[1][2] == false and calls[2][2] == false, "arrows move the cursor")
assert(ChatFrame1EditBox.hooks.OnShow and ChatFrame1EditBox.hooks.OnEditFocusGained, "reapplied when the box opens")
calls = {}
Chat.db.editorKeys = false
Chat:ApplyInput()
assert(#calls == 2 and calls[1][2] == true, "turning it off restores the game default")

-- Short channel names.
local SC = Chat.ShortChannel
assert(SC("2. Trade - City") == "T" and SC("1. General - Elwynn Forest") == "G", "known channels")
assert(SC("4. LookingForGroup") == "LFG" and SC("6. mychannel") == "6", "known and custom")
assert(SC("Community:123:1") == "Community:123:1" and SC("SECRET") == "SECRET", "community and secret untouched")
local cfilter = filters.CHAT_MSG_CHANNEL
assert(cfilter, "channel filter registered")
T.Chat.db = { shortChannels = true }
local r = { cfilter(nil, "CHAT_MSG_CHANNEL", "hi", "Bob", "", "2. Trade - City", "Bob", "", 0, 2, "Trade - City") }
assert(r[1] == false and r[2] == "hi" and r[5] == "T" and r[10] == "Trade - City", "only the label changes")
assert(cfilter(nil, "CHAT_MSG_CHANNEL", "hi", "Bob", "", "SECRET") == false and select("#", cfilter(nil, "CHAT_MSG_CHANNEL", "hi", "Bob", "", "SECRET")) == 1, "secret label passed through")
T.Chat.db.shortChannels = false
assert(select("#", cfilter(nil, "CHAT_MSG_CHANNEL", "hi", "Bob", "", "2. Trade")) == 1, "off means untouched")

-- Grey timestamps wrap and unwrap the game's format; the trailing space stays outside.
local SF = Chat.StampFormat
assert(SF("%H:%M:%S ", true) == "|cff6f7787%H:%M:%S|r ", "wrapped")
assert(SF(SF("%H:%M:%S ", true), true) == "|cff6f7787%H:%M:%S|r ", "wrapping twice is the same")
assert(SF("|cff6f7787%H:%M:%S|r ", false) == "%H:%M:%S ", "unwrapped")
assert(SF("none", true) == "none", "off stays off")
print("PASS: chat links, secret handling, select mode, editor keys, short channels and timestamps")
