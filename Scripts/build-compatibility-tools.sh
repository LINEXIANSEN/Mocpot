#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Standalone LGPL build: no Homebrew libraries, external codecs, network protocols or GPL components.
version=9.0.2
archive="${MOCPOT_FFMPEG_SOURCE:-/tmp/mocpot-ffmpeg-${version}.tar.xz}"
if [[ ! -f "$archive" ]]; then
    curl -fL --retry 3 "https://ffmpeg.org/releases/ffmpeg-${version}.tar.xz" -o "$archive"
fi
expected=8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
actual=$(shasum -a 256 "$archive" | awk '{print $1}')
if [[ "$actual" != "$expected" ]]; then
    echo "FFmpeg source checksum mismatch: $archive" >&2
    exit 1
fi
build_dir=$(mktemp -d /tmp/mocpot-ffmpeg-build.XXXXXX)
tar -xf "$archive" -C "$build_dir"
source_dir="$build_dir/ffmpeg-$version"
output_dir="$PWD/Vendor/FFmpeg/Helpers"
mkdir -p "$output_dir"
cd "$source_dir"
./configure --prefix="$build_dir/install" --cc=clang --extra-cflags=-mmacosx-version-min=13.0 --extra-ldflags=-mmacosx-version-min=13.0 \
    --disable-autodetect --disable-shared --enable-static --disable-network --disable-doc --disable-debug --disable-ffplay --disable-avdevice \
    --enable-videotoolbox --enable-audiotoolbox \
    --disable-encoders --enable-encoder=aac,h264_videotoolbox,subrip \
    --disable-muxers --enable-muxer=mov,srt \
    --disable-demuxers --enable-demuxer=mov,matroska,avi,asf,mpegps,mpegts,flv,ogg,rm \
    --disable-protocols --enable-protocol=file,pipe \
    --disable-filters --enable-filter=aresample,format,aformat,scale,pad,anull,null
make -j 8 ffmpeg ffprobe
cp ffmpeg ffprobe COPYING.LGPLv2.1 LICENSE.md "$output_dir/"
cp ffbuild/config.mak "$output_dir/build-config.txt"
shasum -a 256 "$archive" > "$output_dir/source-sha256.txt"
for tool in ffmpeg ffprobe; do
    codesign --force --sign - "$output_dir/$tool"
    otool -L "$output_dir/$tool"
done
