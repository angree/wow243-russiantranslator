# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

Build a **Russian-language translator addon for World of Warcraft 2.4.3 (The Burning Crusade, build 8606)** — typically a private-server target. The addon rewrites incoming chat / quest / gossip / tooltip text into Russian and ensures it renders with a Cyrillic-capable font on clients whose default fonts lack Cyrillic glyphs.

The repo currently contains no code. Treat `WOW_2_4_3_ADDON_GUIDE.md` as the authoritative spec for what is and isn't possible on the target client.

## Primary reference

**Always read `WOW_2_4_3_ADDON_GUIDE.md` before writing or modifying Lua/XML/TOC files.** Its §11 compatibility table is the single source of truth for what API/events/templates exist in 2.4.3. Do not rely on Wowpedia/WarcraftWiki articles that describe modern retail behaviour — many APIs documented there (the entire `C_*` namespace, `COMBAT_LOG_EVENT_UNFILTERED`, `C_Timer`, `AnimationGroup`, `BackdropTemplate`, multi-line `## Interface`, `Mixin`, `Enum`, etc.) **do not exist** on 2.4.3 and will silently break.

## Build / test / run

There is no build step, no test runner, no package manager. Workflow:

1. Edit files in the repo at `i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator\RussianTranslator\`.
2. Run `sync.bat` from the repo root — it `robocopy /MIR`s the addon folder into the WoW install at `C:\Gry\World of WarcraftOLD\Interface\AddOns\RussianTranslator\`. Symlinks aren't used because the repo (`I:`) and WoW (`C:`) are on different volumes, which rules out `mklink /J` (junctions must stay on one volume).
3. In game: `/reload` (or `ReloadUI()`) picks up Lua/XML changes. TOC changes require a full client restart OR a `/reload` after toggling the addon at character select.
4. Errors surface as red popups if `/console scriptErrors 1` is on; BugSack/BugGrabber (TBC-compatible) capture them otherwise.
5. SavedVariables live in `C:\Gry\World of WarcraftOLD\WTF\Account\<ACCOUNT>\SavedVariables\RussianTranslator.lua` — flushed at `/reload` or clean logout. That file is the source of session logs (including the dictionary-growth `unknowns` table).

When the user asks for a "test", that means a manual in-game check — we have no automation.

## Hard constraints specific to this target

- **TOC**: `## Interface: 20400` (single line, no BOM). Any other number either marks the addon out-of-date or refuses to load.
- **Lua**: 5.1 sandbox. No `io`, no `package`, no network. Bundled dictionary / offline translation only.
- **Text encoding**: save every source file as **UTF-8 without BOM** (Lua files tolerate BOM, `.toc` files do NOT).
- **Strings with Cyrillic**: `#s` and `string.sub` operate on bytes. Always use a UTF-8-aware truncator.
- **Fonts**: 2.4.3 accepts **TTF** only (no OTF). Default Western Blizzard fonts cannot render Cyrillic — ship a Cyrillic-capable TTF and apply it to `ChatFrame1..ChatFrame7` (re-apply on `UPDATE_CHAT_WINDOWS`, `CVAR_UPDATE`).
- **Textures**: **BLP** only; PNG is ignored.
- **Chat length**: 255 bytes per outbound `SendChatMessage` — budget ~127 characters when sending Cyrillic.
- **Taint**: never overwrite a Blizzard global function. Use `hooksecurefunc`, `frame:HookScript`, or `ChatFrame_AddMessageEventFilter`. Never `setfenv` Blizzard code.
- **Combat lockdown**: this addon should not need protected functionality. Stay away from action buttons / unit frames / key bindings during combat.

## Architecture (intended)

Once code exists, the expected shape is:

```
<AddonName>/
  <AddonName>.toc         single-line ## Interface: 20400, no BOM
  libs/                   embedded LibStub + selected Ace3 modules
  Localization.lua        AceLocale-3.0 tables keyed by GetLocale()
  Dictionary/             bundled phrasebook data, loaded at init
  Core.lua                AceAddon entry point; wires filters & hooks
  UI.xml + UI.lua         optional config panel
  fonts/                  bundled Cyrillic TTF
```

Core responsibilities (one per file ideally):
- **Chat pipeline**: `ChatFrame_AddMessageEventFilter` for every `CHAT_MSG_*` the user cares about; rewrite `arg1`, pass the tuple back.
- **Quest / gossip pipeline**: hook `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`, `QUEST_GREETING`, `GOSSIP_SHOW`; read `GetQuestText`/`GetGossipText` and overwrite the relevant `QuestFrame*` / `GossipFrame*` FontStrings before the user reads them.
- **Tooltip pipeline**: hook `OnTooltipSetUnit`/`OnTooltipSetItem`/`OnTooltipSetSpell` on `GameTooltip`, walk `GameTooltipTextLeft<n>`/`Right<n>`. Do NOT translate on every `OnUpdate`.
- **Font injection**: apply the bundled TTF to every chat window and quest/tooltip FontString; reapply on relevant events.
- **SavedVariables**: `RT_DB` (account) for dictionary extensions, `RT_CHAR` (per-character) for enable toggles.

## Code conventions

- Top of every Lua file: `local addonName, ns = ...` — use `ns` instead of polluting `_G`.
- Prefer `AceEvent-3.0`'s `self:RegisterEvent` over raw frame event handlers once AceAddon is in.
- Use `hooksecurefunc` — never rawset Blizzard globals.
- No animation XML blocks (unsupported). Fades / tweens go through `OnUpdate` + `SetAlpha`.
- No `Mixin`, no `Enum.*`, no `C_*` — rewrite snippets that use them.
- `print` is fine for dev logging but `DEFAULT_CHAT_FRAME:AddMessage("|cff55ddff[RT]|r "..msg)` is what the user should see.

## What I should push back on

If the user asks for any of the following, remind them of the 2.4.3 constraint before implementing:
- Online translation via HTTP — not possible, no network access from addon Lua.
- Using `C_*` namespace functions — don't exist.
- Using `COMBAT_LOG_EVENT_UNFILTERED` — must parse `CHAT_MSG_COMBAT_*`/`CHAT_MSG_SPELL_*` instead.
- Cross-addon comms with `RegisterAddonMessagePrefix` — not in 2.4.3; just use `CHAT_MSG_ADDON` and filter by prefix.
- `C_Timer.After` — use `AceTimer-3.0` or an `OnUpdate` accumulator.
- Animations via `<Animations>` XML — must be written as `OnUpdate` tweens.
- Modern TOC features (multi-flavour, `Interface-Classic`, etc.) — single `## Interface: 20400` only.
