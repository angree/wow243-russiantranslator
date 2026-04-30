"""Mine high-frequency Russian bigrams/trigrams from chat logs, translate
through Argos NMT (with sentence template trick to give the model context),
and emit candidate PHRASES entries to review.

Strategy:
  - Pool every WoWChatLog*.txt + the live log
  - Extract Russian-only bigrams + trigrams from chat-line bodies
  - Frequency-filter (>= MIN_FREQ across the whole pool)
  - Skip phrases already in core ns.PHRASES or ns.PHRASES_EXTRA
  - Translate each via Argos: wrap in template "Я говорю: <phrase>" then
    strip "I'm saying:" prefix from output
  - Heuristic-filter low-quality outputs (echoed back, single-word, too long)
  - Write candidates to phrase_candidates.txt for manual review

Output format: one candidate per line, separated by ` | `:
  freq | russian | english_translation
"""
from __future__ import annotations
import re
import os
import sys
import glob
from collections import Counter

sys.stdout.reconfigure(encoding='utf-8')

import argostranslate.translate

ROOT = r'i:/PROGRAMOWANIE_CLAUDE/Addon_Russian_Translator'
ADDON_DIR = os.path.join(ROOT, 'RussianTranslator')
OUT_PATH = os.path.join(ROOT, 'phrase_candidates.txt')

MIN_FREQ = 3       # how many times a phrase must appear in the corpus
MIN_LEN_CYR = 2    # tokens per phrase (2=bigram, 3=trigram)
MAX_LEN_CYR = 4    # cap at 4-grams to limit explosion
TOP_N = 800        # only translate top-N most frequent (Argos batch budget)

CYR_TOKEN = re.compile(r'[а-яёА-ЯЁ]+')
CHAT_BODY = re.compile(r'\[\d+\.\s*\S+\]\s*[^:]+:\s*(.+)')

ENTRY = re.compile(r'\["((?:[^"\\]|\\.)*)"\]="(?:[^"\\]|\\.)*"')


def load_existing_phrases() -> set[str]:
    seen = set()
    s = open(os.path.join(ADDON_DIR, 'Dictionary.lua'), encoding='utf-8').read()
    for m in ENTRY.finditer(s):
        if ' ' in m.group(1):
            seen.add(m.group(1).lower())
    for f in glob.glob(os.path.join(ADDON_DIR, 'Dictionary_Phrases_*.lua')):
        s = open(f, encoding='utf-8').read()
        for m in ENTRY.finditer(s):
            if ' ' in m.group(1):
                seen.add(m.group(1).lower())
    return seen


def extract_messages() -> list[str]:
    """Pull every Russian-containing chat-body line from every log file."""
    msgs = set()
    sources = sorted(glob.glob(os.path.join(ROOT, 'WoWChatLog*.txt')))
    sources.append(r'C:/Gry/World of WarcraftOLD/Logs/WoWChatLog.txt')
    for f in sources:
        if not os.path.exists(f):
            continue
        try:
            text = open(f, encoding='utf-8', errors='replace').read()
        except Exception:
            continue
        for line in text.splitlines():
            m = CHAT_BODY.search(line)
            if m and CYR_TOKEN.search(m.group(1)):
                msgs.add(m.group(1).strip().lower())
    return list(msgs)


def mine_ngrams(messages: list[str], existing: set[str]) -> Counter:
    """Build bigram/trigram/4-gram counter over Cyrillic-only word sequences."""
    counts: Counter = Counter()
    for body in messages:
        toks = [t for t in CYR_TOKEN.findall(body) if len(t) >= 2]
        for n in range(MIN_LEN_CYR, MAX_LEN_CYR + 1):
            for i in range(len(toks) - n + 1):
                phrase = ' '.join(toks[i:i + n])
                if phrase in existing:
                    continue
                if len(phrase) > 60:  # skip overlong
                    continue
                counts[phrase] += 1
    # Filter under-frequency threshold
    return Counter({p: c for p, c in counts.items() if c >= MIN_FREQ})


def translate_batch(phrases: list[tuple[str, int]]) -> list[tuple[str, int, str]]:
    """Run each phrase through Argos via a sentence template, return english."""
    inst = argostranslate.translate.get_installed_languages()
    ru = next(l for l in inst if l.code == 'ru')
    en = next(l for l in inst if l.code == 'en')
    tr = ru.get_translation(en)

    out = []
    for i, (phrase, freq) in enumerate(phrases, 1):
        if i % 50 == 0:
            print(f'  ... translated {i}/{len(phrases)}')
        # Template trick: give the model a full-sentence context so it
        # disambiguates word forms / parses inflection correctly.
        templated = f'Я говорю: {phrase}.'
        try:
            raw = tr.translate(templated)
        except Exception as e:
            print(f'  err on {phrase!r}: {e}')
            continue
        # Strip the template prefix (case-insensitive, allow variants)
        cleaned = re.sub(r'^(I\s*[\'"]?\s*m?\s*say(?:ing)?[:.,]?\s*|I\s*say[:.,]?\s*)',
                         '', raw, flags=re.IGNORECASE).strip()
        cleaned = cleaned.rstrip('.!? ')
        cleaned = cleaned.strip('"\'')
        if not cleaned:
            continue
        # Quality filters
        if len(cleaned) < 2:
            continue
        if cleaned.lower() == phrase.lower():
            continue  # echoed back
        # If output has Cyrillic, model failed
        if re.search(r'[а-яёА-ЯЁ]', cleaned):
            continue
        out.append((phrase, freq, cleaned))
    return out


def main():
    print('Loading existing phrases...')
    existing = load_existing_phrases()
    print(f'  {len(existing)} existing phrases.')

    print('Extracting unique messages from logs...')
    messages = extract_messages()
    print(f'  {len(messages)} unique Russian messages.')

    print('Mining n-grams...')
    counts = mine_ngrams(messages, existing)
    print(f'  {len(counts)} n-grams above freq>={MIN_FREQ}.')

    top = counts.most_common(TOP_N)
    print(f'  Translating top {len(top)} via Argos NMT...')
    translated = translate_batch(top)
    print(f'  {len(translated)} survived quality filter.')

    # Sort by frequency desc
    translated.sort(key=lambda x: -x[1])
    with open(OUT_PATH, 'w', encoding='utf-8', newline='') as f:
        for phrase, freq, en in translated:
            f.write(f'{freq}\t{phrase}\t{en}\n')
    print(f'\nWrote {OUT_PATH} with {len(translated)} candidates.')
    print('First 30:')
    for phrase, freq, en in translated[:30]:
        print(f'  {freq:3} | {phrase:35} | {en}')


if __name__ == '__main__':
    main()
