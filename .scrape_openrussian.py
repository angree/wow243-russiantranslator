#!/usr/bin/env python
"""Scrape OpenRussian.org pages 161..220 (start=8000..10950)."""
import re, json, time, sys, io, urllib.request, unicodedata, random

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = r'I:/PROGRAMOWANIE_CLAUDE/Addon_Russian_Translator/openrussian_7.txt'
HDRS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'en-US,en;q=0.9',
}

def strip_accents(s):
    # Remove U+0301 combining acute and similar combining marks
    return ''.join(ch for ch in unicodedata.normalize('NFD', s) if unicodedata.category(ch) != 'Mn')

def fetch(start, tries=4):
    url = f'https://en.openrussian.org/list/all?start={start}'
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers=HDRS)
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read().decode('utf-8', errors='replace')
        except Exception as e:
            print(f'  retry {attempt+1} for start={start}: {e}', flush=True)
            time.sleep(2 + attempt * 2)
    raise RuntimeError(f'failed start={start}')

PAT = re.compile(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', re.DOTALL)

def parse(html):
    m = PAT.search(html)
    if not m:
        return []
    j = json.loads(m.group(1))
    return j['props']['pageProps']['entries']

def clean_en(tr):
    # Lowercase, strip punctuation noise, collapse whitespace.
    t = tr.strip().lower()
    # drop anything in parens "(something)"
    t = re.sub(r'\([^)]*\)', ' ', t)
    # drop stuff after semicolons and | (alternate senses may be too noisy, keep first)
    # collapse whitespace
    t = re.sub(r'\s+', ' ', t).strip()
    # strip surrounding quotes
    t = t.strip('"\'')
    # remove leading "to " for verbs? keep it — it's normal gloss form.
    return t

pairs = []
seen = set()
total_entries = 0

for page in range(161, 221):
    start = (page - 1) * 50
    print(f'page {page} start={start}', flush=True)
    html = fetch(start)
    entries = parse(html)
    total_entries += len(entries)
    for e in entries:
        bare = e.get('bare')
        if not bare:
            continue
        ru = strip_accents(bare).lower().strip()
        if not ru:
            continue
        trs = e.get('majorTranslations') or e.get('translations') or []
        if not trs:
            continue
        # take first translation as primary
        en = clean_en(trs[0])
        if not en:
            continue
        key = (ru, en)
        if key in seen:
            continue
        seen.add(key)
        pairs.append(f'{ru}|{en}')
    # polite delay
    time.sleep(random.uniform(1.0, 1.5))

with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(pairs) + '\n')

print(f'entries fetched: {total_entries}, unique pairs written: {len(pairs)}', flush=True)
print(f'output: {OUT}', flush=True)
