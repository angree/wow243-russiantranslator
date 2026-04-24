"""Honest coverage analyzer — dedups repeated messages before measuring.

v1.2.0's 99.45% was inflated by repeated spam (guild recruit copy-pasted
100+ times). Each repetition added 20 tokens to the "covered" pile, skewing
the metric toward "perfect."

This analyzer:
  1. Dedupes identical Russian messages.
  2. Reports tokens on UNIQUE messages only.
  3. Reports per-message coverage distribution, not just aggregate tokens.
"""
import re, sys, collections, pathlib
from analyze_coverage import (
    load_dict, normalize, preprocess, apply_phrases, tokenize,
    LEMMA_RULES, lemmatize, LINE_RE, parse_line, CYR_ANY
)

ROOT = pathlib.Path(r"i:\PROGRAMOWANIE_CLAUDE\Addon_Russian_Translator")
LOG = ROOT / "WoWChatLog_latest.txt"


def main():
    phrases, words = load_dict()
    phrases_sorted = sorted(phrases.keys(), key=len, reverse=True)
    raw = LOG.read_bytes().decode("utf-8", errors="replace")

    # Dedup: keep one of each distinct (sender-independent) message.
    unique_msgs = collections.OrderedDict()
    all_msgs = 0
    for line in raw.splitlines():
        sender, msg = parse_line(line)
        if not sender or not msg:
            continue
        if not CYR_ANY.search(msg):
            continue
        all_msgs += 1
        key = msg.strip()
        if key not in unique_msgs:
            unique_msgs[key] = None

    print(f"Raw Russian messages:     {all_msgs}")
    print(f"Unique Russian messages:  {len(unique_msgs)}")
    print(f"Spam multiplier:          {all_msgs/max(1,len(unique_msgs)):.1f}×")
    print()

    # Measure on unique messages only.
    total_tokens = 0
    covered_tokens = 0
    msg_stats = []  # list of (covered_pct, token_count)
    unknown_ctr = collections.Counter()
    unknown_ctx = {}

    for msg in unique_msgs:
        low = preprocess(normalize(msg))
        low = apply_phrases(low, phrases_sorted)
        toks = tokenize(low)
        msg_total = 0
        msg_covered = 0
        for t in toks:
            msg_total += 1
            total_tokens += 1
            if t in words or lemmatize(t, words) is not None:
                msg_covered += 1
                covered_tokens += 1
            else:
                unknown_ctr[t] += 1
                if t not in unknown_ctx:
                    unknown_ctx[t] = msg[:100]
        if msg_total > 0:
            msg_stats.append((msg_covered / msg_total, msg_total))

    token_pct = 100 * covered_tokens / total_tokens if total_tokens else 0
    print(f"=== TOKEN-WEIGHTED (unique messages only) ===")
    print(f"Tokens: {total_tokens:,}  covered: {covered_tokens:,}  "
          f"coverage: {token_pct:.2f}%")
    print()

    # Per-message coverage distribution.
    msg_stats.sort(key=lambda x: x[0])
    full_msgs = sum(1 for c, _ in msg_stats if c == 1.0)
    above_90 = sum(1 for c, _ in msg_stats if c >= 0.9)
    above_80 = sum(1 for c, _ in msg_stats if c >= 0.8)
    above_70 = sum(1 for c, _ in msg_stats if c >= 0.7)
    below_50 = sum(1 for c, _ in msg_stats if c < 0.5)

    print(f"=== PER-MESSAGE DISTRIBUTION ({len(msg_stats)} unique msgs) ===")
    print(f"  100% translated: {full_msgs:>5}  ({100*full_msgs/len(msg_stats):.1f}%)")
    print(f"  ≥90% translated: {above_90:>5}  ({100*above_90/len(msg_stats):.1f}%)")
    print(f"  ≥80% translated: {above_80:>5}  ({100*above_80/len(msg_stats):.1f}%)")
    print(f"  ≥70% translated: {above_70:>5}  ({100*above_70/len(msg_stats):.1f}%)")
    print(f"  <50% translated: {below_50:>5}  ({100*below_50/len(msg_stats):.1f}%)")
    print()

    # Average per-message coverage (unweighted — each message equal).
    avg_per_msg = sum(c for c, _ in msg_stats) / len(msg_stats) * 100
    print(f"=== AVERAGE PER-MESSAGE COVERAGE ===")
    print(f"  Mean coverage across messages: {avg_per_msg:.2f}%")
    print(f"  (Each message counts once, regardless of length)")
    print()

    # Top unknowns on unique messages
    print(f"=== TOP 30 UNKNOWNS ON UNIQUE MESSAGES ===")
    for tok, n in unknown_ctr.most_common(30):
        print(f"  {n:>3}  {tok:<20}  | {unknown_ctx[tok]}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
