import AVFoundation
import Foundation

@main
struct FormatCompatibilityRegression {
    @MainActor static func main() async throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let tools = URL(fileURLWithPath: CommandLine.arguments[2])
        let cache = folder.appendingPathComponent("cache")
        let engine = FormatCompatibility(toolsDirectory: tools, cacheDirectory: cache)
        let names = ["h264-aac.mp4", "h264-aac.mkv", "mpeg4-mp3.avi", "vp9-opus.webm", "wmv-wma.wmv", "flv-mp3.flv", "h264-ac3.ts", "h264-dts.mkv", "hevc-aac.mp4"]
        for name in names {
            let original = folder.appendingPathComponent(name)
            let bytes = try Data(contentsOf: original)
            let native = FormatCompatibility.canDecode(original)
            let converted = try await engine.prepare(original, status: { _ in })
            precondition(FormatCompatibility.canDecode(converted))
            let unchanged = try Data(contentsOf: original)
            precondition(unchanged == bytes)
            let duration = AVURLAsset(url: converted).duration.seconds
            precondition(duration > 1.5 && duration < 3.5)
            if name == "h264-aac.mkv" {
                precondition(AVURLAsset(url: converted).tracks(withMediaType: .audio).count == 2)
                let captions = engine.subtitleFiles(for: converted)
                precondition(captions.count == 1)
                let text = try String(contentsOf: captions[0], encoding: .utf8)
                precondition(text.contains("Test subtitle"))
            }
            let reused = try await engine.prepare(original, status: { _ in })
            precondition(reused == converted)
            print("PASS \(name): native=\(native), compatible=true, source unchanged, cache reused")
        }
        let malicious = folder.appendingPathComponent("network.m3u8")
        try "#EXTM3U\n#EXTINF:2,\nhttps://example.invalid/video.ts\n#EXT-X-ENDLIST\n".write(to: malicious, atomically: true, encoding: .utf8)
        do {
            _ = try await engine.prepare(malicious, status: { _ in })
            preconditionFailure("Playlist should be rejected")
        } catch { print("PASS: network playlist rejected") }
        let other = FormatCompatibility(toolsDirectory: tools, cacheDirectory: folder.appendingPathComponent("cancel-cache"))
        do {
            _ = try await other.prepare(folder.appendingPathComponent("vp9-opus.webm"), status: { _ in other.cancel() })
            preconditionFailure("Cancelled job returned media")
        } catch is CancellationError { print("PASS: cancellation prevents conversion and cache publication") }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: other.cacheDirectory.path)) ?? []
        precondition(files.isEmpty)
        let suite = "FormatRegression-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = PlayerViewModel(defaults: defaults, compatibility: engine)
        let original = folder.appendingPathComponent("h264-aac.mkv")
        vm.openFile(url: original)
        for _ in 0..<200 {
            if !vm.isLoading { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        precondition(vm.isPlaying && vm.currentVideoURL == original && vm.playbackMediaURL != original)
        precondition(vm.audioTracks.count == 2 && !vm.subtitleCues.isEmpty)
        vm.seek(to: 1)
        for _ in 0..<100 {
            if !vm.isScrubbing { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        precondition(abs(vm.currentTime - 1) < 0.2)
        vm.openFile(url: folder.appendingPathComponent("vp9-opus.webm"))
        vm.returnToHome()
        try await Task.sleep(nanoseconds: 300_000_000)
        precondition(vm.currentVideoURL == nil && vm.player == nil && !vm.isLoading)
        print("PASS: player integration preserves original identity, audio/subtitles, seeks and cancels obsolete open")
        print("All format compatibility checks passed")
    }
}
