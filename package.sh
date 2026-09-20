#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -x Vendor/FFmpeg/Helpers/ffmpeg || ! -x Vendor/FFmpeg/Helpers/ffprobe ]]; then
    Scripts/build-compatibility-tools.sh
fi
build_dir=$(mktemp -d /tmp/mocpot-release.XXXXXX)
xcodebuild -project Mocpot.xcodeproj -scheme Mocpot -configuration Release -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build
app="$build_dir/Build/Products/Release/Mocpot.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
for tool in ffmpeg ffprobe; do
    codesign --force --sign - "$app/Contents/Resources/Helpers/$tool"
    "$app/Contents/Resources/Helpers/$tool" -version >/dev/null
done
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
stage=$(mktemp -d /tmp/mocpot-stage.XXXXXX)
ditto "$app" "$stage/Mocpot.app"
ln -s /Applications "$stage/Applications"
output="${MOCPOT_OUTPUT_DIR:-$(dirname "$PWD")}/Mocpot-$version.dmg"
hdiutil create -volname "Mocpot $version" -srcfolder "$stage" -ov -format UDZO "$output"
hdiutil verify "$output"
echo "$output"
