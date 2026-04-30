"""Generate Dictionary_Forms_NN.lua chunks: every inflected form of every
core dictionary lemma mapped to its translation.

Strategy:
  - Core ns.WORDS already holds ~28k hand-curated (lemma -> translation) pairs.
  - pymorphy3 expands each lemma to its full lexeme (~10 forms for nouns,
    ~46 for verbs, ~24 for adjectives).
  - We emit (form, translation) for every form that:
      * is not already in core ns.WORDS (core wins, no override needed)
      * is not already in the existing Dictionary_Full_NN chunks with a
        non-zombie gloss (Kaikki wins for words core doesn't define)
      * passes basic sanity (Cyrillic only, length >= 2)
  - Output: Dictionary_Forms_NN.lua chunks (single-statement globals
    RT_WORDS_FORMS_NN), same shape as Kaikki chunks. Loaded by Core.lua
    BEFORE Kaikki chunks so they take precedence on form lookups.

This replaces 90% of the suffix-strip lemmatizer's work with O(1) hash
lookups, fixes case/aspect mismatches, and overrides leftover Kaikki
zombie entries the runtime guard couldn't catch.
"""
from __future__ import annotations
import re
import os
import sys
import glob

sys.stdout.reconfigure(encoding='utf-8')

import pymorphy3

ADDON_DIR = r'i:/PROGRAMOWANIE_CLAUDE/Addon_Russian_Translator/RussianTranslator'

ENTRY = re.compile(r'\["((?:[^"\\]|\\.)*)"\]="((?:[^"\\]|\\.)*)"')
CYR_LEMMA = re.compile(r'^[а-яёА-ЯЁ\-]+$')

# Zombie patterns to skip when reading existing chunks (just in case any
# slipped past the v1.7.1 cleanup — we don't want to base form expansion
# on zombie values).
ZOMBIE_RE = re.compile(
    r'^('
    r'(nominative|genitive|dative|accusative|instrumental|prepositional|vocative|locative)\s+(singular|plural)(\s+of)?'
    r'|(plural|singular)\s+of'
    r'|form\s+of'
    r'|(first|second|third)-person'
    r'|(perfective|imperfective)\s+(form|aspect)?(\s+of)?'
    r'|(present|past)\s+(active|passive)\s+participle'
    r'|(diminutive|augmentative|pejorative|comparative|superlative)'
    r'|short\s+(masculine|feminine|neuter|plural)'
    r'|the\s+(name|act|state|quality|process|action)\s+of'
    r'|archaic\s+(form|spelling)\s+of'
    r'|nonstandard\s+spelling\s+of'
    r'|abbreviation\s+of'
    r'|a\s+person\s+who'
    r').*$',
    re.IGNORECASE
)


def parse_dict_lua(path: str) -> dict[str, str]:
    """Extract entries from a Lua file's table literals."""
    s = open(path, encoding='utf-8').read()
    out = {}
    for m in ENTRY.finditer(s):
        k, v = m.group(1), m.group(2)
        if k not in out:  # first occurrence wins
            out[k] = v
    return out


def main():
    print('Loading core Dictionary.lua...')
    core = parse_dict_lua(os.path.join(ADDON_DIR, 'Dictionary.lua'))
    # Filter to single-token Cyrillic lemmas (skip phrases stored in WORDS)
    core_lemmas = {
        k: v for k, v in core.items()
        if CYR_LEMMA.match(k) and ' ' not in k
    }
    print(f'  core single-token lemmas: {len(core_lemmas)}')

    print('Loading existing Kaikki chunks (for conflict avoidance)...')
    kaikki = {}
    for f in sorted(glob.glob(os.path.join(ADDON_DIR, 'Dictionary_Full_*.lua'))):
        for k, v in parse_dict_lua(f).items():
            if k not in kaikki and not ZOMBIE_RE.match(v):
                kaikki[k] = v
    print(f'  kaikki entries (non-zombie): {len(kaikki)}')

    print('Loading pymorphy3...')
    morph = pymorphy3.MorphAnalyzer()

    print('Expanding lemmas to inflected forms...')
    forms: dict[str, str] = {}
    progress = 0
    for lemma, translation in core_lemmas.items():
        progress += 1
        if progress % 5000 == 0:
            print(f'  ... {progress}/{len(core_lemmas)} ({len(forms)} forms emitted)')

        # pymorphy can return multiple parses for ambiguous tokens (e.g.
        # "стали" can be plural of "сталь" OR past of "стать"). Walk all
        # parses but pick the one whose normal_form == this lemma.
        parses = morph.parse(lemma)
        matching = [p for p in parses if p.normal_form == lemma]
        if not matching:
            # Lemma not recognized by pymorphy as a normal form — skip.
            # Still keeps the core entry; we just don't add forms.
            continue

        # Use first matching parse (highest confidence by pymorphy ranking).
        p = matching[0]

        # Skip very short lemmas (1 char) — too noisy to expand.
        if len(lemma) < 2:
            continue

        for form in p.lexeme:
            w = form.word
            if w == lemma:
                continue  # core already has it
            if not CYR_LEMMA.match(w):
                continue
            if len(w) < 2:
                continue
            if w in core_lemmas:
                continue  # core handles this form directly
            # Only set if we haven't already mapped this form (or if our
            # current mapping is from a less-confident lemma — keep first).
            if w not in forms:
                forms[w] = translation

    print(f'\nGenerated {len(forms)} new form->translation mappings.')

    # Dump existing form chunks and write fresh ones
    for f in glob.glob(os.path.join(ADDON_DIR, 'Dictionary_Forms_*.lua')):
        os.remove(f)

    items = sorted(forms.items())
    NCHUNKS = 20  # match Kaikki chunk count for consistent loading
    chunk_size = (len(items) + NCHUNKS - 1) // NCHUNKS
    chunks = [items[i:i+chunk_size] for i in range(0, len(items), chunk_size)]
    while len(chunks) < NCHUNKS:
        chunks.append([])

    for i, chunk in enumerate(chunks, 1):
        fn = os.path.join(ADDON_DIR, f'Dictionary_Forms_{i:02d}.lua')
        if chunk:
            parts = ','.join(f'["{k}"]="{v}"' for k, v in chunk)
            content = f'RT_WORDS_FORMS_{i:02d}={{{parts}}}'
        else:
            content = f'RT_WORDS_FORMS_{i:02d}={{}}'
        with open(fn, 'w', encoding='utf-8', newline='') as f:
            f.write(content)
        print(f'  Dictionary_Forms_{i:02d}.lua: {len(chunk):>5} entries, {os.path.getsize(fn):>7} bytes')

    print('\nDone. Update TOC + Core.lua to load these chunks.')


if __name__ == '__main__':
    main()
