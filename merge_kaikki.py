"""Merge kaikki.org Russian harvest into Dictionary.lua — NON-DESTRUCTIVE.

374k pairs from Wiktionary. Very permissive source so filter hard:
  - Skip if Russian key already exists in dict (WoW translations win)
  - Skip if key starts with dash (`-де`, `-то` — Wiktionary affixes)
  - Skip if English value contains Wiktionary meta-prefixes
  - Cap English value to 40 chars (longer = probably a definition, not a gloss)
  - Skip if key is single-letter or purely punctuation
"""
import re, pathlib, unicodedata

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"
SRC = ROOT / "kaikki_russian.txt"

text = DICT.read_text(encoding="utf-8")
existing = set()
for m in re.finditer(r'\["([^"]+)"\]\s*=', text):
    existing.add(m.group(1).lower())

print(f"Existing: {len(existing)}")

META_PREFIXES = (
    "used to", "alternative form", "plural of", "inflection of",
    "diminutive of", "superlative of", "comparative of", "synonym of",
    "obsolete form", "abbreviation of", "initialism of", "acronym of",
    "name of", "surname", "given name",
)

def strip_accents(s):
    return "".join(c for c in unicodedata.normalize("NFD", s)
                   if unicodedata.category(c) != "Mn")

new_words = []
new_phrases = []
seen = set()

for line in SRC.read_text(encoding="utf-8").splitlines():
    if "|" not in line:
        continue
    ru, en = line.split("|", 1)
    ru = strip_accents(ru.strip().lower())
    en = en.strip()
    if not ru or not en:
        continue
    if ru.startswith("-") or ru.endswith("-"):
        continue  # Wiktionary affix entries
    if len(ru) < 2 or len(ru) > 25:
        continue
    if ru in existing or ru in seen:
        continue
    if not re.search(r"[а-яё]", ru):
        continue
    en_low = en.lower()
    if any(en_low.startswith(p) for p in META_PREFIXES):
        continue
    if len(en) > 40:
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
    block = f"\n    -- v1.5.0 Kaikki.org Wiktionary ingestion ({label})\n"
    for k, v in entries:
        block += f'    ["{k}"]="{v}",\n'
    return text[:i] + block + text[i:]

if new_phrases:
    text = inject(text, "PHRASES", new_phrases, "multi-word")
if new_words:
    text = inject(text, "WORDS", new_words, "single-token")

DICT.write_text(text, encoding="utf-8")
print(f"Wrote {DICT}")
