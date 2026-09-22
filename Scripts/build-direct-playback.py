#!/usr/bin/env python3
"""Build an LGPL, local-file-only direct decoder for Apple Silicon/macOS 13+."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys, tempfile
repo = Path(__file__).resolve().parents[1]
root = Path(tempfile.mkdtemp(prefix='mocpot-direct-'))
archives = Path(os.environ.get('MOCPOT_DIRECT_SOURCES', root/'archives')); archives.mkdir(parents=True,exist_ok=True)
manifest = json.loads((repo/'Vendor/MPV/sources.json').read_text())
def run(args,cwd=root,env=None): subprocess.run([str(x) for x in args],cwd=cwd,env=env,check=True)
for name, source in manifest.items():
    archive = archives/source['archive']
    if not archive.exists(): run(['curl','-fL','--retry','3',source['url'],'-o',archive])
    if hashlib.sha256(archive.read_bytes()).hexdigest() != source['sha256']: raise RuntimeError('Source checksum mismatch: '+name)
    folder=root/name; folder.mkdir()
    run(['tar','-xf',archive,'-C',folder,'--strip-components=1'])
run(['patch', '-p1', '-i', repo/'Vendor/MPV/patches/coreaudio-channel-layout.patch'], root/'mpv')
run([sys.executable,'-m','venv',root/'venv'])
run([root/'venv/bin/pip','install','meson==1.12.0','ninja==1.13.2','pkgconf==3.0.1.post0','jinja2==3.1.6'])
pkgconf = subprocess.check_output([root/'venv/bin/python','-c','import pkgconf; print(pkgconf.get_executable())'],text=True).strip()
env=os.environ.copy(); env.update(PATH=str(root/'venv/bin')+':'+env['PATH'],PKG_CONFIG=pkgconf,PKG_CONFIG_PATH=str(root/'deps/lib/pkgconfig'),MACOSX_DEPLOYMENT_TARGET='13.0')
def meson(name,options):
    args=['meson','setup','build','--prefix='+str(root/'deps'),'-Ddefault_library=shared','-Dbuildtype=release','-Dc_args=-mmacosx-version-min=13.0','-Dc_link_args=-mmacosx-version-min=13.0']+options
    run(args,root/name,env);run(['meson','compile','-C','build','-j','8'],root/name,env);run(['meson','install','-C','build'],root/name,env)
meson('freetype',['-Dzlib=disabled','-Dbzip2=disabled','-Dpng=disabled','-Dharfbuzz=disabled','-Dbrotli=disabled'])
meson('fribidi',['-Ddocs=false','-Dtests=false','-Dbin=false'])
meson('harfbuzz',['-Dauto_features=disabled','-Dcoretext=enabled','-Dtests=disabled','-Dutilities=disabled','-Ddocs=disabled','-Dcpp_args=-mmacosx-version-min=13.0','-Dcpp_link_args=-mmacosx-version-min=13.0'])
meson('libass',['-Dfontconfig=disabled','-Dcoretext=enabled','-Dlibunibreak=disabled','-Dtest=disabled','-Dcompare=disabled','-Dprofile=disabled','-Dfuzz=disabled','-Dcheckasm=disabled'])
for headers in ['vulkan','vk_video']: shutil.copytree(root/'vulkan/include'/headers,root/'deps/include'/headers)
shutil.copytree(root/'fast_float/include/fast_float', root/'deps/include/fast_float')
meson('placebo',['-Dauto_features=disabled','-Ddemos=false','-Dtests=false','-Dc_args=-mmacosx-version-min=13.0 -I'+str(root/'deps/include'),'-Dcpp_args=-mmacosx-version-min=13.0 -I'+str(root/'deps/include'),'-Dcpp_link_args=-mmacosx-version-min=13.0'])
run(['./configure','--prefix='+str(root/'deps'),'--cc=clang','--extra-cflags=-mmacosx-version-min=13.0','--extra-ldflags=-mmacosx-version-min=13.0','--disable-autodetect','--enable-shared','--disable-static','--disable-network','--disable-doc','--disable-debug','--disable-programs','--enable-videotoolbox','--enable-audiotoolbox','--disable-encoders','--disable-muxers','--disable-demuxers','--enable-demuxer=mov,matroska,avi,asf,mpegps,mpegts,flv,ogg,rm','--disable-protocols','--enable-protocol=file,pipe'],root/'ffmpeg',env)
run(['make','-j','8'],root/'ffmpeg',env);run(['make','install'],root/'ffmpeg',env)
meson('mpv',['-Dauto_features=disabled','-Dgpl=false','-Dcplayer=false','-Dlibmpv=true','-Dgl=enabled','-Dcocoa=enabled','-Dgl-cocoa=enabled','-Dcoreaudio=enabled','-Dvideotoolbox-gl=enabled','-Dswift-build=enabled','-Dswift-flags=-target arm64-apple-macos13.0'])
run([sys.executable,repo/'Scripts/bundle-direct-playback.py',root,repo/'Vendor/MPV/DirectPlayback'])
shutil.copy2(repo/'Vendor/MPV/sources.json',repo/'Vendor/MPV/DirectPlayback/sources.json')
print('Build directory and corresponding sources:',root)
