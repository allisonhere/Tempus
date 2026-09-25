-- Tempus UI: core, saved settings, profiles, modules, time formatting and secret-value helpers.
local ADDON, T = ...
_G.Tempus = T

T.name = "Tempus"
T.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "1.0"
T.accent = { 0.25, 0.76, 1 }
T.accentHex = "3fc1ff"
T.LOGO = "Interface\\AddOns\\Tempus\\media\\icon"     -- round clock logo (media/icon.tga)

-- Accent colours on offer. T.accent is changed in place, so every file that holds a
-- reference to it sees the new colour; anything already drawn updates after /reload.
T.accents = {
    { "BLUE", "Tempus Blue", { 0.25, 0.76, 1 } },
    { "GREEN", "Emerald", { 0.3, 0.85, 0.45 } },
    { "PURPLE", "Amethyst", { 0.7, 0.47, 1 } },
    { "GOLD", "Gold", { 1, 0.78, 0.25 } },
    { "RED", "Crimson", { 1, 0.34, 0.34 } },
    { "PINK", "Rose", { 1, 0.47, 0.75 } },
}

function T:ApplyAccent()
    local key = T.db and T.db.accent or "BLUE"
    local c = T.accents[1][3]
    for _, a in ipairs(T.accents) do if a[1] == key then c = a[3] end end
    T.accent[1], T.accent[2], T.accent[3] = c[1], c[2], c[3]
    T.accentHex = ("%02x%02x%02x"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5)
end

----------------------------------------------------------------------------------------
-- Secret values. Forever can hand aura fields back as opaque "secret" values that can
-- be displayed (SetText, SetTexture) but not compared or computed with.
----------------------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
T.issecret = issecret

function T.Readable(v)
    return v ~= nil and not issecret(v)
end

function T.Num(v)
    return not issecret(v) and type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

function T.Str(v)
    return not issecret(v) and type(v) == "string" and v ~= ""
end

----------------------------------------------------------------------------------------
-- Defaults
----------------------------------------------------------------------------------------
local function Group(point, x, y, overrides)
    local g = {
        enabled = true,
        style = "ICONS",        -- ICONS | BARS
        size = 34,
        spacing = 5,
        perRow = 12,
        rows = 3,
        growX = "LEFT",         -- LEFT | RIGHT
        growY = "DOWN",         -- DOWN | UP
        barWidth = 200,
        barHeight = 20,
        barIcon = "LEFT",       -- LEFT | RIGHT | NONE
        barColor = "TIME",      -- TIME | CUSTOM | CLASS | TYPE
        scale = 1,
        alpha = 1,
        sort = "TIME",          -- TIME | NAME | INDEX
        reverse = false,
        permanent = "LAST",     -- FIRST | LAST | HIDE
        timer = "BOTTOM",       -- BOTTOM | TOP | CENTER | NONE
        showName = true,
        onlyMine = false,
        point = { point, "UIParent", point, x, y },
    }
    for k, v in pairs(overrides or {}) do g[k] = v end
    return g
end

T.defaults = {
    locked = true,
    hideBlizzard = true,
    theme = "MODERN",           -- MODERN | GLOSS | CLASSIC | FLAT
    accent = "BLUE",            -- key from T.accents
    borderSize = 1,
    iconZoom = 0.08,
    font = "Fonts\\FRIZQT__.TTF",
    fontOutline = "OUTLINE",
    timerFontSize = 11,
    countFontSize = 13,
    nameFontSize = 11,
    barTexture = "SMOOTH",
    timerFormat = "SMART",      -- SMART | CLOCK | LONG
    decimals = 3,
    colorTimers = true,
    soonAt = 60,
    urgentAt = 10,
    pulse = true,
    pulseAt = 8,
    swipe = true,
    swipeAlpha = 0.55,
    tooltips = true,
    rightClickCancel = true,
    clickToRecast = true,
    clickThrough = false,
    mergeWeapons = false,
    colors = {
        normal    = { 1, 1, 1 },
        soon      = { 1, 0.82, 0.1 },
        urgent    = { 1, 0.27, 0.2 },
        border    = { 0.06, 0.06, 0.07 },
        important = { 1, 0.78, 0.2 },
        buffBar   = { 0.25, 0.62, 1 },
        debuffBar = { 0.85, 0.18, 0.18 },
        weaponBar = { 0.72, 0.42, 1 },
        barBg     = { 0.06, 0.07, 0.09 },
    },
    alerts = {
        expired = true,
        warn = true,
        warnAt = 30,
        minDuration = 120,
        sound = true,
        soundKit = 8959,
        chat = false,
    },
    watchHideInCombat = false,
    watchOnlyResting = false,
    lists = { hidden = {}, important = {}, watch = {}, casts = {} },
    groups = {
        buffs   = Group("TOPRIGHT", -205, -13),
        debuffs = Group("TOPRIGHT", -205, -150, { size = 40, perRow = 8, rows = 2, barColor = "TYPE" }),
        weapons = Group("TOPRIGHT", -205, -225, { perRow = 2, rows = 1, barColor = "CUSTOM", permanent = "LAST" }),
        watch   = Group("CENTER", 0, 170, { size = 38, perRow = 8, rows = 1, growX = "RIGHT", timer = "BOTTOM", sort = "NAME" }),
    },
    minimap = { hide = false, angle = 215 },
}

----------------------------------------------------------------------------------------
-- Profiles
----------------------------------------------------------------------------------------
local function CopyTable(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = CopyTable(v) end
    return t
end
T.CopyTable = CopyTable

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            -- Lists and positions are user data; only seed them when absent.
            if k ~= "hidden" and k ~= "important" and k ~= "watch" or next(dst[k]) == nil and next(v) ~= nil then
                Merge(dst[k], v)
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

function T:ProfileName()
    return TempusDB.chars[CharKey()] or "Default"
end

function T:SetProfile(name)
    TempusDB.profiles[name] = TempusDB.profiles[name] or {}
    TempusDB.chars[CharKey()] = name
    Merge(TempusDB.profiles[name], T.defaults)
    T.db = TempusDB.profiles[name]
    T:ApplySettings()
end

function T:CopyProfile(from)
    local src = TempusDB.profiles[from]
    if not src then return end
    local name = T:ProfileName()
    TempusDB.profiles[name] = CopyTable(src)
    T:SetProfile(name)
end

function T:ResetProfile()
    local name = T:ProfileName()
    TempusDB.profiles[name] = {}
    T:SetProfile(name)
end

function T:DeleteProfile(name)
    if name == T:ProfileName() or name == "Default" then return end
    TempusDB.profiles[name] = nil
    for char, prof in pairs(TempusDB.chars) do
        if prof == name then TempusDB.chars[char] = nil end
    end
end

function T:ProfileList()
    local list = {}
    for name in pairs(TempusDB.profiles) do list[#list + 1] = name end
    table.sort(list)
    return list
end

----------------------------------------------------------------------------------------
-- Name lists (hidden / important / watch). Keys are lowercase names or spell IDs.
----------------------------------------------------------------------------------------
function T:ListHas(list, name, spellId)
    local l = T.db.lists[list]
    if spellId and l[tostring(spellId)] then return true end
    if T.Str(name) and l[name:lower()] then return true end
    return false
end

function T:ListAdd(list, text)
    text = text and strtrim(text)
    if not text or text == "" then return end
    T.db.lists[list][text:lower()] = text
    T:ApplySettings()
end

function T:ListRemove(list, key)
    if key == nil then return end
    T.db.lists[list][key] = nil
    T:ApplySettings()
end

----------------------------------------------------------------------------------------
-- Time formatting (readable path)
----------------------------------------------------------------------------------------
local floor, ceil = math.floor, math.ceil

function T.FormatTime(s)
    local db = T.db
    if s <= 0 then return "" end
    local fmt = db.timerFormat
    if db.decimals > 0 and s < db.decimals then
        return ("%.1f"):format(s)
    end
    if fmt == "CLOCK" then
        s = ceil(s)
        if s >= 3600 then return ("%d:%02d:%02d"):format(floor(s / 3600), floor(s % 3600 / 60), s % 60) end
        return ("%d:%02d"):format(floor(s / 60), s % 60)
    elseif fmt == "LONG" then
        s = ceil(s)
        if s >= 3600 then return ("%dh %02dm"):format(floor(s / 3600), floor(s % 3600 / 60)) end
        if s >= 60 then return ("%dm %02ds"):format(floor(s / 60), s % 60) end
        return ("%ds"):format(s)
    end
    -- SMART
    if s >= 3600 then return ("%dh"):format(floor(s / 3600 + 0.5)) end
    if s >= 90 then return ("%dm"):format(ceil(s / 60)) end
    if s >= 60 then return ("%d:%02d"):format(floor(s / 60), ceil(s) % 60) end
    return ("%d"):format(ceil(s))
end

function T.TimeColor(s)
    local c = T.db.colors
    if not T.db.colorTimers or not s then return c.normal end
    if s <= T.db.urgentAt then return c.urgent end
    if s <= T.db.soonAt then return c.soon end
    return c.normal
end

----------------------------------------------------------------------------------------
-- Native (secret-safe) formatters: the client formats the remaining time itself.
----------------------------------------------------------------------------------------
function T:BuildNativeFormatters()
    T.nativeFormatter, T.nativeColorCurve, T.nativeBarCurve = nil, nil, nil
    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
        local ok, fmt = pcall(function()
            local db = T.db
            local f = C_StringUtil.CreateNumericRuleFormatter()
            local up = Enum and Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Up
            local bp = {}
            local function add(t) bp[#bp + 1] = t end
            if db.decimals > 0 then
                add({ threshold = 0.01, step = 0.1, format = "%.1f" })
                add({ threshold = db.decimals, step = 1, rounding = up, format = "%d" })
            else
                add({ threshold = 0.01, step = 1, rounding = up, format = "%d" })
            end
            if db.timerFormat == "CLOCK" then
                add({ threshold = 60, format = "%d:%02d", components = { { div = 60 }, { mod = 60 } } })
                add({ threshold = 3600, format = "%dh", components = { { div = 3600, step = 1 } } })
            elseif db.timerFormat == "LONG" then
                bp[#bp].format = "%ds"
                add({ threshold = 60, format = "%dm %02ds", components = { { div = 60 }, { mod = 60 } } })
                add({ threshold = 3600, format = "%dh", components = { { div = 3600, step = 1 } } })
            else
                add({ threshold = 60, format = "%d:%02d", components = { { div = 60 }, { mod = 60 } } })
                add({ threshold = 90, format = "%dm", components = { { div = 60, step = 1, rounding = up } } })
                add({ threshold = 3600, format = "%dh", components = { { div = 3600, step = 1 } } })
            end
            if f.SetBreakpoints then f:SetBreakpoints(bp) else for _, b in ipairs(bp) do f:AddBreakpoint(b) end end
            return f
        end)
        if ok then T.nativeFormatter = fmt end
    end
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType then
        local ok, curve = pcall(function()
            local c = T.db.colors
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            if T.db.colorTimers then
                curve:AddPoint(0, CreateColor(c.urgent[1], c.urgent[2], c.urgent[3], 1))
                curve:AddPoint(T.db.urgentAt, CreateColor(c.soon[1], c.soon[2], c.soon[3], 1))
                curve:AddPoint(T.db.soonAt, CreateColor(c.normal[1], c.normal[2], c.normal[3], 1))
            else
                curve:AddPoint(0, CreateColor(c.normal[1], c.normal[2], c.normal[3], 1))
            end
            return curve
        end)
        if ok then T.nativeColorCurve = curve end
        ok, curve = pcall(function()
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Linear)
            curve:AddPoint(0, CreateColor(0.95, 0.2, 0.15, 1))
            curve:AddPoint(0.5, CreateColor(1, 0.8, 0.1, 1))
            curve:AddPoint(1, CreateColor(0.2, 0.85, 0.35, 1))
            return curve
        end)
        if ok then T.nativeBarCurve = curve end
    end
end

-- Remaining-fraction color for "TIME" bars: green -> yellow -> red.
function T.GradientColor(p)
    if p > 0.5 then
        local f = (p - 0.5) * 2
        return 1 - 0.8 * f, 0.8 + 0.05 * f, 0.1 + 0.25 * f
    end
    local f = p * 2
    return 0.95 + 0.05 * f, 0.2 + 0.6 * f, 0.15 - 0.05 * f
end

----------------------------------------------------------------------------------------
-- Messages
----------------------------------------------------------------------------------------
function T:Print(msg, ...)
    print(("|cff%sTempus|r: " .. msg):format(T.accentHex, ...))
end

----------------------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------------------
T.modules, T.moduleOrder = {}, {}

-- A module is a table with optional: label, desc, defaults (merged into T.db[key]),
-- OnEnable() once at login when enabled, OnSettings() after any settings change.
-- Enabling or disabling a module takes effect after /reload, as in ElvUI.
function T:NewModule(key, def)
    def.key = key
    T.modules[key] = def
    T.moduleOrder[#T.moduleOrder + 1] = key
    if def.defaults then T.defaults[key] = def.defaults end
    T.defaults.modules = T.defaults.modules or {}
    T.defaults.modules[key] = def.enabledByDefault ~= false
    return def
end

function T:ModuleEnabled(key)
    return T.db and T.db.modules and T.db.modules[key] ~= false
end

-- Settings pages contributed by modules, shown in sidebar sections.
T.pageSections = {
    { key = "general", label = "General" },
    { key = "buffs", label = "Buffs & Debuffs" },
    { key = "unitframes", label = "Unit Frames" },
    { key = "nameplates", label = "Nameplates" },
    { key = "groupframes", label = "Party & Raid" },
    { key = "actionbars", label = "Action Bars" },
    { key = "minimap", label = "Minimap & Info Bar" },
    { key = "skins", label = "Skins" },
}
T.pages = {}
function T:RegisterPage(section, def)
    def.section = section
    T.pages[#T.pages + 1] = def
end

-- Secure frames cannot be changed in combat: run now, or as soon as combat ends.
-- A key replaces an earlier queued job with the same key.
local oocQueue, oocOrder = {}, {}
function T:RunOOC(fn, key)
    if not InCombatLockdown() then
        local ok, err = pcall(fn)
        if not ok and T.ReportError then T:ReportError(err) end
        return
    end
    key = key or (#oocOrder + 1)
    if not oocQueue[key] then oocOrder[#oocOrder + 1] = key end
    oocQueue[key] = fn
end

function T:ReportError(err)
    if TempusDB then
        TempusDB.debug = TempusDB.debug or {}
        TempusDB.debug.lastError = { err = tostring(err), combat = InCombatLockdown(), at = date("%H:%M:%S") }
    end
    if not T.errorShown then
        T.errorShown = true
        T:Print("|cffff5050error:|r %s", tostring(err))
    end
end

local function EachModule(method)
    for _, key in ipairs(T.moduleOrder) do
        local m = T.modules[key]
        if m[method] and T:ModuleEnabled(key) and (method == "OnEnable" or m.enabled) then
            local ok, err = pcall(m[method], m)
            if not ok then T:ReportError(key .. ": " .. tostring(err)) end
            if method == "OnEnable" then m.enabled = ok end
        end
    end
end

function T:ApplySettings()
    if not T.db then return end
    T:ApplyAccent()
    T:BuildNativeFormatters()
    EachModule("OnSettings")
    if T.Movers then T.Movers:Refresh() end
    if T.Options and T.Options.Refresh then T.Options:Refresh() end
    if T.UpdateMinimapButton then T:UpdateMinimapButton() end
end

----------------------------------------------------------------------------------------
-- Diagnostics: Lua warnings, errors from any addon, and blocked-action messages, kept in
-- TempusDB.debug.log so they can be read after a reload. Shown with /tempus log.
----------------------------------------------------------------------------------------
-- Lightweight profiler: T:Wrap(name, fn) times every call; /tempus perf reports it.
T.perf, T.perfSince = {}, 0
local clock = debugprofilestop or function() return GetTime() * 1000 end
function T:Wrap(name, fn)
    return function(...)
        local t0 = clock()
        local a, b, c, d = fn(...)
        local dt = clock() - t0
        local p = T.perf[name]
        if not p then p = { ms = 0, calls = 0, max = 0 }; T.perf[name] = p end
        p.ms, p.calls = p.ms + dt, p.calls + 1
        if dt > p.max then p.max = dt end
        return a, b, c, d
    end
end

-- Per-addon CPU via the game's script profiler (needs the scriptProfile CVar + reload).
function T:CPUCommand(arg)
    local getCVar = C_CVar and C_CVar.GetCVar or GetCVar
    local setCVar = C_CVar and C_CVar.SetCVar or SetCVar
    if not (GetAddOnCPUUsage and UpdateAddOnCPUUsage and ResetCPUUsage) then
        T:Print("this client has no per-addon CPU profiling.")
        return
    end
    if arg == "off" then
        setCVar("scriptProfile", "0")
        T:Print("CPU profiling will be off after /reload.")
        return
    end
    if getCVar("scriptProfile") ~= "1" then
        setCVar("scriptProfile", "1")
        T:Print("CPU profiling switched on. |cff%s/reload|r, play normally, then |cff%s/tempus cpu|r again.", T.accentHex, T.accentHex)
        return
    end
    local secs = tonumber(arg) or 30
    ResetCPUUsage()
    local fps0 = GetFramerate()
    T:Print("measuring every addon for %d seconds - play normally...", secs)
    C_Timer.After(secs, function()
        UpdateAddOnCPUUsage()
        local num = (C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns)()
        local rows, total = {}, 0
        for i = 1, num do
            local ms = GetAddOnCPUUsage(i)
            if T.Num(ms) and ms > 0 then
                local name = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(i)
                rows[#rows + 1] = { name, ms / secs }
                total = total + ms
            end
        end
        table.sort(rows, function(a, b) return a[2] > b[2] end)
        local fps = GetFramerate()
        T:Print("addon CPU over %ds at ~%.0f fps: all addons %.1f ms/s (%.1f%% of the time).", secs, fps, total / secs, total / secs / 10)
        for i = 1, math.min(10, #rows) do T:Print("  %-24s %7.2f ms/s", rows[i][1], rows[i][2]) end
        T:Print("turn profiling off afterwards with |cff%s/tempus cpu off|r and /reload.", T.accentHex)
        TempusDB.cpu = { at = date("%H:%M:%S"), secs = secs, fps = fps, fps0 = fps0, total = total / secs, rows = rows }
    end)
end

function T:PerfReport()
    local secs = math.max(GetTime() - T.perfSince, 0.001)
    local rows, total = {}, 0
    for name, p in pairs(T.perf) do
        rows[#rows + 1] = { name, p.ms / secs, p.calls / secs, p.max }
        total = total + p.ms
    end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    T:Print("perf over %.0fs - %.0f fps. Tempus total %.2f ms per second (%.2f%% of a frame budget).",
        secs, GetFramerate(), total / secs, total / secs / 10)
    for i = 1, math.min(12, #rows) do
        local r = rows[i]
        T:Print("  %-26s %6.2f ms/s  %5.1f calls/s  worst %.2f ms", r[1], r[2], r[3], r[4])
    end
    TempusDB.perf = { at = date("%H:%M:%S"), secs = secs, fps = GetFramerate(), rows = rows }
end

T.log = {}
function T:Log(kind, msg)
    msg = tostring(msg):gsub("\n.*", ""):sub(1, 300)
    for _, e in ipairs(T.log) do
        if e.msg == msg then e.count = e.count + 1 return end
    end
    if #T.log >= 40 then table.remove(T.log, 1) end
    T.log[#T.log + 1] = { kind = kind, msg = msg, count = 1, at = date("%H:%M:%S") }
end

do
    local diag = CreateFrame("Frame")
    for _, e in ipairs({ "LUA_WARNING", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MACRO_ACTION_BLOCKED" }) do
        pcall(diag.RegisterEvent, diag, e)
    end
    diag:SetScript("OnEvent", function(_, event, a1, a2)
        if event == "LUA_WARNING" then
            T:Log("warning", a2 or a1)
        else
            T:Log("blocked", ("%s: %s called %s"):format(event, tostring(a1), tostring(a2)))
        end
    end)
    local previous = geterrorhandler and geterrorhandler()
    if seterrorhandler and previous then
        seterrorhandler(function(msg, ...)
            if T.quietErrors then
                T.quietErrors[#T.quietErrors + 1] = tostring(msg):sub(1, 200)
                return
            end
            pcall(function()
                T:Log("error", msg)
                -- Keep a short stack with the first occurrence so the source can be traced.
                local last = T.log[#T.log]
                if last and last.msg == tostring(msg):gsub("\n.*", ""):sub(1, 300) and not last.stack and debugstack then
                    last.stack = debugstack(3, 8, 0):sub(1, 900)
                end
            end)
            return previous(msg, ...)
        end)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        TempusDB = TempusDB or {}
        TempusDB.profiles = TempusDB.profiles or {}
        TempusDB.chars = TempusDB.chars or {}
        TempusDB.debug = { log = T.log }       -- fresh diagnostics every session
        TempusDB.tabdump = nil                  -- one-off spellbook tab dump, no longer used
    elseif event == "PLAYER_LOGIN" then
        T.perfSince = GetTime()     -- the profiler's window starts at login, not client launch
        local name = T:ProfileName()
        TempusDB.profiles[name] = TempusDB.profiles[name] or {}
        Merge(TempusDB.profiles[name], T.defaults)
        T.db = TempusDB.profiles[name]
        T:ApplyAccent()             -- before any module draws
        T:BuildNativeFormatters()
        EachModule("OnEnable")
        if T.Movers then T.Movers:Refresh() end
        T:InitMinimapButton()
        T.Options:InitBlizzardPanel()
        T:Print("loaded. Type |cff%s/tempus|r to configure.", T.accentHex)
    elseif event == "PLAYER_REGEN_ENABLED" then
        local order = oocOrder
        oocOrder = {}
        for _, key in ipairs(order) do
            local fn = oocQueue[key]
            oocQueue[key] = nil
            if fn then
                local ok, err = pcall(fn)
                if not ok then T:ReportError(err) end
            end
        end
    end
end)

----------------------------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------------------------
SLASH_TEMPUS1, SLASH_TEMPUS2 = "/tempus", "/bt"
local fullMsg
SlashCmdList.TEMPUS = function(msg)
    fullMsg = msg
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "lock" then
        T.db.locked = true; T:ApplySettings(); T:Print("frames locked.")
    elseif msg == "unlock" or msg == "move" then
        T.db.locked = false; T:ApplySettings(); T:Print("frames unlocked. Drag the boxes, then |cff%s/tempus lock|r.", T.accentHex)
    elseif msg == "test" then
        if T.Display then
            T.Display:SetTestMode(not T.Display.testMode)
            T:Print("test mode %s.", T.Display.testMode and "on" or "off")
        end
    elseif msg == "reset" then
        T:ResetProfile(); T:Print("profile reset.")
    elseif msg == "fpstest" or msg == "fps" then
        T:FPSTest()
    elseif msg == "cpu" then
        T:CPUCommand((fullMsg or ""):lower():match("^%s*cpu%s+(%S+)"))
    elseif msg == "perf" then
        T:PerfReport()
        T.perf, T.perfSince = {}, GetTime()
    elseif msg == "log" then
        if #T.log == 0 then T:Print("no warnings or errors this session.") end
        for _, e in ipairs(T.log) do
            T:Print("|cff888888%s|r [%s]%s %s", e.at, e.kind, e.count > 1 and (" x" .. e.count) or "", e.msg)
        end
    elseif msg == "skinreport" then
        if T.Skins and T.Skins.Report then T.Skins:Report() else T:Print("the Skins module is off.") end
    elseif msg == "install" or msg == "setup" then
        T.Installer:Open()
    elseif msg == "safe" then
        -- Escape hatch: turn every module except buffs off and reload.
        for key in pairs(T.modules) do
            if key ~= "buffs" then T.db.modules[key] = false end
        end
        ReloadUI()
    elseif msg == "probe" and (fullMsg or ""):lower():match("^%s*probe%s+group") then
        if T:RunGroupProbe() then
            T:Print("group probe recorded. Now pull something with your group; a combat sample is taken automatically.")
        else
            T:Print("group probe: join a party or raid first, then run it again.")
        end
    elseif msg == "probe" and (fullMsg or ""):lower():match("^%s*probe%s+off") then
        if TempusDB.probe then TempusDB.probe = nil end
        T:Print("probe data cleared and login probing off.")
    elseif msg == "probe" then
        T:RunProbe(InCombatLockdown() and "combat" or "idle")
        TempusDB.probe.enabled = true   -- also record paging facts at future logins
        T:Print("probe recorded. /reload so it is saved to disk.")
    elseif msg == "debug" then
        local log = TempusDB.debug or {}
        for _, state in ipairs({ "idle", "combat" }) do
            for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
                local r = log[state] and log[state][filter]
                T:Print("%s %s: %s", state, filter, r and ("%d via %s%s"):format(r.count, r.path, r.err and (" |cffff5050" .. r.err .. "|r") or "") or "not seen yet")
            end
        end
        if log.lastError then T:Print("last error (%s): %s", log.lastError.combat and "combat" or "idle", log.lastError.err:match("^[^\n]*")) end
    elseif msg == "help" then
        T:Print("/tempus [lock | unlock | test | install | reset | debug | probe | safe] - no argument opens settings. 'safe' turns off everything but buffs and reloads.")
    else
        T.Options:Toggle()
    end
end
