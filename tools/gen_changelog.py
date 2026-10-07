#!/usr/bin/env python3
"""Generate Core/Changelog.lua from CHANGELOG.md, or verify that it is current."""
import argparse
from pathlib import Path
import re

def lua(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = re.sub(r"\*\*(.+?)\*\*", r"|cffffffff\1|r", s)
    s = re.sub(r"`(.+?)`", r"|cff9fd6ff\1|r", s)
    return s.replace("|", "||").replace("||c", "|c").replace("||r", "|r")

def render(source):
    out, version, section = [], None, None
    for raw in source.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if line.startswith("## "):
            if section:
                out.append("        } },")
            if version:
                out.append("    } },")
            version, section = line[3:].strip(), None
            out.append('    { version = "%s", sections = {' % lua(version))
        elif line.startswith("### ") and version:
            if section:
                out.append("        } },")
            section = line[4:].strip()
            out.append('        { title = "%s", items = {' % lua(section))
        elif section and re.match(r"^\s*- ", line):
            indent = len(line) - len(line.lstrip())
            out.append('            { %d, "%s" },' % (1 if indent else 0, lua(line.strip()[2:])))
    if section:
        out.append("        } },")
    if version:
        out.append("    } },")
    return (
        "-- Generated from CHANGELOG.md by tools/gen_changelog.py. Do not edit by hand.\n"
        "local _, T = ...\nT.changelog = {\n" + "\n".join(out) + "\n}\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="CHANGELOG.md")
    parser.add_argument("--output", default="Core/Changelog.lua")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source, output = Path(args.source), Path(args.output)
    generated = render(source)
    if args.check:
        current = output.read_text(encoding="utf-8") if output.exists() else None
        if current != generated:
            parser.error(f"{output} is stale; run tools/gen_changelog.py")
        return
    output.write_text(generated, encoding="utf-8")


if __name__ == "__main__":
    main()
