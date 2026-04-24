#!/usr/bin/env python3
"""Stream-parse kaikki.org Russian JSONL files and emit word|english pairs.

Downloads per-POS JSONL files from kaikki.org, extracts the Russian lemma
and a short English gloss (first 1-3 content words of the first sense's
first gloss), filters out non-Cyrillic / overly-long entries, deduplicates
(first occurrence wins), and writes lowercase pipe-separated output.
"""

from __future__ import annotations

import io
import json
import re
import sys
import urllib.request
from pathlib import Path

POS_FILES = [
    # (pos_slug, approx_bytes) - download order: small first
    "conj",
    "particle",
    "prep",
    "det",
    "phrase",
    "intj",
    "pron",
    "num",
    "adv",
    "name",
    "adj",
    "noun",
    "verb",
]

BASE_URL = "https://kaikki.org/dictionary/Russian/pos-{pos}/kaikki.org-dictionary-Russian-by-pos-{pos}.jsonl"
OUT_PATH = Path(r"i:/PROGRAMOWANIE_CLAUDE/Addon_Russian_Translator/kaikki_russian.txt")

# Cyrillic range incl. ё, й — and hyphen/space for hyphenated lemmas
CYRILLIC_RE = re.compile(r"^[а-яёА-ЯЁ\- ]+$")
# strip leading parens / bracketed qualifiers from glosses
PARENTHETICAL_RE = re.compile(r"\([^)]*\)")
BRACKETS_RE = re.compile(r"\[[^\]]*\]")
# grammar tags often prefixing glosses: "(transitive) to run" etc.
LEADING_TAG_RE = re.compile(r"^\s*\([^)]*\)\s*")

# noise markers indicating meta-Wiktionary / non-translation glosses
SKIP_GLOSS_PREFIXES = (
    "alternative form",
    "alternative spelling",
    "diminutive of",
    "augmentative of",
    "pejorative of",
    "abbreviation of",
    "contraction of",
    "obsolete form",
    "obsolete spelling",
    "pre-reform spelling",
    "romanization of",
    "superseded spelling",
    "superlative of",
    "comparative of",
    "vocative of",
    "genitive of",
    "accusative of",
    "dative of",
    "feminine of",
    "masculine of",
    "neuter of",
    "plural of",
    "singular of",
    "inflection of",
    "participle of",
    "gerund of",
    "infinitive of",
    "past tense of",
    "verbal noun of",
    "reflexive of",
    "nominative plural",
    "see ",
    "synonym of",
)


def clean_gloss(raw: str) -> str:
    """Strip leading grammar tags, parentheticals, brackets; keep first 1-3 words."""
    g = raw.strip()
    # drop ALL parenthetical / bracketed content
    g = PARENTHETICAL_RE.sub("", g)
    g = BRACKETS_RE.sub("", g)
    g = g.strip(" ;,.:\"'")
    # cut at first ; , : or the word "usually" / "esp"
    for sep in (";", ", ", " — ", " - ", ": "):
        idx = g.find(sep)
        if idx > 0:
            g = g[:idx]
            break
    # collapse whitespace
    g = " ".join(g.split())
    # keep up to 3 words, but preserve common multi-word phrases of 4 if short
    words = g.split()
    if len(words) > 3:
        g = " ".join(words[:3])
    return g.lower().strip()


def extract_pair(entry: dict) -> tuple[str, str] | None:
    word = entry.get("word", "").strip()
    if not word:
        return None
    word_lower = word.lower()
    if len(word_lower) > 20 or len(word_lower) < 2:
        return None
    if not CYRILLIC_RE.match(word_lower):
        return None
    senses = entry.get("senses") or []
    for sense in senses:
        glosses = sense.get("glosses") or []
        if not glosses:
            continue
        raw = glosses[0]
        if not isinstance(raw, str):
            continue
        low = raw.lower().lstrip()
        # drop any leading "(tag)" for the prefix check
        stripped = LEADING_TAG_RE.sub("", low)
        if any(stripped.startswith(p) for p in SKIP_GLOSS_PREFIXES):
            continue
        cleaned = clean_gloss(raw)
        if not cleaned:
            continue
        # final sanity: gloss must contain only ASCII letters/space/hyphen/apostrophe
        if not re.match(r"^[a-z][a-z'\- ]*$", cleaned):
            continue
        if len(cleaned) > 40:
            continue
        return (word_lower, cleaned)
    return None


def stream_pos(pos: str, seen: dict[str, str], stats: dict) -> None:
    url = BASE_URL.format(pos=pos)
    print(f"[{pos}] fetching {url}", file=sys.stderr, flush=True)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    n_lines = 0
    n_added = 0
    with urllib.request.urlopen(req, timeout=120) as resp:
        reader = io.TextIOWrapper(resp, encoding="utf-8", errors="replace", newline="")
        for line in reader:
            line = line.strip()
            if not line:
                continue
            n_lines += 1
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                stats["parse_errors"] += 1
                continue
            pair = extract_pair(entry)
            if pair is None:
                continue
            w, g = pair
            if w in seen:
                continue
            seen[w] = g
            n_added += 1
    print(f"[{pos}] lines={n_lines} added={n_added} total={len(seen)}", file=sys.stderr, flush=True)
    stats["lines"] += n_lines


def main() -> int:
    seen: dict[str, str] = {}
    stats = {"lines": 0, "parse_errors": 0}
    for pos in POS_FILES:
        try:
            stream_pos(pos, seen, stats)
        except Exception as exc:
            print(f"[{pos}] ERROR: {exc}", file=sys.stderr, flush=True)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8", newline="\n") as fh:
        for w in sorted(seen):
            fh.write(f"{w}|{seen[w]}\n")
    print(f"wrote {len(seen)} entries to {OUT_PATH}", file=sys.stderr)
    print(f"total-lines={stats['lines']} parse-errors={stats['parse_errors']}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
