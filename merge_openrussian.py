"""Merge OpenRussian harvest into Dictionary.lua — NON-DESTRUCTIVE.

Existing WoW-specific entries (slang, shorthand, item names) are kept
untouched. OpenRussian entries fill gaps only.

Rules:
- If a key already exists in ns.WORDS or ns.PHRASES, skip (WoW wins).
- Strip combining acute accents (U+0301) from Russian keys.
- Lowercase keys.
- Replace `|` in English values (defensive — they can break Lua parse).
- Multi-word keys → ns.PHRASES, single-word → ns.WORDS.
- Skip entries where English is empty or the Russian key would also
  already be produced by lemmatization from an existing key (soft-
  overwrite avoidance: e.g. `персонаж` already covered; don't dilute
  with OpenRussian variant).
"""
import re, pathlib, unicodedata

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"

text = DICT.read_text(encoding="utf-8")
existing = set()
for m in re.finditer(r'\["([^"]+)"\]\s*=', text):
    existing.add(m.group(1).lower())

print(f"Existing keys: {len(existing)}")

# Collect OpenRussian harvest.
new_words = []
new_phrases = []
seen = set()

def strip_accents(s):
    # Strip combining acute (U+0301) and other combining marks from
    # Russian words. Keep Cyrillic base letters + ё.
    nfd = unicodedata.normalize("NFD", s)
    return "".join(ch for ch in nfd if unicodedata.category(ch) != "Mn")

for i in range(1, 6):
    p = ROOT / f"openrussian_{i}.txt"
    if not p.exists():
        print(f"missing {p}")
        continue
    for line in p.read_text(encoding="utf-8").splitlines():
        if "|" not in line:
            continue
        ru, en = line.split("|", 1)
        ru = strip_accents(ru.strip().lower())
        en = en.strip().replace("|", "/").replace('"', "'")
        if not ru or not en:
            continue
        if ru in existing or ru in seen:
            continue
        # Filter out garbage tokens (single chars, only digits, etc.)
        if len(ru) < 2:
            continue
        if not re.search(r"[а-яё]", ru):
            continue
        seen.add(ru)
        if " " in ru:
            new_phrases.append((ru, en))
        else:
            new_words.append((ru, en))

print(f"New: {len(new_words)} words, {len(new_phrases)} phrases")

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
    block = f"\n    -- v1.2.0 OpenRussian fill-in ({label})\n"
    for k, v in entries:
        block += f'    ["{k}"]="{v}",\n'
    return text[:i] + block + text[i:]

if new_phrases:
    text = inject(text, "PHRASES", new_phrases, "multi-word")
if new_words:
    text = inject(text, "WORDS", new_words, "single-token")

DICT.write_text(text, encoding="utf-8")
print(f"Wrote {DICT}")
