"""Coverage analysis on Moonwell forum text dumps.

Runs the same phrase→word pipeline as Core.lua/analyze_coverage.py but on
free-flowing prose instead of chat-log lines.

Outputs:
- Per-file token/coverage numbers
- Overall aggregated coverage %
- Top 50 unknown tokens across the corpus (with counts + sample context)
"""
import re, pathlib, collections, sys

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
DICT = ROOT / "RussianTranslator" / "Dictionary.lua"
DUMP = ROOT / "forum_dump"

CU = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
CL = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
TR = str.maketrans(CU, CL)
CYR_ANY = re.compile(r"[а-яёА-ЯЁ]")
TOKEN_RE = re.compile(r"[а-яёА-ЯЁ]+")


def load_dict():
    text = DICT.read_text(encoding="utf-8")
    pair = re.compile(r'\["([^"]+)"\]\s*=\s*"([^"]*)"')
    phrases, words = {}, {}
    for m in pair.finditer(text):
        k = m.group(1).lower()
        (phrases if " " in k else words)[k] = m.group(2)
    return phrases, words


def preprocess(s):
    # Same numeric-suffix preprocessors as Core.lua (word-boundary-aware).
    rules = [
        (r"(\d[\d\.,]*)\s*к(?![а-яёa-z])", r"\1K"),
        (r"(\d[\d\.,]*)\s*г(?![а-яёa-z])", r"\1g"),
        (r"(\d[\d\.,]*)\s*дд(?![а-яёa-z])", r"\1 dps"),
        (r"(\d[\d\.,]*)\s*хил(?![а-яёa-z])", r"\1 healer"),
        (r"(\d[\d\.,]*)\s*танк(?![а-яёa-z])", r"\1 tank"),
        (r"(\d[\d\.,]*)\s*рейт(?![а-яёa-z])", r"\1 rating"),
        (r"(\d[\d\.,]*)\s*мин(?![а-яёa-z])", r"\1 min"),
        (r"(\d[\d\.,]*)\s*сек(?![а-яёa-z])", r"\1 sec"),
        (r"(\d[\d\.,]*)\s*лвл(?![а-яёa-z])", r"\1 lvl"),
    ]
    for p, r in rules:
        s = re.sub(p, r, s)
    return s


def analyze_text(text, phrases_sorted, words):
    """Return (total_tokens, covered_tokens, Counter(unknowns), ctx_dict)."""
    unknowns = collections.Counter()
    ctx = {}
    total = 0
    covered = 0
    # Process paragraph by paragraph so tokenization stays local and context
    # samples are meaningful.
    for para in text.splitlines():
        if not CYR_ANY.search(para):
            continue
        low = preprocess(para.translate(TR).lower())
        # Phrase substitution pass, longest first.
        for k in phrases_sorted:
            if k in low:
                low = low.replace(k, " __PH__ ")
        for tok in TOKEN_RE.findall(low):
            total += 1
            if tok in words:
                covered += 1
            else:
                unknowns[tok] += 1
                if tok not in ctx:
                    ctx[tok] = para.strip()[:110]
    return total, covered, unknowns, ctx


def main():
    phrases, words = load_dict()
    phrases_sorted = sorted(phrases.keys(), key=len, reverse=True)
    print(f"Dictionary: {len(words)} words, {len(phrases)} phrases")
    print()

    grand_total = 0
    grand_covered = 0
    grand_unknowns = collections.Counter()
    grand_ctx = {}

    files = sorted(DUMP.glob("*.txt"))
    print(f"{'Section':<32}{'Tokens':>10}{'Covered':>10}{'Coverage':>12}  Unknown-types")
    print("-" * 80)
    for f in files:
        raw = f.read_bytes().decode("utf-8", errors="replace")
        t, c, u, cx = analyze_text(raw, phrases_sorted, words)
        grand_total += t
        grand_covered += c
        for tok, n in u.items():
            grand_unknowns[tok] += n
            if tok not in grand_ctx:
                grand_ctx[tok] = cx[tok]
        pct = (100.0 * c / t) if t else 0.0
        print(f"{f.name:<32}{t:>10,}{c:>10,}{pct:>11.2f}%{len(u):>10,}")

    print("-" * 80)
    overall = (100.0 * grand_covered / grand_total) if grand_total else 0.0
    print(f"{'TOTAL':<32}{grand_total:>10,}{grand_covered:>10,}{overall:>11.2f}%"
          f"{len(grand_unknowns):>10,}")
    print()
    print(f"Top 50 unknowns (of {len(grand_unknowns)} distinct, "
          f"{sum(grand_unknowns.values())} token occurrences):")
    print()
    for tok, n in grand_unknowns.most_common(50):
        print(f"  {n:>5}  {tok:<22}  | {grand_ctx[tok]}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
