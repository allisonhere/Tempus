-- Tempus UI: damage meter helpers shared with Combat Pulse, data source. Reads Blizzard's built-in damage meter
-- (C_DamageMeter) rather than parsing the combat log. In combat the client may hand the
-- numbers back as secret values, which can be drawn but not compared; Read reports that.
local _, T = ...
local DT = T.DPSTrack or {}
T.DPSTrack = DT

local Source = {}
DT.Source = Source

local function EnumValue(group, key, fallback)
    local g = Enum and Enum[group]
    return g and g[key] or fallback
end

function Source.Available()
    return (C_DamageMeter and type(C_DamageMeter.GetCombatSessionFromType) == "function") and true or false
end

local function IsMe(src, myGUID)
    local mine = src.isLocalPlayer
    if not T.issecret(mine) and mine == true then return true end
    local guid = src.sourceGUID
    return myGUID ~= nil and not T.issecret(guid) and guid == myGUID
end

-- live and group top from a session's sources. Returns live, top, secret; when secret is
-- true, live may be a secret value and top is nil (secret values cannot be compared).
function Source.Pick(sources, myGUID)
    local live, top, secret = 0, 0, false
    if type(sources) ~= "table" then return live, top, secret end
    for _, src in ipairs(sources) do
        if type(src) == "table" then
            local aps = src.amountPerSecond
            if T.issecret(aps) then
                secret = true
                if IsMe(src, myGUID) then live = aps end
            elseif type(aps) == "number" then
                if aps > top then top = aps end
                if IsMe(src, myGUID) then live = aps end
            end
        end
    end
    if secret then top = nil end
    return live, top, secret
end

-- The current fight from Blizzard's meter, or nil when there is none.
function Source.Read()
    if not Source.Available() then return nil end
    local damageDone = EnumValue("DamageMeterType", "DamageDone", 0)
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType,
        EnumValue("DamageMeterSessionType", "Current", 1), EnumValue("DamageMeterType", "Dps", damageDone))
    if not ok or T.issecret(session) or type(session) ~= "table" then return nil end
    local live, top, secret = Source.Pick(session.combatSources, UnitGUID and UnitGUID("player"))
    if secret then
        -- The DPS session is ranked by Blizzard; maxAmount measures total damage.
        local first = session.combatSources[1]
        top = first and first.amountPerSecond or 0
    end
    return live, top, secret
end

-- Animated stand-in for test mode: a wavering player and a stronger group member.
function Source.Test(t)
    local live = 640e3 + 170e3 * math.sin(t * 0.9) + 60e3 * math.sin(t * 2.3)
    local other = 930e3 + 230e3 * math.sin(t * 0.33 + 1)
    return live, math.max(live, other), false
end
