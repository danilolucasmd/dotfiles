#!/usr/bin/env python3
"""Regenerate ../data/emoji.json, the emoji picker's whole dataset.

Run by hand, not by the shell: the panel reads the generated JSON and never
this script. It is checked in so the data can be rebuilt when Unicode ships a
new emoji release (or when the emoji font is swapped for one with different
coverage), rather than the JSON being an opaque blob nobody can reproduce.

    ./gen-emoji-data.py            # needs network; writes ../data/emoji.json

Three sources, all fetched fresh:

  emoji-test.txt      the emoji themselves, already in CLDR order -- which is
                      the order every emoji keyboard uses, macOS included, and
                      the whole reason this file exists. elephant's `symbols`
                      provider, which super+E reached before this, sorted
                      alphabetically by name -- so an empty query opened on
                      medals and abacuses.
  annotations/en.xml  CLDR search keywords ("lol", "joy" -> face with tears of
                      joy). Names alone make for a picker where nothing but the
                      official noun finds anything.
  annotationsDerived  the same keywords for sequences (ZWJ, flags, keycaps),
                      which CLDR keeps in a second file.

Coverage is checked against the emoji font fontconfig would actually pick, so
an emoji this machine can only draw as tofu never reaches the grid. Sequences
are kept when every code point in them is covered -- a ZWJ sequence the font
has no ligature for degrades into its parts, which is ugly but legible, where a
missing code point is a blank box.
"""

import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

EMOJI_TEST = "https://unicode.org/Public/emoji/latest/emoji-test.txt"
CLDR = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/en.xml"
CLDR_DERIVED = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotationsDerived/en.xml"

# Unicode's ten groups, folded into the eight tabs macOS shows and in macOS's
# order -- which differs from the file's in two places: the two people groups
# are one tab there, and Activity comes before Travel & Places.
CATEGORIES = [
    ("Smileys & People", ["Smileys & Emotion", "People & Body"]),
    ("Animals & Nature", ["Animals & Nature"]),
    ("Food & Drink", ["Food & Drink"]),
    ("Activity", ["Activities"]),
    ("Travel & Places", ["Travel & Places"]),
    ("Objects", ["Objects"]),
    ("Symbols", ["Symbols"]),
    ("Flags", ["Flags"]),
]

def fetch(url: str) -> str:
    with urllib.request.urlopen(url) as r:
        return r.read().decode("utf-8")


def font_codepoints() -> set[int]:
    """Every code point the emoji font fontconfig resolves can draw."""
    path = subprocess.run(
        ["fc-match", "-f", "%{file}", "emoji"], capture_output=True, text=True, check=True
    ).stdout
    charset = subprocess.run(
        ["fc-query", "-f", "%{charset}", path], capture_output=True, text=True, check=True
    ).stdout

    out: set[int] = set()
    for token in charset.split():
        if "-" in token:
            lo, hi = token.split("-")
            out.update(range(int(lo, 16), int(hi, 16) + 1))
        else:
            out.add(int(token, 16))
    return out


def keywords() -> dict[str, str]:
    """emoji -> space-joined CLDR search keywords.

    CLDR strips U+FE0F from the `cp` attribute, so every lookup has to be tried
    both ways; the keys here are stored without it and the caller normalises.
    """
    out: dict[str, str] = {}
    pattern = re.compile(r'<annotation cp="([^"]+)"(?: type="tts")?>([^<]*)</annotation>')
    for url in (CLDR, CLDR_DERIVED):
        for cp, body in pattern.findall(fetch(url)):
            # The tts variant is the spoken name, which is the name we already
            # have from emoji-test.txt; only the keyword lists are new here.
            if "|" not in body and cp in out:
                continue
            words = [w.strip() for w in body.split("|") if w.strip()]
            joined = " ".join(words)
            out[cp] = f"{out[cp]} {joined}".strip() if cp in out else joined
    return out


def main() -> int:
    covered = font_codepoints()
    kw = keywords()

    version = ""
    group = ""
    buckets: dict[str, list[dict]] = {}
    dropped = 0

    line_re = re.compile(r"^([0-9A-F ]+?)\s*;\s*fully-qualified\s*#\s*(\S+)\s+E\d+\.\d+\s+(.*)$")

    for line in fetch(EMOJI_TEST).splitlines():
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if line.startswith("# Version:"):
            version = line.split(":", 1)[1].strip()
            continue
        if not line or line.startswith("#"):
            continue

        m = line_re.match(line)
        if not m:
            continue
        codes, glyph, name = m.groups()

        # Skin tone and hair variants are components of an emoji already in the
        # grid, not emoji of their own: keeping them would triple the list and
        # bury the base glyph, which is exactly what macOS avoids by hiding
        # them behind a long press.
        if "skin tone" in name:
            continue
        # The Component group is nothing but those modifiers in isolation.
        if group == "Component":
            continue

        if not all(int(c, 16) in covered for c in codes.split()):
            dropped += 1
            continue

        entry = {"c": glyph, "n": name}
        k = kw.get(glyph) or kw.get(glyph.replace("️", ""))
        if k:
            entry["k"] = k
        buckets.setdefault(group, []).append(entry)

    categories = []
    for label, groups in CATEGORIES:
        emoji: list[dict] = []
        for g in groups:
            emoji.extend(buckets.get(g, []))
        if emoji:
            categories.append({"name": label, "emoji": emoji})

    out = Path(__file__).resolve().parent.parent / "data" / "emoji.json"
    out.write_text(
        json.dumps({"version": version, "categories": categories}, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    total = sum(len(c["emoji"]) for c in categories)
    print(f"emoji {version}: wrote {total} to {out} ({dropped} dropped, font has no glyph)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
