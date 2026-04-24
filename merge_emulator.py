"""Merge emulator_db.txt (TBC ruRU→enUS from cmangos/tbc-db) into
Dictionary.lua — NON-DESTRUCTIVE, PHRASES-priority (WoW names are usually
multi-word).
"""
import re, pathlib

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"
SRC = ROOT / "emulator_db.txt"

text = DICT.read_text(encoding="utf-8")
existing = set()
for m in re.finditer(r'\["([^"]+)"\]\s*=', text):
    existing.add(m.group(1).lower())

print(f"Existing: {len(existing)}")

new_words = []
new_phrases = []
seen = set()

for line in SRC.read_text(encoding="utf-8").splitlines():
    if "|" not in line:
        continue
    ru, en = line.split("|", 1)
    ru = ru.strip().lower()
    en = en.strip()
    if not ru or not en:
        continue
    if len(ru) < 2 or len(ru) > 80:
        continue
    if ru in existing or ru in seen:
        continue
    if not re.search(r"[а-яё]", ru):
        continue
    if '"' in en:
        en = en.replace('"', "'")
    seen.add(ru)
    if " " in ru:
        new_phrases.append((ru, en))
    else:
        new_words.append((ru, en))

print(f"New: {len(new_words)} words + {len(new_phrases)} phrases")


def inject(text, section, entries, label):
    m = re.search(rf"^ns\.{section}\s*=\s*\{{", text, re.M)
    depth = 1
    i = m.end()
    while i < len(text):
        if text[i] == "{": depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0: break
        i += 1
    block = f"\n    -- v1.5.0 cmangos/tbc-db WoW-specific names ({label})\n"
    for k, v in entries:
        block += f'    ["{k}"]="{v}",\n'
    return text[:i] + block + text[i:]

if new_phrases:
    text = inject(text, "PHRASES", new_phrases, "multi-word item/creature/quest names")
if new_words:
    text = inject(text, "WORDS", new_words, "single-token")

DICT.write_text(text, encoding="utf-8")
print(f"Wrote {DICT}")
