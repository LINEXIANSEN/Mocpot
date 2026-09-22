import AppKit
import AVFoundation

@main struct DirectPlaybackRegression {
    @MainActor static func wait(_ name: String, timeout: Double = 12, _ condition: () -> Bool) async throws {
        let end = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > end { throw FormatCompatibility.Failure(message: "Timed out: \(name)") }
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        print("PASS: \(name)")
    }
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1])
        let suite = "MocpotDirectTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = fixtures.appendingPathComponent("no-transcode-cache")
        let vm = PlayerViewModel(defaults: defaults, compatibility: FormatCompatibility(toolsDirectory: fixtures.appendingPathComponent("missing-helpers"), cacheDirectory: cache))
        vm.autoPlayNext = false
        vm.rememberLastPosition = false
        vm.volume = 0
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 640, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        defer { vm.returnToHome(); window.close() }
        var firstFrame: Data?
        for name in ["vp9-opus.webm", "h264-aac.mkv", "mpeg4-mp3.avi", "wmv-wma.wmv", "flv-mp3.flv", "h264-ac3.ts", "h264-dts.mkv", "orientation.mkv", "long.webm"] {
            let url = fixtures.appendingPathComponent(name)
            let bytes = try Data(contentsOf: url)
            let start = Date()
            vm.openFile(url: url)
            try await wait("\(name) uses direct engine") { vm.directPlayback != nil || vm.playbackError != nil }
            guard let direct = vm.directPlayback else { throw FormatCompatibility.Failure(message: vm.playbackError ?? "Missing direct player") }
            let view = DirectVideoView(playback: direct)
            view.viewModel = vm
            window.contentView = view
            view.frame = NSRect(x: 0, y: 0, width: 640, height: 360)
            try await wait("\(name) displays and advances") { !vm.isLoading && vm.currentTime > 0.2 && view.renderedFrames > 1 }
            print("FIRST FRAME \(name): \(Date().timeIntervalSince(start)) seconds")
            precondition(vm.player == nil && vm.playbackMediaURL == url && vm.playbackError == nil)
            precondition((try? Data(contentsOf: url)) == bytes)
            precondition(!FileManager.default.fileExists(atPath: cache.path))
            if name != "orientation.mkv" {
                let sampleRate = await direct.property("audio-params/samplerate")
                let output = await direct.property("current-ao")
                precondition((Double(sampleRate) ?? 0) > 0)
                precondition(output == "coreaudio")
                print("PASS: audio decoded at \(sampleRate) Hz through \(output)")
            }
            if name == "long.webm" { precondition(vm.duration > 100) }
            let png = view.screenshotPNG()!
            if name == "orientation.mkv" {
                let image = NSBitmapImageRep(data: png)!
                let topLeft = image.colorAt(x: image.pixelsWide / 4, y: image.pixelsHigh / 4)!.usingColorSpace(.deviceRGB)!
                let topRight = image.colorAt(x: image.pixelsWide * 3 / 4, y: image.pixelsHigh / 4)!.usingColorSpace(.deviceRGB)!
                let bottomLeft = image.colorAt(x: image.pixelsWide / 4, y: image.pixelsHigh * 3 / 4)!.usingColorSpace(.deviceRGB)!
                precondition(topLeft.redComponent > 0.7 && topLeft.blueComponent < 0.2)
                precondition(topRight.greenComponent > 0.7 && bottomLeft.blueComponent > 0.7)
                print("PASS: rendered video orientation and RGB quadrants")
            }
            if firstFrame == nil { firstFrame = png; try png.write(to: fixtures.appendingPathComponent("direct-frame.png")) }
            vm.togglePlayPause()
            try await Task.sleep(nanoseconds: 200_000_000)
            let paused = vm.currentTime
            try await Task.sleep(nanoseconds: 250_000_000)
            precondition(abs(vm.currentTime - paused) < 0.15 && !vm.isPlaying)
            vm.seek(to: 0.8)
            try await Task.sleep(nanoseconds: 250_000_000)
            try await wait("paused seek") { abs(vm.currentTime - 0.8) < 0.15 && !vm.isPlaying }
            if name == "h264-aac.mkv" {
                precondition(vm.audioTracks.count == 2 && vm.subtitleTracks.count >= 1)
                vm.selectedAudioTrack = 1
                vm.audioDelay = 0.2
                let audioID = await direct.property("aid")
                let audioDelay = await direct.property("audio-delay")
                precondition(Int(audioID) == vm.directAudioIDs[1] && abs((Double(audioDelay) ?? 0) - 0.2) < 0.01)
                vm.selectedSubtitleTrack = vm.directSubtitleIDs.keys.sorted().first!
                try await wait("embedded text decoded during playback") { !vm.activeSubtitleText.isEmpty }
                vm.selectedSubtitleTrack = -1
                precondition(vm.activeSubtitleText.isEmpty)
                vm.importSubtitle(fixtures.appendingPathComponent("subtitle.srt"))
                precondition(vm.activeSubtitleText.contains("Test subtitle"))
                precondition(Set(vm.subtitleTracks.map(\.id)).count == vm.subtitleTracks.count)
                vm.vrMode = .mono
                view.needsDisplay = true
                try await Task.sleep(nanoseconds: 150_000_000)
                let before = view.screenshotPNG()
                view.yaw = 0.8; view.needsDisplay = true
                try await Task.sleep(nanoseconds: 150_000_000)
                precondition(before != view.screenshotPNG())
                vm.vrMode = .none
            }
            if name == "long.webm" {
                vm.seek(to: 80)
                try await Task.sleep(nanoseconds: 300_000_000)
                try await wait("long WebM seeks directly to 80 seconds") { abs(vm.currentTime - 80) < 0.2 }
            }
            vm.returnToHome()
            precondition(vm.directPlayback == nil)
        }
        print("All direct playback regression checks passed; no ffmpeg helper or converted cache was used.")
    }
}
