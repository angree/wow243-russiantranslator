"""Rewrite Dictionary_Full chunks to top-level global pattern.

Chunks become single-statement files:
    RT_WORDS_EXTRA_NN={...}
    RT_PHRASES_EXTRA_NN={...}
Core.lua merges these globals into ns.WORDS_EXTRA / ns.PHRASES_EXTRA at startup.
No dependency on RussianTranslatorNS existing when chunk loads.
"""
import re, os, sys
sys.stdout.reconfigure(encoding='utf-8')

# Source: deployed chunks in WoW folder (known good state).
SRC_ROOT = r'C:/Gry/World of WarcraftOLD/Interface/AddOns/RussianTranslator'
DST_ROOT = r'i:/PROGRAMOWANIE_CLAUDE/Addon_Russian_Translator/RussianTranslator'

ENTRY = re.compile(r'\["((?:[^"\\]|\\.)*)"\]="((?:[^"\\]|\\.)*)"')

words_all = []
phrases_all = []

# Read Dictionary_Full_NN.lua — any single-statement or multi-statement format works.
for name in sorted(os.listdir(SRC_ROOT)):
    if not name.endswith('.lua'):
        continue
    if not (name.startswith('Dictionary_Full_') or name.startswith('Dictionary_Phrases_')):
        continue
    p = os.path.join(SRC_ROOT, name)
    s = open(p, encoding='utf-8').read()
    is_phrase = name.startswith('Dictionary_Phrases_')
    for m in ENTRY.finditer(s):
        k, v = m.group(1), m.group(2)
        if k.startswith('__chunk_'):
            continue
        if is_phrase:
            phrases_all.append((k, v))
        else:
            words_all.append((k, v))

seen = set(); words = []
for k, v in words_all:
    if k in seen:
        continue
    seen.add(k); words.append((k, v))
seen = set(); phrases = []
for k, v in phrases_all:
    if k in seen:
        continue
    seen.add(k); phrases.append((k, v))

print(f'Extracted: {len(words)} unique words, {len(phrases)} unique phrases')

def split(lst, n):
    k = (len(lst) + n - 1) // n
    return [lst[i * k:(i + 1) * k] for i in range(n)]

NW = 20
NP = 5
w_chunks = split(words, NW)
p_chunks = split(phrases, NP)

for name in os.listdir(DST_ROOT):
    if name.startswith('Dictionary_Full_') or name.startswith('Dictionary_Phrases_'):
        os.remove(os.path.join(DST_ROOT, name))

for i, chunk in enumerate(w_chunks, 1):
    fn = os.path.join(DST_ROOT, f'Dictionary_Full_{i:02d}.lua')
    parts = ','.join(f'["{k}"]="{v}"' for k, v in chunk)
    with open(fn, 'w', encoding='utf-8', newline='') as f:
        f.write(f'RT_WORDS_EXTRA_{i:02d}={{{parts}}}')
    print(f'  Dictionary_Full_{i:02d}.lua: {len(chunk)} entries, {os.path.getsize(fn)} bytes')

for i, chunk in enumerate(p_chunks, 1):
    fn = os.path.join(DST_ROOT, f'Dictionary_Phrases_{i:02d}.lua')
    parts = ','.join(f'["{k}"]="{v}"' for k, v in chunk)
    with open(fn, 'w', encoding='utf-8', newline='') as f:
        f.write(f'RT_PHRASES_EXTRA_{i:02d}={{{parts}}}')
    print(f'  Dictionary_Phrases_{i:02d}.lua: {len(chunk)} entries, {os.path.getsize(fn)} bytes')
