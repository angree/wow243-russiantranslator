# Russian Translator — WoW 2.4.3 addon

Translates incoming Russian chat into English (dictionary-based, pure in-game, no network calls). Unknown tokens are transliterated on the fly and logged per-session so the dictionary can be grown over time.

> **Target client**: World of Warcraft 2.4.3 (The Burning Crusade, build 8606). Will not work on retail / WotLK / Cata / modern classic. See `../WOW_2_4_3_ADDON_GUIDE.md` for why.

## What the addon does

Every incoming chat message from Say / Yell / Party / Raid / Guild / Whisper / Channel / Emote / Monster-* is scanned:

1. **No Cyrillic?** Pass through unchanged.
2. **Has Cyrillic?**
   - Lowercase (handles ASCII and the 33 Cyrillic letters + Ё).
   - Match longest multi-word phrases first (`го кара` → `let's go Karazhan`).
   - Word-by-word dictionary lookup — known → English, unknown → transliterated (`привет` → `privet`) **and recorded** in the session log.
   - Render as `[Russian] <english>  (<original cyrillic>)`.

## What makes it break (by design)

- No HTTP / network calls — the WoW 2.4.3 Lua sandbox forbids it. Zero online translation.
- No AI / LLM — just dictionary + transliteration.
- No real-time file I/O — unknowns flush to `SavedVariables` at logout or `/reload`.

Consequence: the addon only translates what it knows. Everything else comes out transliterated. That's the point — we iterate the dictionary from real-world misses.

## Install

Source of truth lives in this repo (`i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\`). The game loads from `C:\Gry\World of WarcraftOLD\Interface\AddOns\RussianTranslator\`.

To sync repo → game:

```
..\sync.bat
```

(uses `robocopy /MIR`). Run it after any edit; then `/reload` in-game to pick up the changes.

If the client is not running, TOC changes require a fresh launch. Lua changes are picked up by `/reload`.

## Usage

After login you should see:

```
[RT] loaded (session 2026-04-19_10-15-30). Type /rt help for commands.
```

Slash commands:

| Command        | Effect                                                          |
|----------------|-----------------------------------------------------------------|
| `/rt`          | show help                                                       |
| `/rt on`       | enable translation                                              |
| `/rt off`      | disable (messages pass through untouched)                       |
| `/rt orig`     | toggle appending the original Cyrillic after each translation   |
| `/rt dump`     | print current session stats + top 10 unknown tokens to the chat |
| `/rt clear`    | wipe all stored sessions from `SavedVariables`                  |
| `/rt status`   | print current settings and session count                        |

## The dictionary-growth workflow

1. Play on a Russian-speaking TBC server (e.g. WoWCircle TBC x2). Russian chat messages render as `[Russian] <partial translation>  (<original>)`.
2. End the session (`/reload` or logout). `SavedVariables` is flushed to disk.
3. Open the file:
   ```
   C:\Gry\World of WarcraftOLD\WTF\Account\<YOUR_ACCOUNT>\SavedVariables\RussianTranslator.lua
   ```
4. Inside you'll find per-session records:
   ```lua
   RT_DB = {
       sessions = {
           {
               started = "2026-04-19_10-15-30",
               ended   = "2026-04-19_11-47-22",
               messagesSeen = 812,
               messagesTranslated = 244,
               unknownDistinct = 87,
               unknowns = {
                   ["гоняем"]  = { count = 5, sample = "кто ещё гоняем кару седня" },
                   ["кидайте"] = { count = 3, sample = "кидайте инвы" },
                   ...
               },
           },
       },
   }
   ```
5. Paste the `unknowns = { ... }` block (or the whole file) into a chat with Claude in this project; Claude translates and extends `Dictionary.lua`.
6. Run `sync.bat`, `/reload` in game — enriched dictionary is live.

## File layout

```
RussianTranslator/
    RussianTranslator.toc    single-line ## Interface: 20400, no BOM
    Dictionary.lua           PHRASES, WORDS, CYR_LOWER, TRANSLIT tables
    Core.lua                 filter pipeline + session logger + slash handler
    README.md                this file
```

## Known limitations (tracked for future iterations)

- **Homonyms**: `маг` means both "mage" and "Magtheridon"; current dictionary picks one winner (Magtheridon, last-write). Plan: disambiguate via phrases like `го маг` → Magtheridon, bare token → mage.
- **`за`**: ambiguous between "for" (preposition) and "Zul'Aman". Currently treats as Zul'Aman.
- **Russian inflection**: `нужен / нужна / нужно / нужны` all mean "need" but are separate tokens — we add variants as they appear in logs.
- **Cyrillic punctuation** (`«»`, `—`) not handled specially; they end up between tokens as separators, no harm done.
- **Rendering font**: if your client's default chat font lacks Cyrillic glyphs, the `(original)` part will show as squares. Either ship a Cyrillic-capable TTF and apply it to `ChatFrame1..N` (planned; see guide §15) or run `/rt orig` to hide the original.

## Security model

The addon is purely observational:
- No protected function calls, no combat-lockdown concerns.
- No secure templates used.
- No hooks on Blizzard functions — only `ChatFrame_AddMessageEventFilter`, which is the sanctioned entry point.
- No global variable overwrites.

Taint-free by construction.
