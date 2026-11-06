-- Opt-in, position-only layout routing. Evaluate the current group, never a stale queued target.
local _, T = ...
local A = {}
T.AutoLayouts = A
T.defaults.autoLayouts = {enabled = false, paused = false, solo = "", party = "", raid = ""}
local states = setmetatable({}, {__mode = "k"})
local labels = {solo = "Solo", party = "Party", raid = "Raid"}
function A:Config()
    T.db.autoLayouts = T.db.autoLayouts or {}
    return T.db.autoLayouts
end
function A:Context()
    if IsInRaid and IsInRaid() then return "raid" end
    if IsInGroup and IsInGroup() then return "party" end
    return "solo"
end
local function State()
    if not T.db then return end
    if not states[T.db] then states[T.db] = {} end
    return states[T.db]
end
local function Refresh()
    if T.Options and T.Options.Refresh then T.Options:Refresh() end
end
function A:Status()
    local state = State()
    return state and state.status or "Automatic layouts are disabled."
end
function A:Schedule(delay)
    if self.scheduled then return end
    self.scheduled = true
    local function Run() self.scheduled = nil; self:Evaluate() end
    if C_Timer and C_Timer.After then C_Timer.After(delay or 0.1, Run)
    else self.scheduled = nil end
end
function A:ManualEdit()
    if self.applying or not T.db then return end
    local cfg, state = self:Config(), State()
    if not cfg.enabled or cfg.paused then return end
    local context = self:Context()
    state.context, state.name, state.seen, state.manual = context, cfg[context] or "", true, true
    state.status = "Manual layout kept for " .. labels[context] .. "; switching resumes when the group type changes."
    Refresh()
end
function A:Reapply()
    local state = State()
    if state then state.seen, state.manual = nil, nil end
    self:Schedule()
end
function A:PresetRenamed(from, name)
    if not T.db then return end
    local cfg, state = self:Config(), State()
    for context in pairs(labels) do if cfg[context] == from then cfg[context] = name end end
    if state.name == from then
        state.name = name
        if state.seen and not state.manual and state.context then state.status = "Active automatic layout: " .. labels[state.context] .. " / " .. name end
    end
    self:Schedule()
end
function A:PresetDeleted(name)
    if not T.db then return end
    local cfg = self:Config()
    for context in pairs(labels) do if cfg[context] == name then cfg[context] = "" end end
    self:Schedule()
end
function A:Evaluate()
    if not T.db or self.applying then return end
    local cfg, state = self:Config(), State()
    if not cfg.enabled or cfg.paused then
        state.seen, state.manual = nil, nil
        state.status = cfg.paused and "Automatic layouts are paused (manual override)." or "Automatic layouts are disabled."
        Refresh(); return
    end
    local context = self:Context()
    local name = cfg[context] or ""
    if state.seen and state.context == context and state.name == name then
        state.status = state.manual and ("Manual layout kept for " .. labels[context] .. "; switching resumes when the group type changes.")
            or (name == "" and ("No preset assigned for " .. labels[context] .. "; current positions kept.") or ("Active automatic layout: " .. labels[context] .. " / " .. name))
        Refresh(); return
    end
    if name == "" then
        state.context, state.name, state.seen, state.manual = context, name, true, nil
        state.status = "No preset assigned for " .. labels[context] .. "; current positions kept."
        Refresh(); return
    end
    if not T.Layouts:Store()[name] then
        state.status = "Preset missing for " .. labels[context] .. ": " .. name .. ". Choose another preset."
        Refresh(); return
    end
    local ready, reason = T.Layouts:CanEdit()
    if InCombatLockdown() then state.status = "Waiting for combat to end; target: " .. labels[context] .. " / " .. name
    elseif not T.db.locked then state.status = "Waiting until frames are locked; target: " .. labels[context] .. " / " .. name
    elseif T.Layouts.pending then state.status = "Waiting until the layout preview ends; target: " .. name
    elseif not ready then state.status = reason
    else
        self.applying = true
        local ok, err = T.Layouts:ApplySaved(name)
        self.applying = nil
        if ok then
            state.context, state.name, state.seen, state.manual = context, name, true, nil
            state.status = "Active automatic layout: " .. labels[context] .. " / " .. name
        else state.status = err end
        Refresh(); return
    end
    Refresh()
    if not InCombatLockdown() then self:Schedule(0.5) end
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function() A:Schedule() end)
