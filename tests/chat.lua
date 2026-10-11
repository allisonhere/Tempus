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

-- The filter passes secret and non-string text through unchanged.
Chat.db = { urls = true }
local filter
ChatFrame_AddMessageEventFilter = function(_, fn) filter = fn end
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
print("PASS: chat links and secret handling")
