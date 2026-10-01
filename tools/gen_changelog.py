#!/usr/bin/env python3
"""Regenerates Core/Changelog.lua from CHANGELOG.md so the settings window can show it.
Run from the addon folder after editing CHANGELOG.md:  python3 tools/gen_changelog.py"""
import re

def lua(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = re.sub(r"\*\*(.+?)\*\*", r"|cffffffff\1|r", s)
    s = re.sub(r"`(.+?)`", r"|cff9fd6ff\1|r", s)
    return s.replace("|", "||").replace("||c", "|c").replace("||r", "|r")

out, version, section = [], None, None
for raw in open("CHANGELOG.md", encoding="utf-8").read().splitlines():
    line = raw.rstrip()
    if line.startswith("## "):
        if section: out.append("        } },")
        if version: out.append("    } },")
        version, section = line[3:].strip(), None
        out.append('    { version = "%s", sections = {' % lua(version))
    elif line.startswith("### ") and version:
        if section: out.append("        } },")
        section = line[4:].strip()
        out.append('        { title = "%s", items = {' % lua(section))
    elif section and re.match(r"^\s*- ", line):
        indent = len(line) - len(line.lstrip())
        out.append('            { %d, "%s" },' % (1 if indent else 0, lua(line.strip()[2:])))
if section: out.append("        } },")
if version: out.append("    } },")
open("Core/Changelog.lua", "w", encoding="utf-8").write(
    "-- Generated from CHANGELOG.md by tools/gen_changelog.py. Do not edit by hand.\n"
    "local _, T = ...\nT.changelog = {\n" + "\n".join(out) + "\n}\n")
