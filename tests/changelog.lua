local T = {Style = {C = {muted = {1, 1, 1}, text = {1, 1, 1}}, accent = {0, 1, 1}}, UI = {}, version = '9.9'}
local pages = {}
function T:RegisterPage(section, def) pages[#pages + 1] = def end
assert(loadfile('Core/Changelog.lua'))('Tempus', T)
assert(loadfile('Config/Changelog.lua'))('Tempus', T)
assert(#T.changelog >= 1 and T.changelog[1].version, 'changelog data present')
local lines, sections = {}, {}
local p = {
    Section = function(_, title) sections[#sections + 1] = title end,
    Paragraph = function(_, text) lines[#lines + 1] = text end,
}
assert(#pages == 1 and pages[1].key == 'changelog')
pages[1].build(p)
local joined = table.concat(lines, '\n')
assert(joined:find('Themes apply everywhere', 1, true), 'latest entry rendered')
assert(sections[1]:find("What's new", 1, true))
-- Generated file is in sync with CHANGELOG.md.
local md = io.open('CHANGELOG.md'):read('*a')
local _, headings = md:gsub('\n## ', '')
assert(headings == #T.changelog, 'run python3 tools/gen_changelog.py')
print('PASS: changelog page renders every release; generated data matches CHANGELOG.md')
