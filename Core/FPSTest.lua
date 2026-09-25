-- Tempus UI: /tempus fpstest - finds which Tempus element costs frame rate by hiding
-- each one for a few seconds and measuring. Rendering cost does not show in Lua
-- profiling, so this measures what actually matters: frames per second.
local _, T = ...

local SETTLE, SAMPLE = 1.5, 3       -- seconds to settle, seconds to average

-- Each candidate returns a list of frames to hide for its phase.
local function Candidates()
    local list = {}
    local function Add(name, frames)
        local shown = {}
        for _, f in ipairs(frames) do
            if f and f.IsShown and f:IsShown() then shown[#shown + 1] = f end
        end
        if #shown > 0 then list[#list + 1] = { name = name, frames = shown } end
    end
    local UF = T.UnitFrames
    if UF and UF.frames then
        local models, frames = {}, {}
        for _, f in pairs(UF.frames) do
            if f.model then models[#models + 1] = f.model end
            frames[#frames + 1] = f
        end
        Add("3D portraits", models)
        Add("Unit frames (all)", frames)
    end
    local AB = T.ActionBars
    if AB and AB.bars then
        local bars = {}
        for _, b in pairs(AB.bars) do bars[#bars + 1] = b end
        Add("Action bars", bars)
    end
    if T.Minimap and T.Minimap.holder then Add("Minimap", { T.Minimap.holder }) end
    if T.Display and T.Display.groups then
        local g = {}
        for _, grp in pairs(T.Display.groups) do g[#g + 1] = grp.frame end
        Add("Buff & debuff groups", g)
    end
    if T.DataBar and T.DataBar.bar then Add("Info bar", { T.DataBar.bar }) end
    if T.StatusBars and T.StatusBars.bars then
        local b = {}
        for _, f in pairs(T.StatusBars.bars) do b[#b + 1] = f end
        Add("XP & reputation bars", b)
    end
    local tr = _G.ObjectiveTrackerFrame
    if tr and tr.tempusPanel then Add("Quest tracker panel", { tr.tempusPanel }) end
    return list
end

local running

local function Measure(done)
    local sum, n, t = 0, 0, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, elapsed)
        t = t + elapsed
        if t < SETTLE then return end
        sum, n = sum + GetFramerate(), n + 1
        if t >= SETTLE + SAMPLE then
            self:SetScript("OnUpdate", nil)
            done(n > 0 and sum / n or 0)
        end
    end)
end

function T:FPSTest()
    if running then T:Print("fps test already running.") return end
    if InCombatLockdown() then T:Print("run the fps test out of combat.") return end
    local phases = Candidates()
    if #phases == 0 then T:Print("nothing to test.") return end
    running = true
    local results = {}
    local all = { name = "ALL Tempus elements", frames = {} }
    for _, p in ipairs(phases) do for _, f in ipairs(p.frames) do all.frames[#all.frames + 1] = f end end
    phases[#phases + 1] = all
    T:Print("fps test: about %d seconds. Stand still and don't touch the camera.", math.ceil((#phases + 1) * (SETTLE + SAMPLE)))

    local baseline
    local i = 0
    local function Next()
        i = i + 1
        local p = phases[i]
        if not p then
            running = false
            table.sort(results, function(a, b) return a.gain > b.gain end)
            T:Print("baseline %.0f fps. Hiding each element:", baseline)
            for _, r in ipairs(results) do
                T:Print("  %-24s %5.0f fps  (%+.0f)", r.name, r.fps, r.gain)
            end
            TempusDB.fpstest = { at = date("%H:%M:%S"), baseline = baseline, results = results }
            return
        end
        if InCombatLockdown() then running = false T:Print("fps test stopped: combat.") return end
        for _, f in ipairs(p.frames) do f:Hide() end
        Measure(function(fps)
            for _, f in ipairs(p.frames) do if not InCombatLockdown() or not f:IsProtected() then f:Show() end end
            results[#results + 1] = { name = p.name, fps = fps, gain = fps - baseline }
            Next()
        end)
    end
    Measure(function(fps)
        baseline = fps
        Next()
    end)
end
