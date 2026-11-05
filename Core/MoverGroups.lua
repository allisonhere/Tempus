-- Multi-frame geometry is expressed in UIParent units, independent of frame scale.
local _, T = ...
local M = T.Movers
function M.GroupBounds(boxes)
    local union
    for _, box in ipairs(boxes) do
        if not union then union = {box[1], box[2], box[3], box[4]}
        else
            union[1], union[2] = math.min(union[1], box[1]), math.max(union[2], box[2])
            union[3], union[4] = math.min(union[3], box[3]), math.max(union[4], box[4])
        end
    end
    return union
end
local minimum = {move = 1, centerScreen = 1, left = 2, right = 2, top = 2,
    bottom = 2, centerX = 2, centerY = 2, spaceX = 3, spaceY = 3}
function M.GroupPlan(boxes, action, dx, dy, W, H)
    local required = minimum[action]
    if not required then return nil, "Unknown group action." end
    if #boxes < required then return nil, "Select at least " .. required .. " frames." end
    local union, positions = M.GroupBounds(boxes), {}
    for i, box in ipairs(boxes) do positions[i] = {box[1], box[3]} end
    if action == "move" or action == "centerScreen" then
        if union[2] - union[1] > W or union[4] - union[3] > H then return nil, "The selected group is larger than the screen." end
        if action == "centerScreen" then
            dx, dy = (W - union[1] - union[2]) / 2, (H - union[3] - union[4]) / 2
        end
        dx = math.max(-union[1], math.min(dx or 0, W - union[2]))
        dy = math.max(-union[3], math.min(dy or 0, H - union[4]))
        for i, box in ipairs(boxes) do positions[i] = {box[1] + dx, box[3] + dy} end
    elseif action == "spaceX" or action == "spaceY" then
        local axis = action == "spaceX" and 1 or 3
        local sorted, size = {}, 0
        for i, box in ipairs(boxes) do sorted[i] = i; size = size + box[axis + 1] - box[axis] end
        table.sort(sorted, function(a,b)
            if boxes[a][axis] == boxes[b][axis] then return a < b end
            return boxes[a][axis] < boxes[b][axis]
        end)
        local start = boxes[sorted[1]][axis]
        local finish = boxes[sorted[#sorted]][axis + 1]
        local gap = (finish - start - size) / (#boxes - 1)
        if gap < -0.00001 then return nil, "Not enough room for equal gaps; spread the frames apart first." end
        local offset = start
        for _, i in ipairs(sorted) do
            positions[i][axis == 1 and 1 or 2] = offset
            offset = offset + boxes[i][axis + 1] - boxes[i][axis] + math.max(0, gap)
        end
    else
        for i, box in ipairs(boxes) do
            local w, h = box[2] - box[1], box[4] - box[3]
            if action == "left" then positions[i][1] = union[1]
            elseif action == "right" then positions[i][1] = union[2] - w
            elseif action == "centerX" then positions[i][1] = (union[1] + union[2] - w) / 2
            elseif action == "bottom" then positions[i][2] = union[3]
            elseif action == "top" then positions[i][2] = union[4] - h
            elseif action == "centerY" then positions[i][2] = (union[3] + union[4] - h) / 2 end
        end
    end
    for i, p in ipairs(positions) do
        local box = boxes[i]
        if p[1] < -0.00001 or p[2] < -0.00001 or p[1] + box[2] - box[1] > W + 0.00001
            or p[2] + box[4] - box[3] > H + 0.00001 then return nil, "That arrangement would place a frame off screen." end
    end
    return positions
end
function M:CanGroup(required)
    if not T.db or T.db.locked then return false, "Unlock the frames first." end
    local ready, err = T.Layouts:CanEdit()
    if not ready then return false, err end
    if #self:Selection() < (required or 1) then return false, "Select at least " .. (required or 1) .. " frames." end
    return true
end
local function Capture()
    local state = {profile = T.db, items = {}, boxes = {}}
    for _, mover in ipairs(M:Selection()) do
        local box, cfg = M.GetBounds(mover.target), mover.opts.cfg()
        if not box or not cfg then return nil, "A selected frame is not ready to move." end
        local corner = mover.opts.corner and mover.opts.corner() or (cfg.point and cfg.point[1]) or "CENTER"
        state.items[#state.items + 1] = {mover = mover, cfg = cfg, corner = corner}
        state.boxes[#state.boxes + 1] = box
    end
    return state
end
local function Place(state, positions)
    for i, item in ipairs(state.items) do
        local frame, p = item.mover.target, positions[i]
        local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p[1] / factor, p[2] / factor)
    end
end
local function Commit(state)
    for _, item in ipairs(state.items) do item.mover.pendingMove = nil end
    if state.profile ~= T.db then M:RefreshHistory(); return end
    -- Settings may have re-laid frames before hiding a mover or ending combat.
    -- Commit the final cursor positions, rather than that incidental module layout.
    if state.positions then Place(state, state.positions) end
    -- Save every anchor before callbacks can trigger module layouts or hide movers.
    for _, item in ipairs(state.items) do M.SavePoint(item.mover.target, item.cfg, item.corner, true) end
    for _, item in ipairs(state.items) do if item.mover.opts.onMoved then item.mover.opts.onMoved() end end
    T.Layouts:EndEdit(state.edit)
    M:RefreshSelection()
end
function M:GroupAction(action, dx, dy)
    local ready, err = self:CanGroup(minimum[action] or 1)
    if not ready then return nil, err end
    local state; state, err = Capture()
    if not state then return nil, err end
    local positions; positions, err = M.GroupPlan(state.boxes, action, dx, dy, UIParent:GetWidth(), UIParent:GetHeight())
    if not positions then return nil, err end
    state.edit = T.Layouts:BeginEdit()
    state.positions = positions
    Commit(state)
    return true
end
function M:StartGroupDrag(source)
    local ready = self:CanGroup(1)
    if not ready then return end
    local state = Capture()
    if not state then return end
    state.source, state.edit = source, T.Layouts:BeginEdit()
    state.positions = {}
    for i, box in ipairs(state.boxes) do state.positions[i] = {box[1], box[3]} end
    state.x, state.y = GetCursorPosition()
    state.scale = UIParent:GetEffectiveScale()
    state.union = M.GroupBounds(state.boxes)
    state.targets = {{0, UIParent:GetWidth(), 0, UIParent:GetHeight()}}
    for _, other in ipairs(self.list) do
        if not self.selected[other] and other:IsShown() then
            local box = M.GetBounds(other.target)
            if box then state.targets[#state.targets + 1] = box end
        end
    end
    self.activeDrag, source.moving = state, true
    source:SetScript("OnUpdate", function()
        if T.db ~= state.profile or T.db.locked or InCombatLockdown() then self:FinishGroupDrag(); return end
        local x, y = GetCursorPosition()
        local W, H = UIParent:GetWidth(), UIParent:GetHeight()
        local positions = M.GroupPlan(state.boxes, "move", (x - state.x) / state.scale, (y - state.y) / state.scale, W, H)
        if not positions then M.HideGuides(); return end
        local dx, dy = positions[1][1] - state.boxes[1][1], positions[1][2] - state.boxes[1][3]
        local u = state.union
        local sx, sy, gx, gy = 0, 0
        if not IsAltKeyDown() then
            sx, sy, gx, gy = M.FindSnap({u[1]+dx,u[2]+dx,u[3]+dy,u[4]+dy}, state.targets, 8)
            if u[1]+dx+sx < 0 or u[2]+dx+sx > W then sx,gx = 0,nil end
            if u[3]+dy+sy < 0 or u[4]+dy+sy > H then sy,gy = 0,nil end
        end
        for _, p in ipairs(positions) do p[1], p[2] = p[1]+sx, p[2]+sy end
        state.positions = positions
        Place(state, positions); M.ShowGuides(gx,gy)
    end)
    self:RefreshHistory()
end
function M:FinishGroupDrag()
    local state = self.activeDrag
    if not state then return end
    self.activeDrag, state.source.moving = nil, nil
    state.source:SetScript("OnUpdate", nil)
    M.HideGuides()
    for _, item in ipairs(state.items) do item.mover.pendingMove = true end
    T:RunOOC(function() Commit(state) end)
    self:RefreshHistory()
end
