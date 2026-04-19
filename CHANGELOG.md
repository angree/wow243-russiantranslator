# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.6.0] - 2026-04-19

### Fixed
- **Gold-shorthand preprocessor no longer eats into following words.**
  v0.5 converted `28 крита` (28 crit) into `28Kрита` because the regex
  `(%d+)%s*к` matched the leading `к` of `крита`. Fixed with a word-boundary
  constraint: the suffix is only consumed if the next byte is not a Cyrillic
  letter or ASCII word character.

### Added
- **Numeric shorthand preprocessors extended**:
  - `20г` → `20g` (gold single-letter shorthand, same boundary rule as `к`).
  - `1дд` / `2дд` / `3дд` … → `1 dps` / `2 dps` / `3 dps`.
  - `1хил` / `2хилл` → `1 healer` / `2 healers`.
  - `1танк` / `2танк` → `1 tank` / `2 tank`.
- **Dictionary gaps filled from real v0.4 chat session** (WoWChatLog_004): 50+
  new entries covering the words that fell through — modal verbs and
  particles (`может`, `мб`, `пусть`, `возможно`, `возможность`), pronouns
  (`кому`, `который`, `которая`, `них`, `него`), conjunctions (`чтоб`,
  `чем`, `помимо`), verbs (`убить`, `видеть`, `дают`, `лежит`, `кажется`,
  `воспринимай`, `подумал`, `убрали`), nouns (`администрация`, `гробница`,
  `топики`, `чате`, `пиво`, `язык`, `удача`), time (`суток`, `порой`),
  affective (`скорей`, `англ`, `удачи`), laughter-length variants, and
  insult/slur placeholders for completeness.
- **Explicit pre-baked gold shortcuts** for common amounts: `20г`, `10г`,
  `50г`, `100г`, `500г`, `1к`..`100к`.

### Coverage
After v0.6.0 the live chat log from WoWCircle TBC Global channel reaches
**98 %** translation coverage at the Cyrillic-token level (323 tokens,
318 hits, remaining 5 are player nicknames).

## [0.5.0] - 2026-04-19

### Added
- Major dictionary expansion: **2361 entries** (409 phrases + 1952 words), up
  from 586 in v0.4.0 — a ~4x increase. Harvested in parallel by three
  research agents:
  - **General Russian-English vocabulary**: conjugated verbs in common forms
    (я иду, пришёл, сделаю), everyday adjectives with all grammatical forms,
    adverbs, pronouns in all cases, numerals 1–1000, time words, chat slang
    (хз, имхо, норм, збс, ща, юзать), internet reactions (ору, жесть, кринж,
    топчик, жиза), and emotional/insult vocabulary common in MMO chat.
  - **Russian WoW TBC forum slang**: class/spec abbreviations (фростик,
    ретрик, холик, протик, элька, энха, рестик, афлик, деструктор, мункин,
    совунья), instance shorthand variants (шатхол, маналей, муни, маркнар),
    server economy terms (буст, бустер, прем, примка, донат, реалманы,
    пинкод), PvP/arena slang (бурст, кайт, контроль, кц, ммр, глад).
  - **Broader Russian WoW web content**: Russian localised zone names
    (Запределье, Нордскол, Калимдор, Штормград, Оргриммар, Даларан,
    Шаттрат, Награнд, Зангартопь), Russian-language spell names players
    shorthand (полимаг, молния цепью, удар в спину), professions and ranks
    (алхимик, кузнец, ювелир, пошив, кожевник, горное дело), combat
    call-outs (вайп, трай, клир, фокус огонь, не стой в огне).
- Grammatical-case coverage for high-frequency WoW nouns (штормграда/
  штормграде, оргриммара/оргриммаре, каражана/каражане/каре/кары).

### Fixed
- **Number + "к" is now translated as "K" thousand-shorthand** (e.g.
  "продам за 5к" → "WTS for 5K", "4.5 к голда" → "4.5K gold"). Previously
  the single-token "к" fell through to its preposition meaning "to",
  producing nonsense like "WTS for 4.5 to". Implemented as a pre-token
  regex replacement in the translation pipeline.
- **Standalone "за" now defaults to "for"** instead of "Zul'Aman". The
  Zul'Aman sense is already covered by phrases like "го за" and "кто на за",
  so the common trade sense ("за 5к" = "for 5K") now translates correctly.



### Added
- Comprehensive starter dictionary seeded from real Global-channel chat logs
  on a Russian TBC server: ~140 multi-word phrases + ~440 single-word tokens
  covering instance names (all TBC 5-mans + raids), class/role abbreviations,
  LFG/LFM idioms, trade/arena shorthand, common slang and small words.
- Russian raid-progress pattern recognition (e.g. `ХС 5/5 БТ 7/9`).
- Per-session activity log written to `SavedVariables` at logout/reload:
  encoding detected, first hex bytes per encoding, filter call count,
  sampled chat rows, and per-token unknown-word frequency with sample context.
- Startup credit line.

### Changed
- Untranslated Cyrillic tokens are now kept in Cyrillic (coloured orange)
  instead of being transliterated, so it is immediately clear which parts
  of a message the dictionary did not match.

## [0.3.1] - 2026-04-19

### Changed
- Unknown tokens keep their Cyrillic form (orange) rather than being
  transliterated to Latin.

## [0.3.0] - 2026-04-19

### Fixed
- Chat filter signature corrected for WoW 2.4.3. Earlier versions used the
  modern `(self, event, msg, ...)` signature, which on a 2.4.3 client
  shifts every positional argument by two (so `event` receives `sender`,
  `msg` receives `language`, etc.) and crashes inside `string.format` for
  events with no sender.  Now uses the real TBC signature `(msg, ...)` with
  the event name captured via a closure at registration time.
- Filter body wrapped in `pcall` so a bug in the pipeline no longer taints
  the chat frame.

## [0.2.0] - 2026-04-19

### Fixed
- Shared-namespace initialisation. The common Lua idiom
  `local addonName, ns = ...` silently fails on 2.4.3 because top-level
  addon varargs were not introduced until patch 3.0.2 (WotLK); every
  subsequent `ns.foo = ...` then errored as "attempt to index nil value".
  Replaced with a shared-global-table pattern that works on every WoW
  version.

### Added
- Automatic CP1251 → UTF-8 normalisation for servers that ship Cyrillic
  chat in the legacy Windows-1251 encoding.
- `/rt debug`, `/rt test <text>`, `/rt log`, `/rt reregister`.

## [0.1.0] - 2026-04-19

Initial working draft (did not survive contact with a live 2.4.3 client;
kept for history).
