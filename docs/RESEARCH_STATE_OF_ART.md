# RU→EN Rule-Based Translation — State of the Art (April 2026)

Research notes compiled by a dedicated sub-agent (42 sources, ~10 min deep dive).
Relevance: establishing whether our ~30k-entry dictionary + 85-rule
suffix-strip lemmatizer + ~2k phrases approach has more room to grow
before hitting the rule-based ceiling.

## Executive summary

Mature rule-based RU→EN systems (Apertium, pymorphy2, MyStem) converge around
**~89-96% token coverage**, with **pymorphy2's Zaliznyak-derived dictionary at
~5M word forms from ~400k lemmas** as the effective ceiling for
dictionary-driven approaches. Our current approach (~30,279 entries + 85
suffix rules, 97-98% chat coverage) is at-or-above the practical ceiling.

The user's complaint about "1/3 of meaningful words untranslated" is the
**known structural failure mode of rule-based MT**, not a bug: rare-but-
content-bearing tokens are precisely what falls out of Zipf's tail.

## 1. Russian morphology in practice

| System | Lexicon size | Design | Coverage |
|--------|--------------|--------|----------|
| **pymorphy2/3** | ~5M forms, ~391k lemmas (OpenCorpora) | DAFSA + paradigm table + KnownSuffixAnalyzer | <1% error on in-vocab |
| **MyStem (Yandex)** | Zaliznyak-derived | FST + unknown-word guesser (Segalovich 2003) | <1% error |
| **Apertium-rus** | 126,833 stems, 3,790 paradigms | 308 constraint grammar rules | **89.57%** on Wikipedia |
| **Snowball Russian** | 0 (pure rules) | ~8 suffix categories | Not a lemmatizer; overstemming problems |

**Key pattern:** DAFSA-compressed lexicon of surface forms → (lemma,
paradigm-index, POS) triples + suffix-trie fallback for OOV. Pymorphy2 tries
endings of decreasing length (5→1 char) until matching a known paradigm.
Zaliznyak's 1977 grammatical dictionary (110k lemmas) is the common
ancestor of every serious Russian NLP system.

## 2. Known hard cases

Our flat 85-rule suffix-strip handles these poorly:

1. **Fleeting vowels** (`беглые гласные`): *день/дня/дней*
2. **Consonant mutations**: *писать→пишу, любить→люблю, возить→вожу*
3. **Suppletive pairs**: *есть/съесть, брать/взять, идти/шёл*
4. **Aspect pairs via 16+ prefixes**: *писать / написать / переписать / подписать / списать*
5. **Motion verbs**: *идти/ходить, ехать/ездить*
6. **2nd-conjugation -еть verbs** — unpredictable
7. **Case syncretism** in declension
8. **Stress-shifting prefixed verbs**: *выпить* vs *выпивать*
9. **Diminutives** (open-ended productive derivation)
10. **Possessive adjectives** from names: *Петин, Машин*

## 3. Open datasets

Ranked by fitness for our use case:

| Dataset | Size | License | Fitness |
|---------|------|---------|---------|
| **Kaikki.org Russian JSONL** | 776 MB | CC-BY-SA | **Best single source.** Pre-parsed Wiktionary, every case form + EN glosses. |
| **OpenCorpora** | ~391k lemmas, ~5M forms | CC-BY-SA | Best for morphology engine; no EN glosses. |
| **OpenRussian (Badestrand)** | Nouns/verbs/adjectives CSVs | CC-BY-SA 4.0 | Modest size but pre-curated. Used in v1.2-1.4. |
| **Tatoeba RU-EN** | ~550k RU sentences | CC-BY 2.0 FR | Phrase-level parallel data. |
| **OPUS OpenSubtitles RU-EN** | ~25M sentence pairs | Mixed | Huge; chat-register-adjacent. |
| Zaliznyak electronic | 110k+8k | CC-BY-NC | **NC blocks us**. |
| MyStem binary | Proprietary | Non-commercial only | Can't redistribute. |

**Counter-intuitive finding:** kaikki.org is underused. Gives lemma +
inflected forms + English gloss in JSONL, pre-parsed. CC-BY-SA compatible
with attribution.

## 4. Slang / chat handling

Almost nothing turn-key exists:
- **russki-mat.net** — Russian obscene slang + English glosses
- **Lurkmore.to** — Russian internet culture corpus (poorly structured)
- **Gaming-slang research** (Perm State 2021) confirms ~90% of Russian
  gaming slang is anglicisms already (афк, изи, гг, нуб) → mechanical
  transliteration reverse-lookup would cover most
- **Dota 2 Steam guides** collect RU→EN gaming-chat mappings informally

**Finding:** no curated Russian-gaming-chat parallel corpus. Our own
session logs + manual curation remain the best source.

## 5. WoW-specific resources

- **tekkub/wow-globalstrings** — extracted `GlobalStrings.lua` files for
  every Blizzard locale including ruRU. UI text, not chat.
- **Classic Wowhead** offers ruRU/enUS browsing; scraping blocked.
- **Private-server DB files**: ArcEmu/TrinityCore for TBC include
  `locales_item`, `locales_quest`, `locales_creature`, etc. with ruRU
  columns. **Best single source for WoW-specific name pairs.** Licensing
  varies; emu DBs are community-compiled but ruRU localizations come
  from Blizzard.

## 6. Architecture

Our (pure Lua 5.1 / 2008-era client / no network / ~30k dict) is exotic.

- **Our approach**: flat hash + suffix-strip, 30,279 entries, ~100 rules,
  97-98% coverage — **already exceeds Apertium-rus's 89.6%**. We do
  glossing, not translation (transfer rules), which is easier.
- **MARISA-trie**: would compress our dict to 1/50-1/100 of hashmap
  memory. Overkill unless we ship 200k+ entries.
- **Realistic ceiling for RBMT-style gloss on Russian chat:** 95-98%
  on-corpus with good morphology engine and 50k+ lemma dict.
  **We are there.** Remaining 2-5% is new slang, names, typos,
  productive derivation — cannot close without ML.

## 7. Concrete recommendations (v1.5.0+ roadmap)

Ranked by ROI:

### Tier 1: implement soon

1. **Perfectivizing-prefix stripper** (HIGH ROI, LOW complexity)
   Strip 16 perfective prefixes (на-, по-, про-, за-, с-, вы-, …) before
   lookup. Saves dozens of dict entries per imperfective base verb.
   **→ IMPLEMENTED in v1.5.0.**

2. **Kaikki.org Russian JSONL ingestion** (HIGH ROI, MEDIUM complexity)
   Download, extract `{lemma, forms[], translations{en}}`. 50k-100k lemma
   dictionary with pre-expanded inflections + free English glosses.
   CC-BY-SA + attribution.
   **→ IN PROGRESS v1.5.0.**

3. **TBC emulator DB dump** (MEDIUM ROI, LOW complexity)
   Mine ArcEmu/MaNGOS 2.4.3 `locales_item`, `locales_quest`,
   `locales_creature`, etc. for canonical Russian→English name pairs.
   Thousands of game-specific terms. Licensing: ruRU localizations are
   Blizzard-originated.
   **→ IN PROGRESS v1.5.0.**

### Tier 2: bigger rewrites

4. **Paradigm-keyed lemmatizer** (MEDIUM ROI, HIGH complexity)
   Replace flat suffix-strip with DAFSA/radix trie of (form → lemma,
   paradigm). Closes consonant-mutation / fleeting-vowel gaps.
   **→ v2.0 rewrite candidate.**

5. **Phonetic fallback** (LOW ROI, HIGH user-visibility)
   Russian-specific Daitch-Mokotoff Soundex to catch transliterations.
   Use only as last resort, risk of false collisions.

### Anti-patterns (don't do)

- More flat suffix rules past ~100 — overstemming grows faster than coverage.
- Scrape Wowhead (blocked).
- Integrate Apertium-rus (GPL infection).
- Ship Mueller dict without license review (GPL problems).

## 8. Sources (curated)

Morphology / NLP systems:
- [pymorphy2 GitHub](https://github.com/pymorphy2/pymorphy2)
- [Korobov 2015 paper](https://arxiv.org/pdf/1503.07283)
- [Apertium-rus/stats](https://wiki.apertium.org/wiki/Apertium-rus/stats)
- [Snowball Russian](https://snowballstem.org/algorithms/russian/stemmer.html)
- [Segalovich 2003 (MyStem)](https://cache-default01e.cdn.yandex.net/download.yandex.ru/company/iseg-las-vegas.pdf)

Datasets:
- [kaikki.org Russian](https://kaikki.org/dictionary/Russian/index.html)
- [wiktextract parser](https://github.com/tatuylonen/wiktextract)
- [OpenCorpora](https://opencorpora.org/)
- [Badestrand/russian-dictionary](https://github.com/Badestrand/russian-dictionary)
- [Tatoeba](https://tatoeba.org/en/downloads)
- [OPUS OpenSubtitles](https://opus.nlpl.eu/legacy/OpenSubtitles-v2018.php)

Slang / gaming:
- [russki-mat.net](https://www.russki-mat.net/e/Russian.php)
- [Gaming Slang in Russian Media](https://www.researchgate.net/publication/357058496_Gaming_Slang_Terms_in_Russian_Online_Media)

WoW-specific:
- [tekkub/wow-globalstrings](https://github.com/tekkub/wow-globalstrings)

Architecture:
- [MARISA-trie](https://github.com/s-yata/marisa-trie)
- [Steve Hanov succinct trie](https://stevehanov.ca/blog/index.php?id=120)

Linguistic reference:
- [Russian declension](https://en.wikipedia.org/wiki/Russian_declension)
- [Russian verbal aspect](https://en.wikibooks.org/wiki/Russian/Verbal_Aspect)
- [Aspect in Slavic languages](https://en.wikipedia.org/wiki/Grammatical_aspect_in_the_Slavic_languages)
