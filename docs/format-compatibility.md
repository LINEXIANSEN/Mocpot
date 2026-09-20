# Format compatibility in 1.2.2

A file extension identifies a container, not whether its video/audio codec can be decoded. Mocpot tests a video frame and audio samples through AVFoundation before choosing a playback path.

1. If the system decodes the file, use it directly.
2. Otherwise, try copying video and all audio tracks into MOV without re-encoding.
3. If that fails validation, preserve video and encode audio as AAC.
4. If needed for SDR content, encode H.264 video through VideoToolbox and AAC audio. This is lossy and may take considerable time for large files. HDR that still cannot be decoded is rejected rather than silently converted to incorrect SDR colors.

Only successful, decoded results are cached. The source file is never overwritten. Original URLs remain the identity for history, resume positions, playlist entries, VR-name detection and external subtitles. Converted media is used for video rendering, audio timing and screenshots. Text subtitles (SRT/ASS/SSA/WebVTT/mov_text) are extracted when converting; bitmap subtitles (PGS/VobSub), attachments and complex ASS effects are not supported by this text subtitle renderer.

The loading overlay shows preparation progress and can be cancelled. Switching media or returning home cancels obsolete preparation. Stop during preparation cancels autoplay. Cache cleanup is available in General settings and preserves the active media. Older completed cache files are pruned to a 5 GiB budget excluding the current file, which may exceed this budget. Conversion requires free disk space.

The conversion helper has no network protocols. Its input demuxers are allowlisted; remote URLs, HLS/concat playlists and device inputs are not part of this local-file feature. This is not DRM support or a guarantee for damaged media.

## Verification

`Tests/run-formats.sh` generates small synthetic SDR video/audio fixtures with development FFmpeg, then runs the **bundled** helpers and validates decoding, unchanged source bytes, cache reuse, multiple audio tracks, text subtitle extraction, cancellation and playlist rejection. `Tests/run.sh` verifies playback and settings regressions.

| Container and codecs | Native decoding on test Mac | Compatibility path |
|---|---|---|
| MP4, H.264 + AAC | Yes | Direct |
| MKV, H.264 + AAC | No | Remux |
| AVI, MPEG-4 + MP3 | No | Remux or conversion |
| WebM, VP9 + Opus | No | Remux or conversion |
| WMV, WMV2 + WMA2 | No | Conversion |
| FLV, FLV1 + MP3 | No | Conversion |
| TS, H.264 + AC-3 | Yes | Direct |
| MKV, H.264 + DTS | No | Audio conversion |
| MP4, HEVC + AAC | Yes | Direct |

These fixtures exercise specific combinations, not every codec variant, resolution, HDR profile or damaged file. Native support can differ between macOS releases and hardware.
