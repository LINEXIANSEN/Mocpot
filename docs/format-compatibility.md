# Format compatibility in 1.3.0

Mocpot includes a local-file-only LGPL libmpv/FFmpeg decoder. WebM, MKV, AVI, WMV, FLV and MPEG-TS open without whole-file conversion or intermediate movies. MP4/MOV/M4V/3GP files use AVFoundation when it can decode them; native failures can retry through the bundled decoder.

Original URLs remain the identity for playlists, history, resume positions and external subtitles. Direct playback supports pause, seek, speed, volume, audio tracks and delay, text subtitles and sync, screenshots, A/B looping and panoramic viewing. Hardware decoding is attempted when available, with software decoding for other codecs. Startup still requires decoder and renderer initialization.

## Limits

- The released runtime and DMG target Apple Silicon, macOS 13 or later. Intel binaries are not included.
- System Picture in Picture remains available only through AVFoundation; its button is disabled for direct playback.
- The text subtitle overlay does not reproduce bitmap subtitles (PGS/VobSub), attached fonts or complex ASS styling.
- HDR profiles and unusual codecs are not exhaustively validated. This is not DRM support or a guarantee for every file carrying a supported extension.
- Network protocols, scripts, user configuration, automatic external-file loading and referenced playlists are disabled.
- Legacy conversion helpers remain a fallback for development builds missing the direct runtime. Complete release bundles use direct decoding for these containers.

## Verification

`Tests/run-formats.sh` creates synthetic SDR fixtures and checks legacy compatibility helpers. `Tests/run-direct.sh <fixture-directory>` plays original fixtures through OpenGL with the conversion helper deliberately unavailable. It verifies CoreAudio output, pause/seek, audio-track switching and delay, embedded/external text subtitles, panoramic view changes, screenshot orientation and a two-minute seek. Source bytes remain unchanged and no conversion cache is created. `Tests/run.sh` covers native playback, settings and folder switching.

| Tested container and codecs | Release playback path |
|---|---|
| MP4, H.264 / HEVC + AAC | AVFoundation when decodable |
| WebM, VP9 + Opus | Bundled direct decoder |
| MKV, H.264 + AAC / DTS | Bundled direct decoder |
| AVI, MPEG-4 + MP3 | Bundled direct decoder |
| WMV, WMV2 + WMA2 | Bundled direct decoder |
| FLV, FLV1 + MP3 | Bundled direct decoder |
| TS, H.264 + AC-3 | Bundled direct decoder |

These tests cover specific combinations, not every resolution, profile or macOS release. Pinned sources, checksums, build instructions and the CoreAudio compatibility patch are documented in [Vendor/MPV](../Vendor/MPV/README.md). Corresponding decoder sources accompany the binary release.
