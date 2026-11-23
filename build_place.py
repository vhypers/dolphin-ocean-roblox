#!/usr/bin/env python3
"""Rebuild build/Spring.rbxlx from src/ with Rojo, keeping the ocean baked into the old file.

Run it only while Studio does not have the place open:  python3 build_place.py
The old file is kept as build/Spring-before.rbxlx. Rojo builds the scripts; the Terrain item
(the baked sea floor and water, its colours and the SpringOcean version) is copied over from
the old file, so the ocean does not have to be baked again.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
PLACE = os.path.join(HERE, "build", "Spring.rbxlx")
BEFORE = os.path.join(HERE, "build", "Spring-before.rbxlx")


def main() -> int:
    if os.path.exists(PLACE + ".lock"):
        print("Studio has the place open (build/Spring.rbxlx.lock). Close it first.")
        return 1
    with tempfile.TemporaryDirectory() as scratch:
        fresh = os.path.join(scratch, "fresh.rbxlx")
        subprocess.run([os.path.join(HERE, "tools", "rojo"), "build", HERE, "-o", fresh], check=True)
        new = open(fresh, encoding="utf-8").read()
        terrain = ""
        if os.path.exists(PLACE):
            old = open(PLACE, encoding="utf-8").read()
            m = re.search(r'<Item class="Terrain" referent="([^"]*)">', old)
            if m:
                end = old.find("</Item>", m.end())
                nested = old.find("<Item ", m.end())
                if nested != -1 and nested < end:
                    print("The old Terrain has children; this script does not handle that.")
                    return 1
                terrain = old[m.start() : end + len("</Item>")]
                if ('referent="%s"' % m.group(1)) in new:
                    print("Referent clash; build again.")
                    return 1
        if terrain:
            ws = re.search(r'<Item class="Workspace" referent="[^"]*">', new)
            at = new.find("</Properties>", ws.end()) + len("</Properties>")
            new = new[:at] + "\n" + terrain + new[at:]
            # the terrain refers to shared strings (its materials, its tags) kept at the file's end
            wanted = set(re.findall(r'<SharedString name="[^"]*">([^<]*)</SharedString>', terrain))
            have = set(re.findall(r'<SharedString md5="([^"]*)">', new))
            defined = dict(re.findall(r'(?s)<SharedString md5="([^"]*)">(.*?)</SharedString>', old))
            extra = ""
            for md5 in sorted(wanted - have):
                if md5 not in defined:
                    print("The old file does not define shared string " + md5)
                    return 1
                extra += '\n\t\t<SharedString md5="%s">%s</SharedString>' % (md5, defined[md5])
            if extra:
                if "</SharedStrings>" in new:
                    at = new.rfind("</SharedStrings>")
                    new = new[:at] + extra + "\n\t" + new[at:]
                else:
                    at = new.rfind("</roblox>")
                    new = new[:at] + "\t<SharedStrings>" + extra + "\n\t</SharedStrings>\n" + new[at:]
        out = os.path.join(scratch, "Spring.rbxlx")
        open(out, "w", encoding="utf-8").write(new)
        ET.parse(out)  # must still be well-formed XML
        if os.path.exists(PLACE):
            shutil.copy2(PLACE, BEFORE)
        shutil.copy2(out, PLACE)
    print("Built build/Spring.rbxlx" + (" with the baked ocean" if terrain else " (no ocean yet: bake it in Studio)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
