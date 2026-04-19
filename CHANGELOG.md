# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.1] - 2026-04-19

### Fixed
- **Removed `@WoW` from author credit strings.** The author string
  `"Grzegorz Korycki (Poczwarka @WoW)"` was being interpreted by GitHub
  as an `@WoW` user-mention, auto-linking release notes, the README and
  commit descriptions to `github.com/wow` — an unrelated GitHub account
  who had nothing to do with this project. Every release published so
  far was notifying that stranger. Replaced with `"(Poczwarka)"` and
  retro-edited all six existing release notes (v0.4.0..v0.7.0) to strip
  the mention. No functional changes; source, README, TOC author field,
  and in-game startup credit all updated.

## [0.7.0] - 2026-04-19

### Coverage
Fresh WoWCircle TBC session (log 006, 2248 lines, ~230 unique Russian
messages with very different themes from previous logs — guild-chat
recruiting, heroic-dungeon LFG, attunement questions, schedule posts,
Russian-localised quest/item names, complaints about spam). Starting
coverage was **71 %** (710/991 Cyrillic tokens covered); after this
release it is **98 %** (697/710 tokens, remaining 13 are mostly
player nicknames). Dictionary grew from 2361 → **3261 entries**
(698 phrases + 2563 words).

### Added
- **Difficulty-mode slang**: `гер`/`геры` (heroic), `нормалы`/`нм`/`нормалку`
  (normal), `дейлик` (daily). These are the dominant way Russian TBC
  players tag LFG posts, previously falling through as unknown.
- **Loot / raid-roster idioms**: `ласт`/`ласта`/`ласту` (last boss),
  `сум к ласту` (summon to last), `слот`, `штаны рез`/`штаны резерв`
  (pants reserved), `перчи рез`, `плащ рез`, `ласт слот`.
- **Instance-with-mode phrases**: `рампы гер`, `рампы нм`, `бф гер`,
  `шх гер`, `шм гер`, `паровое нм`, `паровое гер`, `узилище гер`,
  `узилищер` (Arcatraz heroic).
- **Weekly-schedule vocabulary**: days of week short (пн, вт, ср, чт, пт,
  сб, вс) and full (понедельник..воскресенье), `сб и вс`, `с пн по пт`,
  `пн-чт`, `выходной`, `сбор в 19:00`, `по иркутскому времени`,
  `по московскому времени`.
- **Quest-flow phrases** seen in log: `прикосновение занзила`
  (Touch of Zanzil), `как выполнить`, `сдать не могу`, `квест не сдаётся`,
  `в журнале пишет`, `за дейлик`, `ключ за дейлик`.
- **Russian-localised item names**: `туз из колоды зверей` (Ace of
  Beasts), `фолиант сотворения воды` (Tome of Conjure Water),
  `изначальная мощь` (Primal Might), `ткань пустоты` (Netherweave Cloth),
  `руническая ткань` (Runecloth), `ездовой хлыст назана` (Nazan's Riding
  Crop).
- **Russian-localised zone names**: `сёрные топи` (Swamp of Sorrows),
  `алый монастырь` / `монастырь алого` (Scarlet Monastery), `на кладбище`
  (SM Graveyard wing), `лабиринты иглошкуры` (Razorfen Kraul),
  `баресне`/`барренс` (Barrens), `каменор` (Stonard).
- **Attunement talk**: `атюн`/`аттюн` + case forms, `атюн на бт`
  (BT attunement), `с барабанами` (with drums), `прохождения санвела`
  (Sunwell progression), `для уcиления гильдии` (latin-'c' typo
  variant included).
- **Guild-recruit boilerplate**: `помогаем одеваем подсказываем`, `связь
  обязательная (дискорд)`, `для походов в рейды`, `по доп. вопросам в пм`,
  `приоритет в новых людях`, `шмот не важен`, `мы ценим`.
- **Complaint vocabulary**: `задолбали спамить ги`, `гавно-спам`, `эго
  гильд лидеров`, `обьядиниться`/`объединиться`, `игнорировать`,
  `сервак лагает`, `не готов к наплыву беженцев`.
- **Arena-rating team search**: `ищу напа в свою тиму`, short class tags
  `ршам`/`рдру`/`рпал`/`энх`/`энха`.

### Added (preprocessors in Core.lua)
- `<num>рейт` → `<num> rating`  (e.g. `1712рейт` → `1712 rating`)
- `<num>мин` → `<num> min`
- `<num>сек` → `<num> sec`
- `<num>лвл` → `<num> lvl`
  (complementing existing `<num>к/г/дд/хил/танк` preprocessors.)

### Fixed
- Missing `кару` (Karazhan accusative) — common in "кто на кару".
- Disambiguated `можно`, `лока`, `св`, `инвиз`, `уйти` that were falling
  through as unknowns.

## [0.6.2] - 2026-04-19

### Fixed
- **`боты` disambiguated.** A duplicate key was mapping `боты` to "bots"
  later in the file and overriding the earlier "boots" definition, so
  `зачарить боты` (enchant boots) came out as "enchant bots". Kept the
  "boots" default and added phrase overrides `боты пишут`, `все боты`,
  `боты онлайн`, etc. for the bot-complaint sense.

### Added
- **Contextual phrases that fix bad word-by-word translations.** Several
  Russian words are ambiguous in isolation but unambiguous inside common
  phrases; added phrase entries to pick the correct sense:
  - `кто может` / `кто может зачарить` / `может помочь` / `может сделать`
    → "who can" / "who can enchant" / "can help" / "can do" (was landing
    on "maybe" from the single-token fallback).
  - `с какого левела` → "from what level" (bare "с" + "какого" + "левела"
    previously missed).
  - `птица у друида` → "druid flight form" (literal was "bird at druid").
  - `дальний восток` → "Far East" (guild name on WoWCircle).
  - `московского времени` / `от московского времени` → "Moscow time" /
    "from Moscow time".
  - `для тех у кого` → "for those with" (three words none of which were in
    the single-token dictionary in their genitive/dative forms).
- **LFG professional-services phrases**: `ищу инженера`, `ищу ювелира`,
  `ищу кожевника`, `ищу портного`, `ищу алхимика`, `ищу кузнеца`,
  `ищу напа`/`ищу напарника`, and `нужен X` counterparts.
- **Crit-scope phrases**: `прицел 28 крита` / `прицел 28 криты` →
  "28-crit scope", plus `28 крита` / `28 криты` as short forms. Handles
  both crit-count genitive forms used in trade chat.
- **Instance-suffix phrases** for Steamvault (`паровое нормал`,
  `паровое норм`, `паровое хс`, `паровое хк`).
- **Boot-enchant shorthand**: `стамина+бег`, `стам+бег`, `ловкость+бег`
  → "stamina + run speed" etc. `бег` is dictionary-mapped to "run speed"
  (boot enchant context) rather than "run" to avoid mistranslation in
  trade chat.
- **Misc chat**: `лол сосать`, `сосать на` (vulgar losing slang),
  `wtb/куплю` and `куплю/wtb` (slash-joined mixed tokens), `мой реги`,
  `на 10 игр` (arena partner search count).
- **50+ single-word additions** covering the genitive/dative/instrumental
  forms missed in log-005: `дальний`, `восток`, `примет`, `новых`, `тех`,
  `кого`, `кому`, `какого`, `время`, `времени`, `московского`, `инженера`,
  `ювелира`, `алхимика`, `зачарить`, `реги`, `левела`, `птица`, `напа`,
  `напарника`, `игр`, `криты`, `бег`, `сосать`, `форум`, `тема`, `пост`
  and more.

### Coverage
After v0.6.2, live-chat token coverage on WoWCircle TBC Global is
**98 %** (338 Cyrillic tokens, 334 hits, 4 remaining are player
nicknames).

## [0.6.1] - 2026-04-19

### Added
- Registered `CHAT_MSG_BATTLEGROUND` and `CHAT_MSG_BATTLEGROUND_LEADER`.
  Battleground chat (`/bg`) was the only public channel not covered.
  All other channels (Say, Yell, Party, Raid, Raid-Leader, Raid-Warning,
  Guild, Officer, Whisper-in, Whisper-out, numbered channels like Global
  and Trade, Emotes, NPC speech) were already filtered — the addon just
  looked "Global-only" because that channel carries ~95 % of public chat
  traffic on a typical Russian TBC server.

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
