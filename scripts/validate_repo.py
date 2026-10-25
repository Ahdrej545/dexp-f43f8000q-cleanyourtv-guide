#!/usr/bin/env python3
"""Static repository checks; no TV connection or device changes."""
from __future__ import annotations

import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []
json_files = sorted((ROOT / "examples").rglob("*.json"))

def fail(message: str) -> None:
    errors.append(message)

for path in json_files:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{path.relative_to(ROOT)}: invalid JSON ({exc})")
        continue
    if not isinstance(data, dict):
        fail(f"{path.relative_to(ROOT)}: config root must be an object")
        continue
    for key in ("dock_apps", "hidden_apps"):
        if key in data and (not isinstance(data[key], list) or not all(isinstance(item, str) for item in data[key])):
            fail(f"{path.relative_to(ROOT)}: {key} must be an array of strings")
    for key in ("wallpaper", "reduced_motion", "show_stats", "app_glow", "dock_glass"):
        if key in data and not isinstance(data[key], bool):
            fail(f"{path.relative_to(ROOT)}: {key} must be boolean")
    if "columns" in data and (not isinstance(data["columns"], int) or not 1 <= data["columns"] <= 8):
        fail(f"{path.relative_to(ROOT)}: columns must be an integer from 1 to 8")
    if "background_color" in data and not re.fullmatch(r"#[0-9A-Fa-f]{6}", str(data["background_color"])):
        fail(f"{path.relative_to(ROOT)}: background_color must be #RRGGBB")

svg_files = sorted((ROOT / "assets").rglob("*.svg"))
for path in svg_files:
    try:
        root = ET.fromstring(path.read_text(encoding="utf-8"))
        if not root.tag.endswith("svg"):
            fail(f"{path.relative_to(ROOT)}: root element is not SVG")
    except Exception as exc:
        fail(f"{path.relative_to(ROOT)}: invalid SVG/XML ({exc})")

# Audit every Markdown file, including the changelog and security policy.
markdown_files = sorted(ROOT.rglob("*.md"))
link_re = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
for md in markdown_files:
    if not md.exists():
        continue
    text = md.read_text(encoding="utf-8")
    for raw_target in link_re.findall(text):
        target = raw_target.strip().split()[0].strip("<>")
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc or target.startswith("#") or not parsed.path:
            continue
        local_path = (md.parent / parsed.path).resolve()
        try:
            local_path.relative_to(ROOT.resolve())
        except ValueError:
            fail(f"{md.relative_to(ROOT)}: link escapes repository: {target}")
            continue
        if not local_path.exists():
            fail(f"{md.relative_to(ROOT)}: missing local link target: {target}")

if sys.platform != "win32" and subprocess.run(["bash", "-n", str(ROOT / "scripts" / "tv-menu.sh")], capture_output=True).returncode != 0:
    result = subprocess.run(["bash", "-n", str(ROOT / "scripts" / "tv-menu.sh")], capture_output=True, text=True)
    fail(f"scripts/tv-menu.sh: bash syntax error: {result.stderr.strip()}")

# Scan all repository text files for the example owner's network identifiers and
# unsafe generic commands. Binary screenshots are excluded; SVG remains text-scanned.
for file in ROOT.rglob("*"):
    if not file.is_file() or ".git" in file.parts:
        continue
    if file.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".ico"}:
        continue
    try:
        text_content = file.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    # This validator contains the patterns it searches for, so exclude only its own source.
    if file.resolve() == Path(__file__).resolve():
        continue
    rel = file.relative_to(ROOT).as_posix()
    if "192.168.1.107" in text_content or "Keenetic-6281" in text_content:
        fail(f"{rel}: possible private network identifier found")
    if re.search(r"adb\s+shell\s+pm\s+disable-user.*com\.yandex\.tv\.home", text_content):
        fail(f"{rel}: do not recommend disabling the stock launcher generically")

if errors:
    print("Repository validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print(f"Repository validation passed: {len(json_files)} JSON files, {len(svg_files)} SVG files, local Markdown links, and Bash syntax.")
