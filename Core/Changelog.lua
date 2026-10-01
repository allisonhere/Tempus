-- Generated from CHANGELOG.md by tools/gen_changelog.py. Do not edit by hand.
local _, T = ...
T.changelog = {
    { version = "2.3.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffShare profiles|r: Export turns the active profile into a text string; Import creates a new profile from one (General > Profiles). Damaged or edited strings are refused, and nothing in them is ever run." },
            { 0, "|cffffffffCooldowns module|r: a movable row of icons with cooldown swipes for spells you list and your trinkets. \"Add my interrupt\" adds your class's interrupt." },
            { 0, "|cffffffffVendor module|r: sells grey items and repairs gear when you open a merchant (optionally from guild funds), with a short chat summary." },
            { 0, "|cffffffffDispellable buff alert|r on nameplates: a purple edge on enemies carrying a buff you can dispel or steal. It works in combat." },
        } },
    } },
    { version = "2.2.1", sections = {
        { title = "Fixed", items = {
            { 0, "The five combo point boxes above the player frame now show only for rogues and druids in cat form, not for every class." },
        } },
    } },
    { version = "2.2.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffYour interrupt on nameplates|r: your own interrupt, with its cooldown swipe, shows beside casts you can stop (Nameplates > Casts & Auras). Hidden for classes without one." },
            { 0, "|cffffffffWho interrupted|r: a stopped cast reads \"Interrupted: Name\" when the game reports who did it." },
        } },
    } },
    { version = "2.1.3", sections = {
        { title = "New", items = {
            { 0, "|cffffffffSpellPower settings in the Tempus window|r: with SpellPower 0.3.0 or newer installed, its pages are listed in the sidebar and shown in the Tempus window, in the same look." },
        } },
    } },
    { version = "2.1.2", sections = {
        { title = "New", items = {
            { 0, "|cffffffffSpellPower|r gets a section in the settings sidebar (when the addon is installed) with a button that opens its settings." },
        } },
        { title = "Fixed", items = {
            { 0, "The quest tracker no longer stops refreshing if a layout pass hits an error." },
        } },
    } },
    { version = "2.1.1", sections = {
        { title = "Fixed", items = {
            { 0, "|cffffffffTaint error on level-up|r: hiding Blizzard's buff and debuff frames no longer reparents them, which caused \"Auras cannot be accessed when secret while tainted\" when Edit Mode refreshed." },
        } },
    } },
    { version = "2.1.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffThemes apply everywhere|r: Modern, Gloss, Classic and Flat now restyle every Tempus panel and status bar (unit, party and raid frames, nameplates, action bars, minimap, info bar, skinned windows) live, not just buffs. Class, dispel and target highlight edges stay visible in every theme." },
            { 0, "|cffffffffWhat's new page|r in the settings window (General), showing this changelog." },
            { 0, "|cffffffffQuest log search|r: a search box over the quest list that tolerates typos and matches zone names, a Zones button to hide whole zones, and Reset." },
            { 0, "|cffffffffQuest tracker zones and search|r: tracked quests are grouped under zone headers that fold (remembered per character), plus a fuzzy search box at the top of the tracker." },
            { 0, "|cffffffffStock skin|r (Skins page): Blizzard's own look for windows, tooltips, chat and the tracker, with all Tempus features kept." },
            { 0, "|cffffffffNameplates|r" },
            { 1, "A replacement for Blizzard's plates: threat colours by role, execute-range tint and a target glow." },
            { 1, "Cast bars that show when a cast can be interrupted, and alerts for spells on your watch list." },
            { 1, "Your debuffs, purgeable buffs and crowd control." },
            { 0, "|cffffffffCon on nameplates|r: a con-coloured strip, relative level, elite/rare/boss pips or an optional 1-5 danger rating, and grey mobs shrunk and faded." },
            { 0, "|cffffffffParty & Raid frames|r" },
            { 1, "Secure group headers, range fading, incoming heals and absorbs." },
            { 1, "Dispellable debuffs with a coloured tint, your HoTs with timers, and role, leader, ready-check and aggro indicators." },
            { 0, "|cffffffffClick-casting|r on party and raid frames, with starting bindings for Druid, Priest, Shaman and Paladin, and a preview that explains each click." },
            { 0, "|cffffffffPreviews|r: sample nameplates and group frames on their settings pages, plus on-screen sample party/raid frames for arranging them solo." },
            { 0, "|cffffffffAccent colour|r: six to choose from (Appearance)." },
            { 0, "The installer presets now cover nameplates and group frames." },
        } },
        { title = "Fixed", items = {
            { 0, "The panel behind the quest tracker now stays the height of its content when sections change, zones fold or the tracker collapses." },
            { 0, "Target frame auras duplicated on every retarget." },
            { 0, "Spellbook category tabs lost their icons." },
            { 0, "Quest and book text is dark brown on parchment instead of light grey." },
            { 0, "The unit frames' \"by health\" colour never reached green." },
            { 0, "Settings pages could stop scrolling partway down." },
        } },
        { title = "Changed", items = {
            { 0, "New Tempus logo (a clock whose hands form a T) in the AddOns list, settings, installer and minimap button, replacing the pocket-watch icon." },
            { 0, "Developer probing is off by default (|cff9fd6ff/tempus probe|r to turn it on, |cff9fd6ff/tempus probe off|r to clear it)." },
            { 0, "Tempus UI is now published under an All Rights Reserved license (see LICENSE): free to download and play with; redistribution or reuse needs permission." },
        } },
    } },
}
