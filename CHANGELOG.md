# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.4.0] - 2026-04-19

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
