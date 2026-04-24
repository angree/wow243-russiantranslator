"""Merge forum_res_merged.txt into Dictionary.lua (WORDS table only)."""
import re, pathlib

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"
SRC = ROOT / "forum_res_merged.txt"

text = DICT.read_text(encoding="utf-8")
existing = set()
for m in re.finditer(r'\["([^"]+)"\]\s*=', text):
    existing.add(m.group(1).lower())

new_entries = []
seen = set()
for line in SRC.read_text(encoding="utf-8").splitlines():
    m = re.match(r'\["([^"]+)"\]="([^"]*)"', line)
    if not m:
        continue
    k, v = m.group(1), m.group(2)
    k_low = k.lower()
    if not v or k_low in existing or k_low in seen:
        continue
    if " " in k:
        continue  # skip phrases, focus on WORDS
    seen.add(k_low)
    new_entries.append((k, v))

print(f"Adding {len(new_entries)} new entries to ns.WORDS")

# Find WORDS close brace.
m_wd = re.search(r"^ns\.WORDS\s*=\s*\{", text, re.M)
depth = 1
i = m_wd.end()
while i < len(text):
    if text[i] == "{": depth += 1
    elif text[i] == "}":
        depth -= 1
        if depth == 0: break
    i += 1

inject = "\n    -- v1.1.0 residual-after-lemmatization batch\n"
for k, v in new_entries:
    k_safe = k.replace('"', '\\"')
    v_safe = v.replace('"', '\\"')
    inject += f'    ["{k_safe}"]="{v_safe}",\n'

text = text[:i] + inject + text[i:]
DICT.write_text(text, encoding="utf-8")
print(f"Wrote {DICT}")
