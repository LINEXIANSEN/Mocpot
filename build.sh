#!/bin/bash

echo "Building Mocpot..."
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed."
    echo "Please install Xcode from the Mac App Store."
    exit 1
fi

# Check if xcodeproj exists
if [ ! -d "Mocpot.xcodeproj" ]; then
    echo "Error: Mocpot.xcodeproj not found."
    echo "Please run this script from the project root directory."
    exit 1
fi

# Build the project
if [ ! -x Vendor/FFmpeg/Helpers/ffmpeg ]; then
    Scripts/build-compatibility-tools.sh || exit 1
fi
if [ ! -f Vendor/MPV/DirectPlayback/libmpv.2.dylib ]; then
    python3 Scripts/build-direct-playback.py || exit 1
fi
echo "Building with xcodebuild..."
xcodebuild -project Mocpot.xcodeproj \
           -scheme Mocpot \
           -configuration Debug \
           build

if [ $? -eq 0 ]; then
    echo ""
    echo "Build successful!"
    echo "The app is in: ~/Library/Developer/Xcode/DerivedData/"
    echo ""
    echo "To create a standalone app bundle:"
    echo "  xcodebuild -project Mocpot.xcodeproj -scheme Mocpot -configuration Release build"
else
    echo ""
    echo "Build failed. Please check the errors above."
    exit 1
fi
