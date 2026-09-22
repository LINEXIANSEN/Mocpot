# Direct playback runtime

Mocpot uses a dynamically loaded **LGPL build of libmpv 0.41.0** with FFmpeg 9.0.2 for direct local playback. AVFoundation remains the path for decodable MP4/MOV files. The runtime is bundled inside the application; installing Homebrew, mpv or VLC is not required.

Build with `python3 Scripts/build-direct-playback.py`. Source archives and SHA-256 checksums are pinned in `sources.json`; set `MOCPOT_DIRECT_SOURCES` to a directory containing those archives to build offline after Python build tools are installed. Requires Apple Silicon, Xcode command-line tools and Python 3. The binaries target macOS 13.0; system frameworks and bundled libraries are the only runtime dependencies.

The build disables GPL features, scripting, network protocols, external codecs, hardware not available on macOS and the mpv command-line application. Playback additionally disables user configurations, scripts, automatic external-file discovery and referenced playlists. Each release includes corresponding source archives and the build scripts; notices are copied into `DirectPlayback/Licenses`. The C client/render headers here retain their upstream permissive notices.

The included CoreAudio patch passes `AudioChannelLayout` to the matching input-layout property, rather than the integer-array channel-map property. The upstream call is rejected on macOS 27 (mpv issue #18384). This patch is applied by the build script and included with the corresponding source.

`Tests/run-direct.sh <format-fixture-directory>` verifies real OpenGL rendering, pause/seek, subtitles and absence of conversion files with the conversion helper deliberately unavailable. Software decoding is used when VideoToolbox cannot handle a codec. System Picture in Picture is currently available only through AVFoundation.
