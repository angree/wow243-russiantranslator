"""Conservative in-place cleanup of Dictionary.lua:

Strips purely-grammatical parentheticals from values so they don't leak
into user-facing chat output. Only touches parentheses whose *entire*
content matches known linguist tags. Anything else (e.g. "(Kara boss)",
"(Sethekk Halls)", "(heroic)", "(paid svc)") stays.

Also applies two targeted overrides to fix known translation bugs:
  - босу / боссу  -> "boss"  (not "to boss", which caused "к 4 to boss")
"""
import re, pathlib

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"

# Only grammatical/style tags — these should NEVER appear in user output.
STRIP_TAGS = set()
CASES = ["gen", "acc", "dat", "prep", "inst", "nom"]
GENDER = ["m", "f", "n"]
NUMBER = ["pl", "sg"]
STYLE  = ["slang", "adj", "adv", "imp", "imp pl", "pl imp", "vulgar",
          "dial", "typo", "abbr", "nick", "nick/abbr", "realm", "dim",
          "interj", "particle", "fragment", "frag", "glued", "polite",
          "misspelled", "name", "name fragment", "you fragment",
          "inst pl", "frag)"]
STRIP_TAGS.update(CASES)
STRIP_TAGS.update(GENDER)
STRIP_TAGS.update(NUMBER)
STRIP_TAGS.update(STYLE)
STRIP_TAGS.update(f"{c} pl" for c in CASES)
STRIP_TAGS.update(f"{g} pl" for g in GENDER)
STRIP_TAGS.update(f"{c} {g}" for c in CASES for g in GENDER)
STRIP_TAGS.update(f"{g} {c}" for c in CASES for g in GENDER)
STRIP_TAGS.update(f"{c} past" for c in ["m", "f", "n", "pl"])
STRIP_TAGS.update(f"{g} past" for g in GENDER)
STRIP_TAGS.update([
    "pl past", "past", "past m", "past f", "past pl",
    "vulgar m", "vulgar f", "vulgar pl", "slang short",
    "already", "already?",
    "f misspelled", "acc misspelled", "slang m", "slang f", "slang pl",
    "you", "you pl", "pl you", "you fragment",
    "acc misspelled", "nick/abbr", "nick abbr",
    "m acc", "f acc", "n acc", "pl acc",
    "m dat", "f dat", "n dat", "pl dat",
    "m inst", "f inst", "n inst", "pl inst",
    "m prep", "f prep", "n prep", "pl prep",
    "n gen", "gen pl", "gen f", "gen m",
    "m gen", "pl gen",
    "adj m", "adj f", "adj pl", "adj gen",
    "adj inst", "adj prep",
    "dim", "polite", "particle",
    "you)", "f misspelled)", "acc misspelled)",
    "already?)",
])

def clean_value(v):
    def rep(m):
        inside = m.group(1).strip()
        if inside in STRIP_TAGS:
            return ""
        # also handle slash- or comma-separated tag lists
        parts = re.split(r"[,/]\s*", inside)
        if len(parts) > 1 and all(p.strip() in STRIP_TAGS for p in parts if p.strip()):
            return ""
        return m.group(0)
    v = re.sub(r"\s*\(([^()]+)\)", rep, v)
    v = re.sub(r"\s{2,}", " ", v).strip()
    return v

OVERRIDES = {
    "босу": "boss",
    "боссу": "boss",
}

def main():
    text = DICT.read_text(encoding="utf-8")
    pair_re = re.compile(r'(\["([^"]+)"\]\s*=\s*)"([^"]*)"')
    stripped = [0]
    override_hits = [0]
    def rep(m):
        prefix = m.group(1)
        k = m.group(2).lower()
        val = m.group(3)
        if k in OVERRIDES:
            override_hits[0] += 1
            return f'{prefix}"{OVERRIDES[k]}"'
        new_val = clean_value(val)
        if new_val != val:
            stripped[0] += 1
        return f'{prefix}"{new_val}"'
    text2 = pair_re.sub(rep, text)
    DICT.write_text(text2, encoding="utf-8")
    print(f"Values cleaned: {stripped[0]}")
    print(f"Override fixes: {override_hits[0]}")

if __name__ == "__main__":
    main()
