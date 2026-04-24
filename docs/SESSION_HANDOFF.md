# Session handoff — WoW 2.4.3 RussianTranslator — 2026-04-24

## TL;DR for post-compaction Claude

**Addon działa CORE-only.** Dictionary_Full_NN.lua (10 chunków po ~1.5 MB)
z Kaikki.org Wiktionary pack się NIE ŁADUJĄ w WoW 2.4.3 mimo różnych
prób. User widzi `dbg2: ns.WORDS_EXTRA exists = false, chunks loaded=NONE`
przy każdym `/reload`, ale BUILD STAMP w Core.lua potwierdza że kod się
przeładowuje prawidłowo. Problem nie jest sync-related.

**Next step:** rozebrać pfQuest-tbc (addon który ładuje 3.9 MB quests.lua
bezproblemowo) na czynniki pierwsze. User chce tego sam-sprawdzić z
drugim Claude po kompresji.

## Stan repo (at time of handoff)

- Version tag w TOC: `1.6.2` (lokalnie, niepublikowane)
- Ostatni publiczny release na GitHub: **v1.4.2** (stabilny, ~30k entries)
- Commity lokalne po v1.6.1 — NIE pushuj na origin do czasu aż to zadziała
- User explicite: "nie wysylaj na githuba tych wersji smiecisz tam
  zjebanymi wersjami"

## Co działa (v1.6.2 local)

- Core.lua (43 KB) — loaded correctly, build stamp prints
- Dictionary.lua (1.2 MB, ~75k entries) — loaded correctly
  - WoW-specific vocabulary (v0.1→v1.4)
  - Top-5000 OpenRussian
  - cmangos/tbc-db (46k WoW item/NPC/quest names)
  - BUILTIN_NICKS (125 harvested sender nicks)
- Lemmatizer (85-rule suffix-strip, irregular stems)
- Perfectivizing-prefix stripper (36 prefixes, verb-guard)
- Pipeline: phrase-first → WordLookup → Lemmatize → PrefixStrip → orange

## Co NIE działa

Dictionary_Full_NN.lua pack (extra Kaikki Wiktionary, ~350k entries,
~20 MB sumarycznie) → `ns.WORDS_EXTRA` pozostaje `nil` mimo że pliki
są fizycznie w `C:\Gry\World of WarcraftOLD\Interface\AddOns\RussianTranslator\`
wylistowane w TOC, nie mają syntax errorów.

## Chronologia prób (wszystkie nieudane)

1. **v1.5.0**: jeden plik Dictionary_Full.lua 21.7 MB → odrzucony po cichu
   (mode=extra pack missing).
2. **v1.6.0**: split into Dictionary.lua (1.2 MB) + Dictionary_Full.lua
   (21.7 MB). Ten sam problem.
3. **v1.6.1**: 10 chunków po 2.5 MB, każdy format:
   ```lua
   ns.WORDS_EXTRA["key"]="value"  -- tysiące takich linii
   ns.WORDS_EXTRA["key2"]="value2"
   ...
   ```
   Nadal NONE. Podejrzenie: Lua 5.1 max 262k constants per chunk w teorii,
   w praktyce ~65k na WoW 2.4.3.
4. **v1.6.2 attempt A**: 30 chunków po 700 KB z tym samym per-line statement
   format. NONE.
5. **v1.6.2 attempt B**: 10 chunków po 1.5 MB w stylu pfQuest-tbc
   (table-literal + for...pairs merge):
   ```lua
   local w = {["k1"]="v1",["k2"]="v2",...}  -- jedno duże
   for k,v in pairs(w) do ns.WORDS_EXTRA[k] = v end
   ```
   **NADAL NONE** mimo że pfQuest-tbc używa tego samego wzorca na
   3.9 MB quests.lua i mu działa.
6. **Build-stamp check v1.6.2**: user widzi build stamp → kod się
   przeładowuje, sync jest OK, problem leży w samej zawartości plików.

## Plan next session (post-kompresja)

### Krok 1: dokładne rozebranie pfQuest-tbc
**Ścieżki**:
- `/c/Gry/World of WarcraftOLD/Interface/AddOns/pfQuest-tbc/`
- TOC: `pfQuest-tbc.toc`
- Database: `db/ruRU/items.lua` (0.9 MB), `db/ruRU/quests.lua` (3.9 MB)
- Loader: XML `<Include file="..." />` w `init/addon.xml`, `init/ruRU.xml`

**Pytania do zbadania**:
1. Czemu `items.lua` ładuje się OK mimo bycia single-file table literal?
2. Czy `<Include>` z XML loader omija jakiś limit TOC?
3. Czy coś w strukturze pliku pfQuest (np. chunked w ramach pliku, funkcje
   wrapper, `do...end` bloki) jest inne niż nasza?
4. Diff HEAD pfQuest/items.lua vs nasz Dictionary_Full_01.lua linia po linii.
5. Przetestować: skopiować dokładny format pfQuest do naszego chunka i
   sprawdzić czy się załaduje.

### Krok 2: zrezygnować z Kaikki jeśli pfQuest wzorzec też nie zadziała
User deklaruje: "jak dziala to uploadujemy". Jeśli 30-min research pfQuest
nie da odpowiedzi, wrócić do lean wersji:
- Usunąć Dictionary_Full_*.lua z TOC i folderu
- Dictionary.lua pozostaje (~75k entries)
- Coverage na chat: 98%+ wystarczy
- Bump version, commit, release v1.7.0 "lean edition"
- Pozbyć się bloatu, zostawić tylko core co działa

## Kluczowe pliki

### Source
- `i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\Core.lua`
- `i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\Dictionary.lua`
- `i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\Dictionary_Full_01.lua`…`_10.lua`
- `i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\RussianTranslator.toc`

### Deployed (live w WoWie)
- `C:\Gry\World of WarcraftOLD\Interface\AddOns\RussianTranslator\*`
- `sync.bat` robi `robocopy /MIR` z source → live

### Narzędzia
- `analyze_coverage.py` — pipeline mirror (chat log coverage)
- `analyze_coverage_honest.py` — per-unique-message metric
- `analyze_forum_coverage.py` — forum prose coverage
- `merge_openrussian.py`, `merge_kaikki.py`, `merge_emulator.py` —
  non-destructive dict mergers
- `rewrite_chunks.py` — generator Dictionary_Full chunks w stylu pfQuest
  (OSTATNIA PRÓBA, nie zadziałała)
- `clean_dict.py` — strip linguist annotations from values

### Dane źródłowe (backup locally, nie w git)
- `forum_dump/*.txt` — 120KB rosyjskiej prozy z 6 sekcji forum Moonwell
- `WoWChatLog_latest.txt` — najnowszy log czatu (może być zastępowany)

## Debug state obecny

Core.lua ma `pcall`-wrapped diagnostyki wypisywane przy PLAYER_LOGIN:
- dbg1: `ns.WORDS exists` (true)
- dbg2: `ns.WORDS_EXTRA exists` (**false** = problem)
- dbg3: `ns.PHRASES exists` (true)
- dbg4: `ns.PHRASES_EXTRA exists` (false)
- dbg5: `chunks loaded=0/10` + missing list
- BUILD STAMP: `"2026-04-24 20:22 (table-literal chunks)"` ← zmieniać
  na każdej edycji żeby user widział że kod się przeładował

## User preferences (reinforced this session)

- **Polish komunikacja, blunt diagnostyka.**
- **Nie wysyłać na GitHub broken buildów** — "smiecisz tam zjebanymi wersjami".
- Commit/release tylko po potwierdzeniu że działa.
- User pracuje pod presją czasu, chce konkretne fixy nie bikeshed.
- User frustruje się gdy output wygląda identycznie między próbami →
  WŻDY dodaj build stamp żeby user mógł odróżnić.
- User gra na Moonwell x5 (TBC 2.4.3), testuje in-game na Shatt/BG.

## Metrics baseline (przed Kaikki try)

| Miara | v1.4.2 (stable) |
|-------|-----------------|
| Entries | 30,279 |
| Chat coverage (unique msgs) | 97.93% |
| Messages 100% translated | 94.1% |
| Forum coverage | 100% (on corpus) |

## Podsumowanie dla post-kompresji Claude

User prosił o dodanie Kaikki Wiktionary pack (~350k entries extra).
Przez 4 godziny próbowaliśmy różnych sposobów załadować te dane do WoW
2.4.3. Wszystkie próby → **chunks_loaded=0/N**. 

**Musisz zacząć od** rozbicia pfQuest-tbc na czynniki pierwsze — to addon
który DOKŁADNIE to samo robi (ładuje multi-MB rosyjskie dane) i działa.

Jeśli po 30 min diagnostyki pfQuest nie znajdziesz odpowiedzi → cofnij
do v1.4.2 stable (lean edition), skasuj Dictionary_Full_*.lua, bump
version do v1.7.0, commit + push na GitHub.

Nie dodawaj więcej debuga zanim nie porównasz dokładnie pfQuest
quests.lua vs nasz chunk file byte-by-byte w zakresie nagłówka
i pierwszych wpisów.
