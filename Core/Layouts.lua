-- Position-only presets. Snapshots are detached from live settings and scoped to a profile.
local _, T = ...
local L = {}
T.Layouts = L
local function Copy(v)
    if type(v) ~= "table" then return v end
    local out = {}; for k, value in pairs(v) do out[k] = Copy(value) end
    return out
end
local function Walk(node, visit, path)
    path = path or {}
    for key, value in pairs(node) do
        if key ~= "layoutPresets" and type(value) == "table" then
            local nextPath = Copy(path); nextPath[#nextPath + 1] = key
            if type(value.point) == "table" then visit(value, nextPath) end
            Walk(value, visit, nextPath)
        end
    end
end
local function Resolve(root, path)
    for _, key in ipairs(path) do
        if type(root) ~= "table" then return end
        root = root[key]
    end
    return root
end
function L:Capture(root)
    local snapshot = {}
    Walk(root or T.db, function(cfg, path)
        snapshot[#snapshot + 1] = {path = path, point = Copy(cfg.point)}
    end)
    return snapshot
end
-- History stays in memory, outside SavedVariables. Each profile owns up to 50 edits.
local histories = setmetatable({}, {__mode = "k"})
local function PointEqual(a, b)
    if a == nil or b == nil then return a == b end
    for i = 1, 5 do if a[i] ~= b[i] then return false end end
    return true
end
local function PathKey(path)
    local parts = {}
    for _, key in ipairs(path) do
        local value = tostring(key)
        parts[#parts + 1] = type(key) .. #value .. ":" .. value
    end
    return table.concat(parts, "/")
end
local function Changes(before, after)
    local old, new, changes = {}, {}, {}
    for _, entry in ipairs(before) do old[PathKey(entry.path)] = entry end
    for _, entry in ipairs(after) do new[PathKey(entry.path)] = entry end
    local function Add(key, entry)
        local a, b = old[key], new[key]
        local from, to = a and a.point, b and b.point
        if not PointEqual(from, to) then
            changes[#changes + 1] = {path = Copy(entry.path), before = Copy(from), after = Copy(to)}
        end
    end
    for key, entry in pairs(old) do Add(key, entry) end
    for key, entry in pairs(new) do if not old[key] then Add(key, entry) end end
    return changes
end
local function History()
    if not T.db then return end
    local h = histories[T.db]
    if not h then h = {undo = {}, redo = {}}; histories[T.db] = h end
    return h
end
local function Notify()
    if T.Movers.RefreshHistory then T.Movers:RefreshHistory() end
    if T.Options and T.Options.Refresh then T.Options:Refresh() end
end
function L:CanEdit()
    if not T.db then return false, "Layout settings are not ready." end
    if InCombatLockdown() then return false, "Leave combat before changing frame positions." end
    for _, mover in ipairs(T.Movers.list) do
        if mover.moving or mover.sizing or mover.pendingMove then return false, "Finish dragging or resizing first." end
    end
    return true
end
function L:CanUndo()
    local h = History()
    return h ~= nil and #h.undo > 0 and self:CanEdit() == true
end
function L:CanRedo()
    local h = History()
    return h ~= nil and #h.redo > 0 and self:CanEdit() == true
end
function L:BeginEdit()
    if not T.db or self.replaying then return end
    if T.AutoLayouts then T.AutoLayouts:ManualEdit() end
    self:Cancel()
    return {profile = T.db, snapshot = self:Capture()}
end
function L:EndEdit(edit)
    if not edit or edit.profile ~= T.db or self.replaying then return end
    local changes = Changes(edit.snapshot, self:Capture())
    if #changes > 0 then
        local h = History()
        h.undo[#h.undo + 1] = changes
        if #h.undo > 50 then table.remove(h.undo, 1) end
        h.redo = {}
    end
    Notify()
end
local function Replay(self, source, destination, field)
    local ready, err = self:CanEdit()
    if not ready then return nil, err end
    local h = History()
    local change = h[source][#h[source]]
    if not change then return nil, source == "undo" and "Nothing to undo." or "Nothing to redo." end
    if T.AutoLayouts then T.AutoLayouts:ManualEdit() end
    self:Cancel()
    self.replaying = true
    for _, entry in ipairs(change) do
        local cfg = Resolve(T.db, entry.path)
        if type(cfg) == "table" then cfg.point = Copy(entry[field]) end
    end
    table.remove(h[source])
    h[destination][#h[destination] + 1] = change
    T:ApplySettings()
    self.replaying = nil
    Notify()
    return true
end
function L:Undo() return Replay(self, "undo", "redo", "before") end
function L:Redo() return Replay(self, "redo", "undo", "after") end

function L:Store()
    T.db.layoutPresets = T.db.layoutPresets or {}
    return T.db.layoutPresets
end
function L:Names()
    local names = {}; for name in pairs(self:Store()) do names[#names + 1] = name end
    table.sort(names); return names
end
function L:Name(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" or #name > 48 or name:find("[%c|]") then return nil, "Use a name of 1-48 bytes without control characters or |." end
    if self:Store()[name] then return nil, "That preset name already exists." end
    return name
end
function L:Save(name)
    local valid, err = self:Name(name); if not valid then return nil, err end
    self:Store()[valid] = self:Capture(); return valid
end
function L:Duplicate(from, name)
    if not self:Store()[from] then return nil, "Select a saved preset first." end
    local valid, err = self:Name(name); if not valid then return nil, err end
    self:Store()[valid] = Copy(self:Store()[from]); return valid
end
function L:Rename(from, name)
    local valid, err = self:Duplicate(from, name); if not valid then return nil, err end
    self:Store()[from] = nil
    if T.AutoLayouts then T.AutoLayouts:PresetRenamed(from, valid) end
    return valid
end
function L:Delete(name)
    self:Store()[name] = nil
    if T.AutoLayouts then T.AutoLayouts:PresetDeleted(name) end
end
function L:Stage(name, defaults)
    if InCombatLockdown() then return nil, "Leave combat before previewing a layout." end
    for _, mover in ipairs(T.Movers.list) do
        if mover.moving or mover.sizing or mover.pendingMove then return nil, "Finish dragging or resizing before previewing a layout." end
    end
    local snapshot = defaults and self:Capture(T.defaults) or self:Store()[name]
    if not snapshot then return nil, "Select a saved preset first." end
    self:Cancel()
    self.pending = {profile = T.db, snapshot = Copy(snapshot)}
    self.ghosts = {}
    self.pool = self.pool or {}
    for _, mover in ipairs(T.Movers.list) do
        local cfg = mover.opts.cfg()
        for _, entry in ipairs(snapshot) do
            if Resolve(T.db, entry.path) == cfg and (not mover.opts.enabled or mover.opts.enabled()) then
                local index = #self.ghosts + 1
                local ghost = self.pool[index]
                if not ghost then
                    ghost = CreateFrame("Frame", nil, UIParent)
                    local bg = T.Style.Accent(T.Style.Tex(ghost, "BACKGROUND"), 0.3); bg:SetAllPoints()
                    ghost.border = T.Style.CreateBorder(ghost, "BORDER"); ghost.border:SetThickness(2, ghost)
                    ghost.label = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    ghost.label:SetPoint("CENTER")
                    self.pool[index] = ghost
                end
                ghost:ClearAllPoints(); ghost:Show()
                ghost:SetFrameStrata("DIALOG"); ghost:EnableMouse(false)
                local frame, point = mover.target, entry.point
                ghost:SetScale(frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
                ghost:SetSize(frame:GetWidth(), frame:GetHeight())
                ghost:SetPoint(point[1], UIParent, point[3], point[4], point[5])
                ghost.border:SetColor(T.accent[1], T.accent[2], T.accent[3], 1)
                ghost.label:SetText(mover.opts.label .. " (preview)")
                self.ghosts[#self.ghosts + 1] = ghost
                break
            end
        end
    end
    return true
end
function L:Cancel()
    for _, ghost in ipairs(self.ghosts or {}) do ghost:Hide(); ghost:ClearAllPoints() end
    self.ghosts, self.pending = nil, nil
end
function L:Apply()
    local pending = self.pending
    if not pending then return nil, "Preview a layout first." end
    if InCombatLockdown() then return nil, "Leave combat before applying a layout." end
    if pending.profile ~= T.db then self:Cancel(); return nil, "Profile changed; preview again." end
    for _, mover in ipairs(T.Movers.list) do
        if mover.moving or mover.sizing or mover.pendingMove then return nil, "Finish dragging or resizing before applying a layout." end
    end
    return self:ApplySnapshot(pending.snapshot)
end
function L:ApplySnapshot(snapshot)
    local ready, err = self:CanEdit()
    if not ready then return nil, err end
    local edit = self:BeginEdit()
    for _, entry in ipairs(snapshot) do
        local cfg = Resolve(T.db, entry.path)
        if type(cfg) == "table" then cfg.point = Copy(entry.point) end
    end
    self:Cancel(); T:ApplySettings(); self:EndEdit(edit); return true
end
function L:ApplySaved(name)
    local snapshot = self:Store()[name]
    if not snapshot then return nil, "That layout preset no longer exists." end
    return self:ApplySnapshot(Copy(snapshot))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then L:Cancel() end
    Notify()
end)
