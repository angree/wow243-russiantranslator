"""Strip linguist-annotation zombies from Kaikki chunks.

Reads current Dictionary_Full_NN.lua + Dictionary_Phrases_NN.lua, drops every
entry whose value is a bare grammatical descriptor ("accusative singular of",
"genitive plural of", "second-person plural imperative", etc.), and writes
fresh single-statement chunks back.

Anything dropped here is a form the lemmatizer in Core.lua can re-derive from
its base form anyway, so we lose nothing useful.
"""
import re, os, sys
sys.stdout.reconfigure(encoding='utf-8')

ROOT = r'i:/PROGRAMOWANIE_CLAUDE/Addon_Russian_Translator/RussianTranslator'

# Patterns that match a value made entirely of grammatical metadata.
# Any value matching ANY of these regexes (full match, anchored) gets dropped.
ZOMBIE_PATTERNS = [
    # Case + number + "of"
    r'(nominative|genitive|dative|accusative|instrumental|prepositional|vocative|locative)\s+(singular|plural)(\s+of)?',
    # Just "plural/singular of" or "form of"
    r'(plural|singular)\s+of',
    r'form\s+of',
    # Verb person/number/tense
    r'(first|second|third)-person\s+(singular|plural)\s+(present|past|future|imperative|conditional|subjunctive)(\s+(active|passive))?(\s+(indicative|of))?',
    # Tense / aspect markers
    r'(past|present|future)\s+(tense|active|passive)(\s+(participle|adverbial|of))?',
    r'(perfective|imperfective)\s+(form|aspect)?(\s+of)?',
    # Participles / gerunds
    r'(present|past)\s+(active|passive)\s+participle(\s+of)?',
    r'(participle|gerund|infinitive)(\s+of)?',
    # Imperative / conditional standalone
    r'(imperative|conditional|subjunctive)(\s+(form|of))?',
    r'(first|second|third)-person\s+(imperative|conditional)',
    r'(plural|singular)\s+(imperative|conditional)',
    r'(second-person)\s+(plural|singular)\s+(imperative|conditional)?',
    # Diminutives / augmentatives / etc.
    r'(diminutive|augmentative|pejorative|hypocoristic|patronymic)(\s+(form|of))?',
    # Comparatives / superlatives
    r'(comparative|superlative)(\s+(form|degree|of))?',
    # Verbal noun
    r'verbal\s+noun(\s+of)?',
    # Short forms
    r'short\s+(masculine|feminine|neuter|plural)(\s+singular)?(\s+of)?',
    r'(masculine|feminine|neuter)\s+(short|past|of)(\s+(form|of))?',
    r'short\s+(past|present|active|passive)(\s+(participle|of))?',
    # Gender-only metadata
    r'(masculine|feminine|neuter)\s+of',
    # Past tense indicative variants
    r'(masculine|feminine|neuter|plural)\s+singular\s+past(\s+indicative)?(\s+of)?',
    r'plural\s+past(\s+indicative)?(\s+of)?',
    # Reflexive / etc.
    r'reflexive(\s+(form|of))?',
    # Catch-all: starts and ends with grammatical terms only
    r'(masculine|feminine|neuter|short|long)\s+(singular|plural|past|present)(\s+(of|indicative))?',
]
ZOMBIE_RE = re.compile(
    r'^(?:' + '|'.join(ZOMBIE_PATTERNS) + r')\s*$',
    re.IGNORECASE
)

ENTRY = re.compile(r'\["((?:[^"\\]|\\.)*)"\]="((?:[^"\\]|\\.)*)"')

def is_zombie(value):
    return bool(ZOMBIE_RE.match(value.strip()))

# Read existing chunks
words = []
phrases = []
zombie_word_samples = []
zombie_phrase_samples = []

for name in sorted(os.listdir(ROOT)):
    if not name.endswith('.lua'):
        continue
    if name.startswith('Dictionary_Full_'):
        bucket, samples = words, zombie_word_samples
    elif name.startswith('Dictionary_Phrases_'):
        bucket, samples = phrases, zombie_phrase_samples
    else:
        continue
    s = open(os.path.join(ROOT, name), encoding='utf-8').read()
    for m in ENTRY.finditer(s):
        k, v = m.group(1), m.group(2)
        if is_zombie(v):
            if len(samples) < 25:
                samples.append((k, v))
            continue
        bucket.append((k, v))

# Dedup (preserve first)
def dedup(pairs):
    seen, out = set(), []
    for k, v in pairs:
        if k in seen: continue
        seen.add(k); out.append((k, v))
    return out

words = dedup(words)
phrases = dedup(phrases)

print(f'After zombie filter:')
print(f'  words   kept: {len(words)}')
print(f'  phrases kept: {len(phrases)}')
print()
print(f'Sample dropped word zombies:')
for k, v in zombie_word_samples[:15]:
    print(f'  {k:30} -> {v}')
print(f'Sample dropped phrase zombies:')
for k, v in zombie_phrase_samples[:5]:
    print(f'  {k:50} -> {v}')

# Split into 20 word chunks + 5 phrase chunks (same shape as before)
def split(lst, n):
    k = (len(lst) + n - 1) // n
    return [lst[i*k:(i+1)*k] for i in range(n)]

NW, NP = 20, 5
w_chunks = split(words, NW)
p_chunks = split(phrases, NP)

# Wipe old chunks
for name in os.listdir(ROOT):
    if name.startswith('Dictionary_Full_') or name.startswith('Dictionary_Phrases_'):
        os.remove(os.path.join(ROOT, name))

# Write fresh single-statement chunks
for i, chunk in enumerate(w_chunks, 1):
    fn = os.path.join(ROOT, f'Dictionary_Full_{i:02d}.lua')
    parts = ','.join(f'["{k}"]="{v}"' for k, v in chunk)
    with open(fn, 'w', encoding='utf-8', newline='') as f:
        f.write(f'RT_WORDS_EXTRA_{i:02d}={{{parts}}}')
    print(f'  Dictionary_Full_{i:02d}.lua: {len(chunk):>6} entries, {os.path.getsize(fn):>8} bytes')

for i, chunk in enumerate(p_chunks, 1):
    fn = os.path.join(ROOT, f'Dictionary_Phrases_{i:02d}.lua')
    parts = ','.join(f'["{k}"]="{v}"' for k, v in chunk)
    with open(fn, 'w', encoding='utf-8', newline='') as f:
        f.write(f'RT_PHRASES_EXTRA_{i:02d}={{{parts}}}')
    print(f'  Dictionary_Phrases_{i:02d}.lua: {len(chunk):>6} entries, {os.path.getsize(fn):>8} bytes')
