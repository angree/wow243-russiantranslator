#!/usr/bin/env python3
"""Filter stdin lines into russian|english format, append to output file."""
import sys, re, io

# Force UTF-8 stdin/stdout
sys.stdin.reconfigure(encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8')

out_path = sys.argv[1] if len(sys.argv) > 1 else None
lines_out = []

text = sys.stdin.read()
text = text.replace('\u0301', '')  # strip acute accent

for line in text.splitlines():
    line = line.strip()
    if '|' not in line:
        continue
    if line.startswith('```') or line.startswith('#'):
        continue
    parts = line.split('|', 1)
    if len(parts) != 2:
        continue
    ru = parts[0].strip().lower()
    en = parts[1].strip().lower()
    if not ru or not en:
        continue
    if not re.search(r'[а-яё]', ru):
        continue
    # strip combining marks and extra whitespace
    ru = re.sub(r'\s+', ' ', ru)
    en = re.sub(r'\s+', ' ', en)
    lines_out.append(f"{ru}|{en}")

if out_path:
    with open(out_path, 'a', encoding='utf-8') as f:
        for l in lines_out:
            f.write(l + '\n')
    print(f"appended {len(lines_out)} lines")
else:
    for l in lines_out:
        print(l)
