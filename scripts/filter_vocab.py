#!/usr/bin/env python3
import json

src = '/Users/coby/Git/jlpt-all-app/assets/data/vocab.json'
dst = '/Users/coby/Git/jlpt-app/assets/data/vocab.json'

with open(src, 'r', encoding='utf-8') as f:
    data = json.load(f)

print(f"Source total entries: {len(data)}")

# Count by level
from collections import Counter
level_counts = Counter(e.get('lv') for e in data)
print(f"Source level distribution: {dict(level_counts)}")

n1_entries = [e for e in data if e.get('lv') == 'n1']
print(f"N1 entries to write: {len(n1_entries)}")

with open(dst, 'w', encoding='utf-8') as f:
    json.dump(n1_entries, f, ensure_ascii=False, separators=(', ', ': '))

print("Done. Wrote to:", dst)
