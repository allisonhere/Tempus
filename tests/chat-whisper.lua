-- Whisper alert: when it fires, what it shows, which sound, and secret values left alone.
-- Run: lua5.1 tests/chat-whisper.lua
issecretvalue = function(v) return v == "SECRET" end
local T = { Style = {}, Chat = { defaults = {} } }
assert(loadfile("Modules/Chat/Whisper.lua"))("Tempus", T)
local WA = T.Chat.Whisper
local d = T.Chat.defaults
assert(d.whisperAlert == true and d.whisperSound == "TELL" and d.whisperPoint, "defaults merged into chat")

local db = { whisperAlert = true, whisperCombat = true, whisperBattleNet = true }
assert(WA.ShouldAlert(db, "CHAT_MSG_WHISPER", false), "normal whisper alerts")
assert(WA.ShouldAlert(db, "CHAT_MSG_BN_WHISPER", true), "bnet in combat alerts")
db.whisperBattleNet = false
assert(not WA.ShouldAlert(db, "CHAT_MSG_BN_WHISPER", false), "bnet can be off")
db.whisperCombat = false
assert(not WA.ShouldAlert(db, "CHAT_MSG_WHISPER", true) and WA.ShouldAlert(db, "CHAT_MSG_WHISPER", false), "combat can be off")
db.whisperAlert = false
assert(not WA.ShouldAlert(db, "CHAT_MSG_WHISPER", false), "master switch")

assert(WA.Preview("|cffff0000|Hitem:1|h[Sword]|h|r for you") == "[Sword] for you", "preview is plain text")
assert(WA.Preview("SECRET") == nil, "secret message not shown")
assert(#WA.Preview(string.rep("a", 200)) == 90, "long message cut")

SOUNDKIT = { TELL_MESSAGE = 3081, RAID_WARNING = 8959 }
assert(WA.SoundKit("TELL") == 3081 and WA.SoundKit("NONE") == nil, "sound choice")
assert(WA.SoundKit("ALARM") == 12867, "fallback id when the kit name is missing")

assert(WA.SoundDue("Bob", 100) and not WA.SoundDue("Bob", 102) and WA.SoundDue("Bob", 105), "sound gap per sender")
assert(WA.SoundDue("Amy", 102), "other senders not held back")
print("PASS: whisper alert rules, preview, sounds and secret handling")
