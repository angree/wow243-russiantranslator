"""Trim multi-gloss values to their primary sense.

Wiktionary/Kaikki entries often list several senses comma-separated:
   "to get up, to rise, to arise, to stop"
At translation time the addon shows the FULL list — making a 1-word
Russian phrase render as a 6-English-word soup. This script trims each
value to the first sense (parens-aware, so commas INSIDE parens don't
trigger a split).

Applied to: Dictionary.lua, all Dictionary_Forms_NN.lua,
Dictionary_Full_NN.lua, Dictionary_Phrases_NN.lua.

Backup-aware: writes <file>.bak before overwriting in case of regret.
"""
import re, glob, sys, os, shutil
sys.stdout.reconfigure(encoding="utf-8")

DICT_DIR = "RussianTranslator"


def trim_value(v):
    # Walk left-to-right, find the first ", " outside parens. Return prefix.
    depth = 0
    i = 0
    n = len(v)
    while i < n:
        c = v[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif depth == 0 and c == "," and i + 1 < n and v[i + 1] == " ":
            return v[:i].rstrip()
        i += 1
    return v


PAIR = re.compile(r'\["([^"]+)"\]="([^"]*)"')


def process_file(path):
    with open(path, encoding="utf-8") as f:
        src = f.read()

    changes = 0

    def replace(m):
        nonlocal changes
        k, v = m.group(1), m.group(2)
        v2 = trim_value(v)
        if v2 != v:
            changes += 1
        return f'["{k}"]="{v2}"'

    new_src = PAIR.sub(replace, src)
    if changes > 0:
        shutil.copyfile(path, path + ".bak")
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(new_src)
    return changes


def main():
    files = (
        [os.path.join(DICT_DIR, "Dictionary.lua")]
        + sorted(glob.glob(os.path.join(DICT_DIR, "Dictionary_Forms_*.lua")))
        + sorted(glob.glob(os.path.join(DICT_DIR, "Dictionary_Full_*.lua")))
        + sorted(glob.glob(os.path.join(DICT_DIR, "Dictionary_Phrases_*.lua")))
    )
    total = 0
    for f in files:
        c = process_file(f)
        total += c
        print(f"  {os.path.basename(f):35} trimmed: {c:>6}")
    print(f"\nTotal trimmed entries: {total:,}")


if __name__ == "__main__":
    main()
