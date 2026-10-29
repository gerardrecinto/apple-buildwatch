#!/usr/bin/env python3
"""Assemble the browser demo from the same Swift rules used by the CLI."""
import json
from pathlib import Path
import re
import shutil

root = Path(__file__).resolve().parents[1]
output = root / '_site'
output.mkdir(exist_ok=True)
shutil.copytree(root / 'site', output, dirs_exist_ok=True)
shutil.copytree(root / 'fixtures', output / 'fixtures', dirs_exist_ok=True)
source = (root / 'Sources/BuildWatch/LogClassifier.swift').read_text()
pattern = re.compile(r'Rule\(\s*kind: \.(\w+),\s*pattern: #"(.*?)"#,\s*summary: "((?:[^"\\]|\\.)*)",\s*action: "((?:[^"\\]|\\.)*)",\s*confidence: ([0-9.]+)\s*\)', re.S)
rules = []
for kind, regex, summary, action, confidence in pattern.findall(source):
    rules.append({
        'kind': re.sub(r'([A-Z])', lambda m: '_' + m[1].lower(), kind),
        'pattern': regex,
        'summary': json.loads('"' + summary + '"'),
        'action': json.loads('"' + action + '"'),
        'confidence': float(confidence),
    })
expected = len(re.findall(r'\bRule\(\s*kind:', source))
if not rules or len(rules) != expected:
    raise SystemExit(f'Rule extraction mismatch: {len(rules)} of {expected}')
(output / 'rules.json').write_text(json.dumps(rules))
(output / '.nojekyll').touch()
print(f'Assembled {len(rules)} Swift rules and local fixtures in {output}')
