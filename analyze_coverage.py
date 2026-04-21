"""Coverage analyzer for WoWChatLog Russian lines against Dictionary.lua.

Mirrors the Core.lua pipeline:
  - normalize (UTF-8 assumed in log file)
  - lowercase (Cyrillic-aware)
  - numeric-suffix preprocessors
  - Slavic smileys (ignored for coverage purposes)
  - phrase matching (longest first)
  - token-by-token word matching
"""
import re, sys, io, collections, pathlib

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"
LOG  = ROOT / "WoWChatLog_latest.txt"

def load_dict():
    text = DICT.read_text(encoding="utf-8")
    # Grab WORDS and PHRASES literals
    phrases = {}
    words = {}
    # Find all ["key"]="value" occurrences inside ns.WORDS / ns.PHRASES.
    # Simpler: just pick up every ["..."]="..." pair in the file, then classify
    # by whether the key contains a space.
    pair_re = re.compile(r'\["([^"]+)"\]\s*=\s*"([^"]*)"')
    for m in pair_re.finditer(text):
        k, v = m.group(1), m.group(2)
        k_low = k.lower()
        if " " in k_low:
            phrases[k_low] = v
        else:
            words[k_low] = v
    return phrases, words

CYR_UPPER = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
CYR_LOWER = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
TR = str.maketrans(CYR_UPPER, CYR_LOWER)

def normalize(s):
    return s.translate(TR).lower()

def preprocess(s):
    # (num)к/г/дд/хил/танк/рейт/мин/сек/лвл with word-boundary guard
    s = re.sub(r"(\d[\d\.,]*)\s*к(?![а-яёa-z])", r"\1K", s)
    s = re.sub(r"(\d[\d\.,]*)\s*г(?![а-яёa-z])", r"\1g", s)
    s = re.sub(r"(\d[\d\.,]*)\s*дд(?![а-яёa-z])", r"\1 dps", s)
    s = re.sub(r"(\d[\d\.,]*)\s*хил(?![а-яёa-z])", r"\1 healer", s)
    s = re.sub(r"(\d[\d\.,]*)\s*танк(?![а-яёa-z])", r"\1 tank", s)
    s = re.sub(r"(\d[\d\.,]*)\s*рейт(?![а-яёa-z])", r"\1 rating", s)
    s = re.sub(r"(\d[\d\.,]*)\s*мин(?![а-яёa-z])", r"\1 min", s)
    s = re.sub(r"(\d[\d\.,]*)\s*сек(?![а-яёa-z])", r"\1 sec", s)
    s = re.sub(r"(\d[\d\.,]*)\s*лвл(?![а-яёa-z])", r"\1 lvl", s)
    return s

TOKEN_RE = re.compile(r"[а-яёА-ЯЁ]+")
CYR_ANY = re.compile(r"[а-яёА-ЯЁ]")

def tokenize(s):
    return TOKEN_RE.findall(s)

def apply_phrases(s, phrases_sorted):
    for key in phrases_sorted:
        if key in s:
            s = s.replace(key, " __PH__ ")
    return s

LINE_RE = re.compile(r"\[6\. Global\] ([^:]+): (.+)$")

def main():
    phrases, words = load_dict()
    phrases_sorted = sorted(phrases.keys(), key=len, reverse=True)
    print(f"dict: {len(words)} words, {len(phrases)} phrases")

    total_tokens = 0
    unknown_ctr = collections.Counter()
    unknown_ctx = {}
    russian_lines = 0

    # read log (it's CP1251 or UTF-8? try UTF-8 first, fallback cp1251)
    raw = LOG.read_bytes().decode("utf-8", errors="replace")

    for line in raw.splitlines():
        m = LINE_RE.search(line)
        if not m:
            continue
        sender, msg = m.group(1), m.group(2)
        if not CYR_ANY.search(msg):
            continue
        russian_lines += 1
        low = normalize(msg)
        low = preprocess(low)
        low = apply_phrases(low, phrases_sorted)
        toks = tokenize(low)
        for t in toks:
            total_tokens += 1
            if t not in words:
                unknown_ctr[t] += 1
                if t not in unknown_ctx:
                    unknown_ctx[t] = msg.strip()[:110]

    covered = total_tokens - sum(unknown_ctr.values())
    pct = 100.0 * covered / total_tokens if total_tokens else 0
    print(f"russian lines: {russian_lines}")
    print(f"cyrillic tokens: {total_tokens}, covered: {covered} ({pct:.2f}%)")
    print(f"distinct unknown: {len(unknown_ctr)}")
    print()
    print("all unknowns:")
    for t, c in unknown_ctr.most_common():
        print(f"  {c:>4}  {t:<20}  | {unknown_ctx[t]}")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
