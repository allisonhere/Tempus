-- Optional-addon discoverability must preserve both modern and legacy integration.
local previous, previousAPI, previousLegacy = _G.SpellPower, C_AddOns, IsAddOnLoaded
local function Load(sp, loaded, legacy)
    _G.SpellPower = sp
    C_AddOns = loaded ~= nil and {IsAddOnLoaded=function(name) assert(name=="SpellPower");return loaded end} or nil
    IsAddOnLoaded = legacy and function() return true end or nil
    local T={Style={C={}},UI={},accent={},pages={}}
    function T:RegisterPage(section,def) def.section=section; self.pages[#self.pages+1]=def end
    assert(loadfile("Config/Window.lua"))("Tempus",T)
    local entries={}
    for _,def in ipairs(T.pages) do if def.section=="spellpower" then entries[#entries+1]=def end end
    return T,entries
end
local _,entries=Load(nil,false)
assert(#entries==1 and entries[1].unavailable and not entries[1].build)
assert(entries[1].search:find("grammar",1,true))
_,entries=Load(nil,true)
assert(#entries==1 and not entries[1].unavailable and type(entries[1].build)=="function")
_,entries=Load({},nil)
assert(#entries==1 and not entries[1].unavailable,"an older loaded global still gets the legacy settings link")
_,entries=Load(nil,nil,true)
assert(#entries==1 and not entries[1].unavailable,"legacy addon-loaded API is supported")
local mixed,built=0,0
local SP={Settings={sections={{key="general"}},pages={{key="spelling",label="Spelling",section="general",order=2,
    build=function(p) assert(p.marker);built=built+1 end}},Mixin=function(_,p) p.marker=true;mixed=mixed+1 end}}
_,entries=Load(SP,true)
assert(#entries==1 and entries[1].key=="sp_spelling" and entries[1].order==12 and not entries[1].unavailable)
entries[1].build({});assert(mixed==1 and built==1)
_G.SpellPower, C_AddOns, IsAddOnLoaded = previous, previousAPI, previousLegacy
print("PASS: missing, disabled, legacy and integrated SpellPower menu registration")
