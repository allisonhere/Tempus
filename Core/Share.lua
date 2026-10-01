-- Tempus UI: profile sharing. A profile becomes a text string that can be pasted anywhere.
-- Nothing is ever run: the string is parsed by the small JSON-style reader below.
local _, T = ...
local Share = {}
T.Share = Share

local PREFIX = "TEMPUS1:"
local MAX_DEPTH, MAX_LEN = 12, 400000

----------------------------------------------------------------------------------------
-- Encoding
----------------------------------------------------------------------------------------
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function Str(s)
    return '"' .. s:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end) .. '"'
end

local function KeyString(k)
    if type(k) == "number" then return "#" .. string.format("%.14g", k) end
    if k:sub(1, 1) == "#" then return "#s" .. k end
    return k
end

local function IsArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == 0 then return false end
    for i = 1, n do if t[i] == nil then return false end end
    return true
end

local function Ser(v, out, depth)
    local kind = type(v)
    if kind == "boolean" then out[#out + 1] = v and "true" or "false"
    elseif kind == "number" then
        out[#out + 1] = (v ~= v or v == math.huge or v == -math.huge) and "null" or string.format("%.14g", v)
    elseif kind == "string" then out[#out + 1] = Str(v)
    elseif kind == "table" and depth < MAX_DEPTH then
        if IsArray(v) then
            out[#out + 1] = "["
            for i = 1, #v do
                if i > 1 then out[#out + 1] = "," end
                Ser(v[i], out, depth + 1)
            end
            out[#out + 1] = "]"
        else
            local keys = {}
            for k, val in pairs(v) do
                if (type(k) == "string" or type(k) == "number") and type(val) ~= "function" then keys[#keys + 1] = k end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            out[#out + 1] = "{"
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = "," end
                out[#out + 1] = Str(KeyString(k)) .. ":"
                Ser(v[k], out, depth + 1)
            end
            out[#out + 1] = "}"
        end
    else out[#out + 1] = "null" end
end

function Share.Serialize(value)
    local out = {}
    Ser(value, out, 0)
    return table.concat(out)
end

----------------------------------------------------------------------------------------
-- Decoding (JSON subset)
----------------------------------------------------------------------------------------
local UNESC = { ['"'] = '"', ["\\"] = "\\", ["n"] = "\n", ["r"] = "\r", ["t"] = "\t", ["/"] = "/" }

local function Fail(msg, pos) error({ share = msg .. " at character " .. pos }, 0) end

local function SkipWs(s, i)
    return s:find("[^ \t\r\n]", i) or (#s + 1)
end

local Read

local function ReadString(s, i)
    local out, j = {}, i + 1
    while true do
        local c = s:sub(j, j)
        if c == "" then Fail("unterminated string", i) end
        if c == '"' then return table.concat(out), j + 1 end
        if c == "\\" then
            local n = s:sub(j + 1, j + 1)
            if n == "u" then
                local hex = s:match("^%x%x%x%x", j + 2)
                if not hex then Fail("bad escape", j) end
                local code = tonumber(hex, 16)
                out[#out + 1] = code < 256 and string.char(code) or "?"
                j = j + 6
            elseif UNESC[n] then out[#out + 1] = UNESC[n]; j = j + 2
            else Fail("bad escape", j) end
        else
            out[#out + 1] = c
            j = j + 1
        end
    end
end

local function DecodeKey(k)
    if k:sub(1, 2) == "#s" then return k:sub(3) end
    if k:sub(1, 1) == "#" then return tonumber(k:sub(2)) or k end
    return k
end

function Read(s, i, depth)
    if depth > MAX_DEPTH then Fail("nested too deeply", i) end
    i = SkipWs(s, i)
    local c = s:sub(i, i)
    if c == "{" then
        local t = {}
        i = SkipWs(s, i + 1)
        if s:sub(i, i) == "}" then return t, i + 1 end
        while true do
            i = SkipWs(s, i)
            if s:sub(i, i) ~= '"' then Fail("expected a key", i) end
            local key
            key, i = ReadString(s, i)
            i = SkipWs(s, i)
            if s:sub(i, i) ~= ":" then Fail("expected ':'", i) end
            local value
            value, i = Read(s, i + 1, depth + 1)
            t[DecodeKey(key)] = value
            i = SkipWs(s, i)
            local d = s:sub(i, i)
            if d == "}" then return t, i + 1 end
            if d ~= "," then Fail("expected ',' or '}'", i) end
            i = i + 1
        end
    elseif c == "[" then
        local t, n = {}, 0
        i = SkipWs(s, i + 1)
        if s:sub(i, i) == "]" then return t, i + 1 end
        while true do
            local value
            value, i = Read(s, i, depth + 1)
            n = n + 1
            t[n] = value
            i = SkipWs(s, i)
            local d = s:sub(i, i)
            if d == "]" then return t, i + 1 end
            if d ~= "," then Fail("expected ',' or ']'", i) end
            i = i + 1
        end
    elseif c == '"' then return ReadString(s, i)
    elseif s:sub(i, i + 3) == "true" then return true, i + 4
    elseif s:sub(i, i + 4) == "false" then return false, i + 5
    elseif s:sub(i, i + 3) == "null" then return nil, i + 4
    end
    local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
    if num and num ~= "" and tonumber(num) then return tonumber(num), i + #num end
    Fail("unexpected character", i)
end

function Share.Parse(text)
    if #text > MAX_LEN then return nil, "too large" end
    local ok, value, stop = pcall(Read, text, 1, 0)
    if not ok then return nil, type(value) == "table" and value.share or "unreadable" end
    if SkipWs(text, stop) <= #text then return nil, "extra text after the data" end
    return value
end

----------------------------------------------------------------------------------------
-- Base64 and checksum (plain arithmetic: no bit library needed)
----------------------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64IDX = {}
for i = 1, #B64 do B64IDX[B64:sub(i, i)] = i - 1 end

function Share.Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

function Share.Base64Decode(text)
    text = text:gsub("[^%w%+/=]", "")
    if #text % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local a, b, c, d = text:sub(i, i), text:sub(i + 1, i + 1), text:sub(i + 2, i + 2), text:sub(i + 3, i + 3)
        local va, vb = B64IDX[a], B64IDX[b]
        local vc, vd = c == "=" and 0 or B64IDX[c], d == "=" and 0 or B64IDX[d]
        if not (va and vb and vc and vd) then return nil end
        local n = va * 262144 + vb * 4096 + vc * 64 + vd
        local chars = string.char(math.floor(n / 65536) % 256)
        if c ~= "=" then chars = chars .. string.char(math.floor(n / 256) % 256) end
        if d ~= "=" then chars = chars .. string.char(n % 256) end
        out[#out + 1] = chars
    end
    return table.concat(out)
end

local function Checksum(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + data:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%04x%04x", b, a)
end

----------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------
function Share.Export(profile)
    local body = Share.Serialize(profile)
    return PREFIX .. Checksum(body) .. ":" .. Share.Base64Encode(body)
end

-- Returns the decoded table, or nil and a short reason.
function Share.Import(text)
    text = (text or ""):gsub("%s+", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, "this is not a Tempus profile string" end
    local sum, payload = text:match("^" .. PREFIX .. "(%x%x%x%x%x%x%x%x):(.+)$")
    if not sum then return nil, "the string is incomplete" end
    local body = Share.Base64Decode(payload)
    if not body then return nil, "the string is damaged" end
    if Checksum(body) ~= sum then return nil, "the string was cut off or changed" end
    local value, err = Share.Parse(body)
    if type(value) ~= "table" then return nil, err or "no settings found" end
    return value
end

-- Keeps only settings Tempus knows about, with the type they are expected to have.
function Share.Sanitize(profile, defaults)
    local clean = {}
    for key, default in pairs(defaults) do
        local v = profile[key]
        if v ~= nil and type(v) == type(default) then clean[key] = v end
    end
    return clean
end

----------------------------------------------------------------------------------------
-- Profile helpers
----------------------------------------------------------------------------------------
function T:ExportProfile()
    return Share.Export(T.db)
end

-- Reads a pasted string into a new profile and switches to it. Returns true, or false and why.
function T:ImportProfile(name, text)
    name = strtrim(name or "")
    if name == "" then return false, "give the new profile a name" end
    if TempusDB.profiles[name] then return false, "a profile called " .. name .. " already exists" end
    local profile, err = Share.Import(text)
    if not profile then return false, err end
    TempusDB.profiles[name] = Share.Sanitize(profile, T.defaults)
    T:SetProfile(name)
    return true
end
