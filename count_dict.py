"""Count entries across all dictionary files."""
import re, glob, sys
sys.stdout.reconfigure(encoding='utf-8')

ENTRY = re.compile(r'\["((?:[^"\\]|\\.)*)"\]="((?:[^"\\]|\\.)*)"')


def count(f):
    with open(f, encoding='utf-8') as fp:
        return sum(1 for _ in ENTRY.finditer(fp.read()))

forms = sum(count(f) for f in glob.glob('RussianTranslator/Dictionary_Forms_*.lua'))
extra = sum(count(f) for f in glob.glob('RussianTranslator/Dictionary_Full_*.lua'))
phrases_extra = sum(count(f) for f in glob.glob('RussianTranslator/Dictionary_Phrases_*.lua'))

s = open('RussianTranslator/Dictionary.lua', encoding='utf-8').read()
mp = re.search(r'ns\.PHRASES\s*=\s*\{(.*?)^}\s*$', s, re.MULTILINE | re.DOTALL)
mw = re.search(r'ns\.WORDS\s*=\s*\{(.*)$', s, re.DOTALL)
core_phrases = sum(1 for _ in ENTRY.finditer(mp.group(1))) if mp else 0
core_words = sum(1 for _ in ENTRY.finditer(mw.group(1))) if mw else 0
total = core_words + forms + extra + core_phrases + phrases_extra

print(f'core WORDS:   {core_words:>7,}')
print(f'core PHRASES: {core_phrases:>7,}')
print(f'Forms:        {forms:>7,}')
print(f'Kaikki extra: {extra:>7,}')
print(f'Kaikki phr:   {phrases_extra:>7,}')
print(f'-' * 30)
print(f'TOTAL:        {total:>7,}')
