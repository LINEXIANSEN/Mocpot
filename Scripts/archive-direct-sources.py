#!/usr/bin/env python3
"""Create the corresponding-source archive shipped with a binary release."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
import tarfile
import tempfile

repo = Path(__file__).resolve().parents[1]
root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path(tempfile.mkdtemp(prefix='mocpot-source-release-'))
root.mkdir(parents=True, exist_ok=True)
sources = json.loads((repo / 'Vendor/MPV/sources.json').read_text())

def fetch(entry):
    name, source = entry
    target = root / source['archive']
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == source['sha256']:
        print('Verified cached source:', name, flush=True)
        return
    url = source['url']
    if name == 'ffmpeg':
        # The same pinned source also accompanies the earlier compatibility helper.
        url = 'https://github.com/LINEXIANSEN/Mocpot/releases/download/v1.2.5/ffmpeg-9.0.2.tar.xz'
    if name == 'ffmpeg':
        subprocess.run(['gh', 'release', 'download', 'v1.2.5', '--repo', 'LINEXIANSEN/Mocpot', '--pattern', source['archive'], '--dir', str(root), '--clobber'], check=True)
    else:
        subprocess.run(['curl', '-fsSL', '--connect-timeout', '20', '--max-time', '600', '--retry', '3', url, '-o', str(target)], check=True)
    if hashlib.sha256(target.read_bytes()).hexdigest() != source['sha256']:
        raise RuntimeError('Source checksum mismatch: ' + name)
    print('Verified source:', name, flush=True)

with ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(fetch, sources.items()))
shutil.copy2(repo / 'Vendor/MPV/sources.json', root / 'sources.json')
shutil.copy2(repo / 'Vendor/MPV/README.md', root / 'README.md')
for name in ['build-direct-playback.py', 'bundle-direct-playback.py']:
    shutil.copy2(repo / 'Scripts' / name, root / name)
shutil.copytree(repo / 'Vendor/MPV/patches', root / 'patches', dirs_exist_ok=True)
destination = Path(sys.argv[1]).resolve()
with tarfile.open(destination, 'w:xz') as archive:
    archive.add(root, arcname='Mocpot-decoder-sources')
print(destination, flush=True)
