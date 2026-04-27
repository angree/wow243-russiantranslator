# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

**Russian-language chat translator addon for World of Warcraft 2.4.3 (The Burning Crusade, build 8606)** — targets private / emulated TBC servers where Russian-speaking player base dominates. The addon intercepts every `CHAT_MSG_*` event, rewrites Russian text into English using a bundled dictionary, and shows the result as `[Russian] <english>  (<original cyrillic>)` in the chat window.

Current state: **v1.7.1** shipped on GitHub, ~113k dictionary entries (28k core + 85k Kaikki), ~98.5% unique-message coverage on live Moonwell x5 TBC chat.

## Authoritative reference

**Always read `WOW_2_4_3_ADDON_GUIDE.md` before writing or modifying Lua/XML/TOC files.** Its §11 compatibility table is the source of truth for what API/events/templates exist on 2.4.3. Do not copy snippets from modern Wowpedia without verifying — many APIs documented there (`C_*` namespace, `COMBAT_LOG_EVENT_UNFILTERED`, `C_Timer`, `AnimationGroup`, `BackdropTemplate`, multi-line `## Interface`, `Mixin`, `Enum`) **do not exist** on 2.4.3 and will silently break.

The guide now also documents the two non-obvious traps that cost hours to debug early on:
- `local addonName, ns = ...` at file top fails silently on 2.4.3 (idiom added in WotLK 3.0.2). Use shared-global pattern `RussianTranslatorNS = RussianTranslatorNS or {}`.
- `ChatFrame_AddMessageEventFilter` callback signature on 2.4.3 is `function(msg, ...)`, NOT `function(self, event, msg, ...)`. Event name must be threaded through via a closure at registration time.

## Repository layout

```
repo-root/
├── CLAUDE.md                       ← this file
├── WOW_2_4_3_ADDON_GUIDE.md        ← 16-section reference for TBC addon dev
├── CHANGELOG.md                    ← versioned history (0.1.0 → 0.9.2)
├── README.md                       ← public readme (English)
├── LICENSE                         ← MIT, © 2026 Grzegorz Korycki
├── sync.bat                        ← robocopy repo → WoW AddOns folder
├── .gitignore                      ← ignores WoWChatLog_*.txt etc.
├── RussianTranslator/              ← the actual addon
│   ├── RussianTranslator.toc       ← single-line "## Interface: 20400", no BOM
│   ├── Dictionary.lua              ← PHRASES (~850) + WORDS (~3500) + helpers
│   ├── Core.lua                    ← filter pipeline, options panel, slash handler
│   └── README.md                   ← addon-level quickstart
├── releases/                       ← built ZIPs (git-ignored)
└── WoWChatLog*.txt                 ← private chat logs from live sessions (ignored)
```

## Build / test / release workflow

No build step, no test runner, no package manager. Iteration loop:

1. **Edit** the repo at `i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\`.
2. **`sync.bat`** copies via `robocopy /MIR` to `C:\Gry\World of WarcraftOLD\Interface\AddOns\RussianTranslator\`. Cross-volume (I: → C:) rules out `mklink /J`, and `mklink /D` needs Developer Mode.
3. **`/reload`** in WoW picks up Lua changes. TOC changes need a fresh client OR toggle-at-character-select + reload.
4. **Errors** surface as red popups only if `/console scriptErrors 1` is on; BugSack/BugGrabber (TBC-compatible) capture them otherwise.
5. **SavedVariables** live at `C:\Gry\World of WarcraftOLD\WTF\Account\<ACC>\SavedVariables\RussianTranslator.lua`. Flushed on `/reload` or clean logout. The `unknowns` table in each session is the source of dictionary-growth work.

When the user asks for a "test", that means a manual in-game check — there is no automation.

### Dictionary-growth workflow (core iterative work)

1. User plays on **Moonwell x5** (ruRU TBC 2.4.3 private server), accumulates chat via the addon's own logging + `/chatlog` (auto-enabled).
2. User hands off either the live `WoWChatLog.txt` (from `C:\Gry\World of WarcraftOLD\Logs\`) or the `RussianTranslator.lua` SavedVariables dump.
3. Claude runs the analysis simulator (Python snippet shown in-session — tokenizes messages, preprocesses numeric shorthand, matches phrases first then words, reports distinct unknown tokens with counts + sample context).
4. Claude adds entries to `Dictionary.lua` in the appropriate category section.
5. Claude verifies coverage improvement via the simulator, then versions/releases.
6. Release ritual: bump TOC version, update CHANGELOG.md section, sync to WoW, commit, tag, zip, push, `gh release create`.

Target coverage per session: **>95%**. Starting coverage for a previously-unseen topical session is usually **80-90%**; 10-20% of tokens are new.

## Release/publication pipeline

Published on GitHub: **https://github.com/angree/wow243-russiantranslator**

Each release:
1. Edit `RussianTranslator/RussianTranslator.toc` `## Version: X.Y.Z` field.
2. Add a new `## [X.Y.Z] - YYYY-MM-DD` block to `CHANGELOG.md`.
3. Update version badge in `README.md`.
4. `sync.bat` → WoW.
5. `git commit`, `git tag -a vX.Y.Z -m "..."`.
6. `powershell Compress-Archive RussianTranslator → releases/wow243-russiantranslator-vX.Y.Z.zip`.
7. `git push origin main && git push origin vX.Y.Z`.
8. `gh release create vX.Y.Z releases/*.zip --title "..." --notes-file .release_notes_tmp.md` (scratch note file is gitignored).

**NEVER include `@WoW` (or any `@someword`) in release titles, notes, commit messages, README, CHANGELOG, TOC author field, or the in-game startup message.** GitHub parses it as a user mention and pings an unrelated account (`github.com/wow`). All author/credit text reads `(Poczwarka)` — plain parens, no at-sign. This cost us a history rewrite once; see memory entry.

## Hard constraints (2.4.3 client)

- **TOC**: `## Interface: 20400` (single line, UTF-8 no BOM).
- **Lua**: 5.1 sandbox. No `io`, no `package`, no network.
- **Text encoding**: every source file UTF-8 **without BOM**. `.toc` files especially — BOM breaks parsing.
- **Cyrillic handling**: `#s` and `string.sub` are byte-based. Use `ns.NormalizeCyrillic` to handle both UTF-8 and CP1251 server encodings.
- **Fonts**: 2.4.3 accepts **TTF** only (no OTF). Default Western Blizzard fonts can't render Cyrillic.
- **Textures**: **BLP** only; PNG is ignored.
- **Chat length**: 255 bytes per outbound `SendChatMessage`.
- **Filter signature**: `function(msg, ...)` — NO self, NO event. Close over event name at registration.
- **Namespace**: shared-global pattern, not `local x, ns = ...`.

## Architecture snapshot (as of v0.9.2)

### `Dictionary.lua`
- `CYR_LOWER` — 33 Cyrillic uppercase → lowercase pairs.
- `TRANSLIT` — fallback GOST transliteration table (no longer used in pipeline; untranslated tokens stay in orange Cyrillic).
- `CP1251ToUtf8`, `DetectCyrillicEncoding`, `NormalizeCyrillic` — server-encoding agnostic.
- `PHRASES` table (~850 entries, multi-word English target, scanned longest-first).
- `WORDS` table (~3500 single-token entries, hash lookup).
- `PHRASE_ORDER` — sorted phrase keys by length desc (built at load).

### `Core.lua`
Main pipeline per incoming message:
1. `NormalizeCyrillic` — ASCII passes through, CP1251 converted, UTF-8 untouched.
2. Lowercase (both ASCII and Cyrillic).
3. Numeric shorthand preprocessors (word-boundary-aware): `<num>к→K`, `<num>г→g`, `<num>дд→ dps`, `<num>хил→ healer`, `<num>танк→ tank`, `<num>рейт→ rating`, `<num>мин/сек/лвл`.
4. Slavic smiley rewrite (pair-count aware): `)))→:))` / `(((→:((`; balanced parens left alone.
5. `DetectAddressee` — 5-rule layered nickname detection (sender-roster + 4 context heuristics). First matching rule wins; token auto-added to session roster.
6. `ApplyPhrases` — phrase-key substitution via `\1N\1` placeholders.
7. Main token gsub — each token either English (dict hit), preserved (placeholder / known nickname at position 1), or kept in orange Cyrillic (unknown).
8. `RestorePhrases` — placeholder → English phrase.
9. Output formatted as `[Russian] <english>  (<original>)` if `showOrig`, or just `[Russian] <english>`.

Other facilities:
- `InitSession` builds volatile per-session state (unknowns log, known nicks, chat log, counters).
- `InitDB` initialises SavedVariables with defaults for `enabled`, `showOrig`, `debug`, `autoChatLog`, `maxSessions`.
- `EnsureChatLog` calls `LoggingChat(true)` on PLAYER_LOGIN if `db.autoChatLog`.
- `InitUI` registers Blizzard Interface Options panel (four checkboxes wired directly to `db.*` fields).
- `/rt` slash handler with subcommands: `on/off`, `orig`, `debug`, `chatlog`, `status`, `dump`, `log`, `test`, `reregister`, `names`, `options`, `clear`.

## Non-obvious design decisions (don't reverse without reading why)

1. **Untranslated tokens stay in Cyrillic, coloured orange** — not transliterated. User explicitly preferred: visible signal of "not translated" + preserves readability for anyone with Cyrillic-capable font.
2. **`знаковNames` is RAM-only, rebuilt per session.** Persisting would accumulate stale names; a nickname colliding with a Russian word must re-earn its "don't translate" status every session by actually speaking.
3. **Layered addressee detection (5 rules)** catches nicknames even before they've spoken: punctuation markers, pronoun/imperative followers, unknown-at-start. See `DetectAddressee` in Core.lua §"Addressee detection".
4. **Paren-pair aware smiley detection.** Balanced parens (regular parentheticals like `кто на кару (хс)?`) are NOT rewritten. Only excess `)` or `(` get the colon prefix.
5. **`за` defaults to `for`, not Zul'Aman.** Zul'Aman sense is covered by phrases (`го за`, `кто на за`). This avoids the gold-trade mistranslation `продам за 5к` → "WTS Zul'Aman 5K".
6. **`боты` defaults to `boots` (gear), not `bots`.** Gear context dominates in LFG/trade chat. The "bots" sense is caught by phrases `боты пишут`, `все боты`.
7. **Multi-case coverage for high-frequency nouns.** Russian has 6 cases × 2 numbers; we explicitly add 6-8 forms per important noun (instances, classes, gear, stats) because surface-form matching can't derive them.
8. **Homonym handling via phrases.** When the same token means different things in different contexts (e.g. `маг` = "mage" or "Magtheridon"), let the standalone entry take the common sense and override via specific phrases (`го маг` → Magtheridon).
9. **Preprocessors are word-boundary-aware.** `28 крита` used to become `28Kрита` (v0.5 bug) — fixed by requiring that the character after the suffix is not a Cyrillic lead-byte or ASCII word char.
10. **Registering 19 chat events** (every player-visible channel): SAY/YELL/PARTY/RAID\*/GUILD/OFFICER/WHISPER\*/CHANNEL/EMOTE\*/MONSTER\*/BATTLEGROUND\*. Users who see "only Global works" usually haven't had Russian in party/raid chat yet; it works there too.

## Code conventions

- Top of every Lua file: shared-namespace global pattern:
  ```lua
  RussianTranslatorNS = RussianTranslatorNS or {}
  local ns = RussianTranslatorNS
  ```
- No `Mixin`, no `Enum.*`, no `C_*`.
- No animation XML blocks. Tweens via `OnUpdate` + `SetAlpha`/`SetPoint`.
- `hooksecurefunc` never `rawset` Blizzard globals.
- `print` is fine for dev logging; user-facing messages go via `Msg(...)` helper which prefixes with `|cff55ddff[RT]|r`.
- Comments explain **why** (non-obvious constraints, past bugs, design rationale). Don't document **what** (the code shows it).

## What to push back on if the user asks

- Online translation via HTTP — no network in addon Lua sandbox.
- `C_*` namespace functions — don't exist on 2.4.3.
- `COMBAT_LOG_EVENT_UNFILTERED` — 3.0+. Parse `CHAT_MSG_COMBAT_*` / `CHAT_MSG_SPELL_*` instead.
- `RegisterAddonMessagePrefix` — 5.1+. On 2.4.3 all prefixes are delivered, just filter in `CHAT_MSG_ADDON`.
- `C_Timer.After` — 5.4+. Use `AceTimer-3.0` or `OnUpdate` accumulator.
- Multi-flavour TOC (`Interface-Classic: 11302` etc.) — Shadowlands+.

## Ongoing workflow when user returns

1. Check if there's a new `WoWChatLog.txt` in `C:\Gry\World of WarcraftOLD\Logs\` or a new `WoWChatLog_NNN.txt` in the repo root.
2. Run the coverage analysis Python snippet.
3. Add missing entries to `Dictionary.lua` in the relevant sections (don't dump them all at the bottom).
4. Verify coverage with a second simulation.
5. Bump to next patch version (0.9.3, 0.9.4, …), full release ritual.

If the user mentions a new feature or a bug/regression in translations, check the relevant part of `Core.lua` pipeline first (usually preprocessors or addressee detection). For dictionary issues, `Dictionary.lua`.
