"""Merge forum_chunk_*_translated.txt into Dictionary.lua.

- Skips lines with empty value `""` or SKIP marker.
- Dedups against existing dictionary (keeps existing, skips new).
- Appends to the end of ns.WORDS (for single-token keys) and ns.PHRASES
  (for multi-word keys).
"""
import re, pathlib, sys

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"

# Load existing keys so we don't add duplicates.
text = DICT.read_text(encoding="utf-8")
existing = set()
for m in re.finditer(r'\["([^"]+)"\]\s*=', text):
    existing.add(m.group(1).lower())

# Collect new entries.
merged = []
for p in sorted(ROOT.glob("forum_chunk_*_translated.txt")):
    for line in p.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\["([^"]+)"\]="([^"]*)"', line)
        if not m:
            continue
        k, v = m.group(1), m.group(2)
        if not v or v == "??" or v.startswith("?"):
            continue
        if k.lower() in existing:
            continue
        merged.append((k, v))
        existing.add(k.lower())

words = [(k, v) for k, v in merged if " " not in k]
phrases = [(k, v) for k, v in merged if " " in k]
print(f"New entries to add: {len(words)} words + {len(phrases)} phrases "
      f"= {len(merged)} total")

# Find insertion points.
m_ph = re.search(r"^ns\.PHRASES\s*=\s*\{", text, re.M)
m_wd = re.search(r"^ns\.WORDS\s*=\s*\{", text, re.M)
assert m_ph and m_wd

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

ph_close = find_close(m_ph.end())
wd_close = find_close(m_wd.end())

def fmt(entries, section_label):
    out = [f"\n    -- v1.0.0 forum-prose batch ({section_label})"]
    for k, v in entries:
        k_safe = k.replace('"', '\\"')
        v_safe = v.replace('"', '\\"')
        out.append(f'    ["{k_safe}"]="{v_safe}",')
    return "\n".join(out) + "\n"

# Insert phrases before ns.PHRASES closing brace
if phrases:
    ph_insert = fmt(phrases, "multi-word")
    text = text[:ph_close] + ph_insert + text[ph_close:]
    # ns.WORDS offset shifts by len(ph_insert)
    wd_close += len(ph_insert)

if words:
    wd_insert = fmt(words, "single-token")
    text = text[:wd_close] + wd_insert + text[wd_close:]

DICT.write_text(text, encoding="utf-8")
print("Wrote Dictionary.lua")
