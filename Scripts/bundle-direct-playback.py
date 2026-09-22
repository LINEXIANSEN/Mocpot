#!/usr/bin/env python3
"""Bundle only self-built dylibs, with relative install names and their notices."""
from pathlib import Path
import subprocess, shutil, sys, json, hashlib
root = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=True)
seen = set()
def dependencies(path):
    return [line.strip().split(' (compatibility')[0] for line in subprocess.check_output(['otool','-L',str(path)], text=True).splitlines()[1:] if line.startswith('\t')]
def collect(source):
    if source.name in seen: return
    if not source.resolve().is_relative_to(root): raise RuntimeError('Non-portable dependency: '+str(source))
    seen.add(source.name)
    target = output/source.name
    shutil.copy2(source, target)
    target.chmod(0o755)
    for dependency in dependencies(source)[1:]:
        if dependency.startswith(('/usr/lib/', '/System/Library/')): continue
        if dependency.startswith('@rpath/libswift'): continue
        child = Path(dependency)
        if dependency.startswith('@rpath/'): child = root/'deps/lib'/child.name
        if not child.is_absolute(): raise RuntimeError('Unresolved dependency: '+dependency)
        collect(child)
        subprocess.run(['install_name_tool','-change',dependency,'@loader_path/'+child.name,str(target)], check=True)
    subprocess.run(['install_name_tool','-id','@loader_path/'+source.name,str(target)], check=True)
collect(root/'deps/lib/libmpv.2.dylib')
for path in output.glob('*.dylib'):
    if path.name not in seen: path.unlink()
    else:
        for dependency in dependencies(path):
            if dependency.startswith(('/tmp/', '/private/tmp/', '/opt/homebrew/')): raise RuntimeError('Unbundled dependency: '+dependency)
        subprocess.run(['codesign','--force','--sign','-',str(path)],check=True)
notices = output/'Licenses'; notices.mkdir(exist_ok=True)
for name in ['mpv','ffmpeg','placebo','libass','fribidi','freetype','harfbuzz','fast_float']:
    destination = notices/name; destination.mkdir(exist_ok=True)
    for file in (root/name).iterdir():
        if file.is_file() and file.name.upper().startswith(('COPYING','LICENSE','COPYRIGHT')): shutil.copy2(file,destination/file.name)
    if name == 'freetype': shutil.copy2(root/name/'docs/FTL.TXT',destination/'FTL.TXT')
repo = Path(__file__).resolve().parents[1]
shutil.copy2(repo/'Vendor/MPV/patches/coreaudio-channel-layout.patch', notices/'mpv/coreaudio-channel-layout.patch')
shutil.copy2(repo/'Vendor/MPV/README.md', output/'README.md')
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.dylib')}
(output/'sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Bundled {len(seen)} libraries into {output}')
