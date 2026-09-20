# Local compatibility helper

Mocpot invokes standalone FFmpeg and ffprobe executables for local compatibility conversion. System-decodable media bypasses these helpers. There is no Homebrew dependency in the installed application.

Build: `Scripts/build-compatibility-tools.sh` (macOS, Xcode command-line tools, make). The current release builds for Apple Silicon with a macOS 13 deployment target. No Intel/universal compatibility is claimed.

Source: https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz
SHA-256: `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e`

The unmodified upstream source, build script and exact build configuration reproduce these executables. GPL/nonfree components, external libraries, networking and device capture are disabled. The included executables are licensed under LGPL v2.1 or later; copies of upstream license notices and configuration are shipped alongside them in the application Resources/Helpers directory. FFmpeg is a trademark of Fabrice Bellard, originator of the FFmpeg project. See https://ffmpeg.org/ for the project.

Release source archive: attached as `ffmpeg-9.0.2.tar.xz` to the corresponding Mocpot release. `Helpers/` contains generated binaries and is excluded from git.
