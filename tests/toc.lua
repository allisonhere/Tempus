-- The TOC is the runtime manifest. Every production Lua file must appear once.
local listed, order = {}, {}
for line in io.lines("Tempus.toc") do
    local path = line:match("^([^#].*%.lua)%s*$")
    if path then
        path = path:gsub("\\", "/")
        assert(not listed[path], "duplicate TOC entry: " .. path)
        local file = assert(io.open(path, "rb"), "missing TOC file: " .. path)
        file:close()
        listed[path] = true
        order[#order + 1] = path
    end
end

local found = {}
local scan = assert(io.popen("find Core Config Modules -type f -name '*.lua' | sort"))
for path in scan:lines() do
    found[path] = true
    assert(listed[path], "production Lua file is absent from Tempus.toc: " .. path)
end
assert(scan:close(), "could not scan production Lua files")
for path in pairs(listed) do
    assert(found[path], "TOC entry is outside the production Lua directories: " .. path)
end
assert(order[1] == "Core/Core.lua", "Core/Core.lua must load first")
print("PASS: Tempus.toc lists every production Lua file exactly once")
