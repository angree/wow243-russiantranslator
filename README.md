# wow243-russiantranslator

A pure-Lua Russian → English chat translator for **World of Warcraft 2.4.3** (The Burning Crusade, build 8606). Replaces incoming Russian chat messages with a `[Russian]` prefix and a best-effort English translation, keeping any untranslated words in their original Cyrillic (colour-highlighted) so they are easy to spot.

> **Target client**: WoW 2.4.3 only. The addon uses the chat-filter signature, saved-variables flush timing, and secure-code rules specific to TBC. It will not work on Wrath/Cataclysm/MoP classic, retail, or post-3.0 private servers without changes.

![version](https://img.shields.io/badge/version-1.8.5-blue)
![coverage](https://img.shields.io/badge/unique_chat_coverage-96%25-brightgreen)
![forum](https://img.shields.io/badge/forum_prose-100%25-brightgreen)
![entries](https://img.shields.io/badge/dictionary-503k_entries-informational)
![interface](https://img.shields.io/badge/interface-20400-orange)
![license](https://img.shields.io/badge/license-MIT-green)

## Why?

On a Russian-speaking TBC private server, 80–90 % of public-channel chat is in Russian. If the default client font cannot render Cyrillic, you see squares. If it can, you can read the alphabet but not the words. Online translation is not an option — the 2.4.3 Lua sandbox has no networking. This addon takes the practical middle path: a bundled dictionary of WoW-slang and Russian words, matched token-by-token, with the original Cyrillic always kept in parentheses so you can double-check.

## Features

- **Rewrites incoming chat** across every channel (`CHAT_MSG_SAY`, `CHAT_MSG_YELL`, `CHAT_MSG_PARTY`, `CHAT_MSG_RAID*`, `CHAT_MSG_GUILD`, `CHAT_MSG_OFFICER`, `CHAT_MSG_WHISPER*`, `CHAT_MSG_CHANNEL`, `CHAT_MSG_EMOTE*`, `CHAT_MSG_MONSTER_*`).
- **Bundled dictionary** with **2360+ entries** seeded from real Global-channel chat on a live Russian TBC server, then expanded with parallel research across Russian-English dictionaries, Russian WoW forums, and broader Russian WoW community content:
  - ~400 multi-word phrases (e.g. `ведет набор активных игроков` → *recruiting active players*, `ХС 5/5 БТ 7/9` → *Hyjal 5/5 BT 7/9*, `в сердце разрушителя душ` → *Heart of the Soul-Destroyer (quest)*).
  - ~1950 single-word tokens — every TBC 5-man and raid with all Russian short-forms, class/role/spec abbreviations (`хил`, `танк`, `шп`, `ферал`, `фростик`, `ретрик`, `холик`, `элька`, `афлик`, `деструктор`, …), LFG/LFM idioms (`нид`, `инв`, `го`, `ищу`, `ренд`), trade (`куплю`, `продам`, `стак`, `голд`), common slang (`ппц`, `бугров`, `мусорнулся`, `шиза`, `ору`, `жесть`, `кринж`, `топчик`), Russian zone/city names with grammatical cases (`штормграда`, `оргриммаре`, `каражане`), conjugated verbs (`я иду`, `пришёл`, `сделаю`, `будет`, `хочешь`), all common adjectives/adverbs/pronouns/prepositions/numerals.
- **Gold shorthand handling**: `5к`, `4.5 к`, `500к` are recognised as thousand-shorthand and rendered as `5K`, `4.5K`, `500K` — not mistranslated as the preposition "к" (to).
- **Automatic CP1251 detection** — many Russian private servers still ship chat in Windows-1251 rather than UTF-8. The addon sniffs and normalises on the fly so the same pipeline works regardless of encoding.
- **Orange-highlighted untranslated tokens** — any Cyrillic word the dictionary did not match is kept in the original Cyrillic in orange, so readability doesn't collapse to mojibake when the dictionary is short.
- **Per-session activity log** in `SavedVariables` — encodings seen, unknown token frequencies with sample context, filter call counts. Everything you need to grow the dictionary iteratively.
- **`pcall`-wrapped filter** — a bug in the translation pipeline cannot break the chat frame for the user.
- **Zero network, zero protected-API use, zero taint.** Purely observational: just `ChatFrame_AddMessageEventFilter`.

## Installation

### From release ZIP

1. Download `wow243-russiantranslator-<version>.zip` from the [Releases page](../../releases).
2. Extract. You should end up with a folder `RussianTranslator/` containing `RussianTranslator.toc`, `Core.lua`, `Dictionary.lua`.
3. Copy that folder into `<WoW 2.4.3 install>\Interface\AddOns\`.
4. Launch the game. At the character-select screen, click **AddOns** and make sure *Russian Translator* is enabled. Tick *Load out of date AddOns* only if the client refuses to load it — `20400` should be accepted natively on a 2.4.3 build.

### From source (development)

Clone this repo anywhere, then either:

- Symlink `RussianTranslator/` into your `Interface/AddOns/` (Windows: `mklink /J`, same volume required; macOS/Linux: `ln -s`), or
- Use the bundled `sync.bat` (Windows) which `robocopy /MIR`s the addon into a hard-coded WoW install path. Edit the paths in `sync.bat` to match your setup.

## Usage

When you log in, the addon prints:

```
[RT] made by Grzegorz Korycki (Poczwarka)
[RT] loaded (session 2026-04-19_12-34-56). filters: ok=17 fail=0. Type /rt help.
```

Once that appears, every incoming Russian message is rewritten. An example:

```
[Russian] PvE guild Risen recruiting active players for the main raid roster
          mage hunter shadow priest feral RT 20:00 MSK Hyjal 5/5 BT 7/9
          (PvE Гильдия Risen ведет набор активных игроков в мейн статик
           Маг Хант Шп Ферал РТ 20:00 МСК ХС 5/5 Бт 7/9)
```

### Slash commands

| Command             | Effect                                                            |
|---------------------|-------------------------------------------------------------------|
| `/rt`               | print help                                                        |
| `/rt on` / `/rt off`| enable / disable translation (messages pass through untouched)    |
| `/rt orig`          | toggle appending the original Cyrillic next to each translation   |
| `/rt debug`         | toggle per-message debug prints with encoding + hex dump          |
| `/rt status`        | current settings + session counters                               |
| `/rt dump`          | session stats + top 10 unknown tokens                             |
| `/rt log [N]`       | print last N rows of the in-memory activity log (default 20)      |
| `/rt test <text>`   | manually run a string through the pipeline, show each step        |
| `/rt reregister`    | re-register chat filters (diagnostic)                             |
| `/rt clear`         | wipe all stored sessions from `SavedVariables`                    |

### Saved variables

After any clean logout or `/reload`, session data is written to:

```
<WoW install>\WTF\Account\<ACCOUNT>\SavedVariables\RussianTranslator.lua
```

This is a Lua file with a single global `RT_DB` table. Its `sessions[N].unknowns` sub-table lists every Cyrillic token the dictionary failed to match, with a usage count and a sample context line — perfect fodder for growing the dictionary.

## Growing the dictionary

The bundled dictionary is a starting point; real Russian chat will always have words it doesn't know. Workflow to extend it:

1. Play on the server, let the addon accumulate a session's worth of unknowns.
2. Log out cleanly (`/camp`, `/logout`, `/reload`, or the Game Menu).
3. Open `WTF\Account\<ACCOUNT>\SavedVariables\RussianTranslator.lua`.
4. Paste the `unknowns = { ... }` block (or the whole file) into an issue, discussion, PR, or your own translation workflow.
5. Add entries to `RussianTranslator/Dictionary.lua`:
   - Single-token translations go under `ns.WORDS`.
   - Multi-word patterns go under `ns.PHRASES` (matched greedily, longest-first).
6. `/reload` — the new entries are live.

The dictionary is organised by category (instances, classes, LFG, trade, slang, closed-class words) — keep that structure when contributing.

## Known quirks (2.4.3 specifics)

- **TOC is single-line**. `## Interface: 20400`. Multi-flavour TOCs are a post-Shadowlands feature.
- **Saved the "hard way"**. `SavedVariables` only flushes on clean logout or `/reload` — a client crash loses the last session's data.
- **Dictionary-driven**. There is no AI, no machine translation, no fuzzy matching. If a word is not in the dictionary it stays in Cyrillic (orange). If you need something translated, add it.
- **Homonym handling**. A few tokens are intentionally biased toward their most common TBC-chat meaning:
  - `маг` → *mage* (the phrase `го маг` overrides to *Magtheridon*).
  - `за` → *Zul'Aman* (the preposition sense is rare in LFG chat).
  - `локи` → *warlocks* (ambiguous with *locations* — rare).
  - `об` → *(normal)* (the LFG suffix; as a preposition "about" it almost never appears in chat).
- **CP1251 vs UTF-8**. Both are supported automatically. If a message comes through as ASCII when you expected Cyrillic, check the log — the server may be stripping bytes.
- **Fonts**. If your client's default chat font cannot render Cyrillic, the `(original)` portion will show as squares. Either install a Cyrillic-capable TTF and apply it to the chat frames (planned) or run `/rt orig` to hide the original.

## Architecture

```
RussianTranslator/
├── RussianTranslator.toc   single-line ## Interface: 20400, no BOM
├── Dictionary.lua          CYR_LOWER, TRANSLIT, CP1251→UTF-8 helpers,
│                           PHRASES, WORDS, PHRASE_ORDER (sorted)
├── Core.lua                chat-filter pipeline, session logger,
│                           slash handler, event wiring
└── README.md               addon-level quickstart
```

The filter is pure observation (`ChatFrame_AddMessageEventFilter`) and uses no secure or protected API — combat lockdown is irrelevant. See [`WOW_2_4_3_ADDON_GUIDE.md`](WOW_2_4_3_ADDON_GUIDE.md) in this repo for a detailed reference of the 2.4.3 addon environment, including several non-obvious differences from modern retail WoW that tripped up early drafts of this addon.

## Contributing

Pull requests that add dictionary entries, fix bad translations, or improve pipeline correctness are welcome. Please:

- Keep `Dictionary.lua` organised by existing category headings.
- Do **not** use retail-era idioms (`local addonName, ns = ...`, `(self, event, msg, ...)` chat-filter signature, `C_*`, `COMBAT_LOG_EVENT_UNFILTERED`, `AnimationGroup`, `BackdropTemplate`, `Mixin`, `C_Timer`, multi-line TOC). See the guide for why.
- If you add a word that is homonymous or fleksja-heavy, document the choice in a comment.

## License

[MIT](LICENSE) © 2026 Grzegorz Korycki.

## Credits

- Built by **Grzegorz Korycki** (Poczwarka).
- Seeded from live chat on a Russian TBC server — anonymous thanks to every raid-pinger whose `нид хил 1 дд` ended up in the dictionary.
- Chat-filter signature and several 2.4.3 pitfalls cross-checked against other working TBC addons, notably `Timed` (which correctly uses the TBC-era `function(msg)` filter signature).
