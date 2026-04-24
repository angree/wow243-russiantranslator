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

# Mirror of Core.lua LEMMA_RULES. See analyze_forum_coverage.py for the full list.
LEMMA_RULES = [("ами","а"),("ами",""),("ями","я"),("ями",""),("ыми","ый"),("ыми","ой"),("ыми","ые"),("ими","ий"),("ими","ие"),("ого","ый"),("ого","ой"),("его","ий"),("его","ее"),("ому","ый"),("ому","ой"),("ему","ий"),("лись","ться"),("лась","ться"),("лось","ться"),
# Reflexive 3rd-person present (try both -ться and -ть)
("ются","ться"),("ются","ть"),("утся","ться"),("утся","ть"),("атся","аться"),("атся","ать"),("ятся","яться"),("ятся","ять"),("ятся","ить"),
# Reflexive imperative
("йся","ться"),("йтесь","ться"),
# Imperative
("айте","ать"),("яйте","ять"),("ай","ать"),("яй","ять"),("уйте","овать"),("уй","овать"),("ите","ить"),("ите","еть"),
# Irregular stems (помочь family)
("огла","очь"),("огли","очь"),("ёг","ечь"),("егла","ечь"),
# 2sg present
("ешь","ать"),("ешь","еть"),("ишь","ить"),
("ах","а"),("ах",""),("ях","я"),("ях",""),("ам","а"),("ам",""),("ям","я"),("ям",""),("ов",""),("ёв",""),("ев",""),("ей","ь"),("ей",""),("ий","ие"),("ий",""),("ою","а"),("ею","я"),("ой","а"),("ой","ая"),("ем",""),("ом",""),("ём",""),("ая","ый"),("яя","ий"),("ое","ый"),("ее","ий"),("ые","ый"),("ие","ий"),("ую","ая"),("юю","яя"),("ую",""),("ли","ть"),("ла","ть"),("ло","ть"),("лся","ться"),("ют","ть"),("ут","ть"),("ят","ить"),("ат","ать"),("ет","ть"),("ит","ить"),("у","а"),("у",""),("ю","я"),("ю","ь"),("ю",""),("а",""),("я",""),("я","й"),("е","а"),("е","я"),("е","ь"),("е",""),("и","а"),("и","я"),("и","ь"),("и",""),("ы",""),("л","ть"),("й",""),("","а"),("","я"),("","ь")]

def lemmatize(tok, words):
    if len(tok) < 2:
        return None
    for suf, addback in LEMMA_RULES:
        if suf == "" or tok.endswith(suf):
            cand = (tok + addback) if suf == "" else (tok[:-len(suf)] + addback)
            if len(cand) >= 2 and cand in words:
                return words[cand]
    return None


# Perfectivizing prefix stripper — mirrors Core.lua TryPerfectivePrefix.
PERFECTIVIZING_PREFIXES = [
    "перед", "разо", "подо", "надо", "обо", "ото", "изо", "вос",
    "пере", "разу", "пред", "вне", "под", "над", "при", "про",
    "раз", "рас", "воз", "вос", "низ", "нис",
    "вы", "за", "на", "по", "от", "об", "до", "из", "ис", "со",
    "у", "о", "в", "с",
]


def _is_verb_gloss(s):
    if not s:
        return False
    if s.startswith("to ") or s.startswith("I "):
        return True
    if s.endswith(("ing", "ed", "s")):
        return True
    return False


def try_perfective_prefix(tok, words):
    if len(tok) < 4:
        return None
    for pfx in PERFECTIVIZING_PREFIXES:
        if tok.startswith(pfx):
            remainder = tok[len(pfx):]
            if len(remainder) >= 3:
                hit = words.get(remainder)
                if hit and _is_verb_gloss(hit):
                    return hit
                lem = lemmatize(remainder, words)
                if lem and _is_verb_gloss(lem):
                    return lem
    return None

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

# Match every chat format `/chatlog` writes:
#   `[N. ChannelName] Sender: msg`   (Global/Trade/LFG/LocalDefense, any index, any case)
#   `[Guild] Sender: msg`            (Guild / Officer / Party / Raid)
#   `Sender says: msg`               (SAY, including NPC lines — we'll keep Cyrillic-only filter below)
#   `Sender yells: msg`              (YELL)
#   `Sender whispers: msg`           (incoming WHISPER)
LINE_RE = re.compile(
    r"(?:\[\d+\.\s*[A-Za-zА-Яа-я_]+\]|\[(?:Guild|Officer|Party|Raid|Whisper)\])\s*([^:]+):\s*(.+)$"
    r"|^\S+\s+\S+\s+([A-Za-zА-Яа-яЁё][\w'\- ]*)\s+(?:says|yells|whispers):\s*(.+)$"
)

def parse_line(line):
    m = LINE_RE.search(line)
    if not m: return None, None
    if m.group(1):
        return m.group(1), m.group(2)
    return m.group(3), m.group(4)

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
        sender, msg = parse_line(line)
        if not sender or not msg:
            continue
        if not CYR_ANY.search(msg):
            continue
        russian_lines += 1
        low = normalize(msg)
        low = preprocess(low)
        low = apply_phrases(low, phrases_sorted)
        toks = tokenize(low)
        for t in toks:
            total_tokens += 1
            if t in words:
                pass
            elif lemmatize(t, words) is not None:
                pass
            elif try_perfective_prefix(t, words) is not None:
                pass
            else:
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
