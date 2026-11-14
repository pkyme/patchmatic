"""Regenerates the per-file platform filters on the app's synchronized folder, so every
file under Patchmatic/Patchmatic/macOS builds only for macOS and every file under
Patchmatic/Patchmatic/iPad builds only for iPadOS.

Usage: python3 scripts/sync_platform_filters.py
"""
import os, re
repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
proj = os.path.join(repo, 'Patchmatic/Patchmatic.xcodeproj/project.pbxproj')
root = os.path.join(repo, 'Patchmatic/Patchmatic')
s = open(proj).read()
entries = []
for plat, folder in (('macos', 'macOS'), ('ios', 'iPad')):
    for dp, _, fs in os.walk(os.path.join(root, folder)):
        for f in sorted(fs):
            if not f.startswith('.'):
                entries.append((os.path.relpath(os.path.join(dp, f), root), plat))
entries.sort()
q = lambda x: x if re.fullmatch(r'[A-Za-z0-9_./]+', x) else '"' + x + '"'
body = ''.join(f"\t\t\t\t{q(r)} = (\n\t\t\t\t\t{p},\n\t\t\t\t);\n" for r, p in entries)
old = re.search(r'\t\t\tplatformFiltersByRelativePath = \{\n.*?\n\t\t\t\};', s, re.S).group(0)
open(proj, 'w').write(s.replace(old, "\t\t\tplatformFiltersByRelativePath = {\n" + body + "\t\t\t};"))
print(len(entries), 'entries')
