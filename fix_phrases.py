"""One-shot: move all multi-word `["key with space"]="val"` entries that
landed inside ns.WORDS back into ns.PHRASES (where they actually work).

Preserves comments, formatting, and single-word entries. Runs once.
"""
import re, pathlib

DICT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\Dictionary.lua")

text = DICT.read_text(encoding="utf-8")

# Locate the start/end lines of both tables.
m_ph_start = re.search(r"^ns\.PHRASES\s*=\s*\{", text, flags=re.M)
m_wd_start = re.search(r"^ns\.WORDS\s*=\s*\{", text, flags=re.M)
assert m_ph_start and m_wd_start

ph_open = m_ph_start.end()
wd_open = m_wd_start.end()

# Find the closing `}` of each table.
def find_close(start):
    depth = 1
    i = start
    while i < len(text):
        c = text[i]
        if c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0: return i
        i += 1
    raise RuntimeError("unbalanced")

ph_close = find_close(ph_open)
wd_close = find_close(wd_open)

ph_body = text[ph_open:ph_close]
wd_body = text[wd_open:wd_close]

# Find all multi-word entries in WORDS body (keys containing a space).
# Match complete lines so we can drop them cleanly.
pattern = re.compile(r'^[ \t]*\["([^"]* [^"]*)"\]\s*=\s*"[^"]*"\s*,?\s*(?:--[^\n]*)?\n', re.M)
moved = []
def drop(m):
    moved.append(m.group(0))
    return ""

new_wd_body = pattern.sub(drop, wd_body)
print(f"Moved {len(moved)} multi-word entries from WORDS to PHRASES.")

if moved:
    injection = "\n    -- Auto-moved from ns.WORDS (v0.9.7 phrases that landed in the wrong table)\n"
    injection += "".join(moved)
    # Insert right before the closing `}` of PHRASES, preserving its trailing whitespace/newline.
    # Need to find the indentation before `}`.
    new_ph_body = ph_body.rstrip() + "\n" + injection + "\n"
    new_text = (
        text[:ph_open] + new_ph_body
        + text[ph_close:wd_open] + new_wd_body
        + text[wd_close:]
    )
    DICT.write_text(new_text, encoding="utf-8")
    print(f"Rewrote {DICT}")
