import AppKit
import AVKit
import QuartzCore

@main struct NativePlaybackSoak {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let suite = "MocpotNativeSoak-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = PlayerViewModel(defaults: defaults)
        let original = AVURLAsset(url: url)
        // Reproduce the previous unconditionally composed single-audio path.
        let baseline = AVMutableComposition()
        for source in original.tracks {
            let track = baseline.addMutableTrack(withMediaType: source.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid)!
            try track.insertTimeRange(source.timeRange, of: source, at: source.timeRange.start)
            track.preferredTransform = source.preferredTransform
        }
        let direct = try vm.makePlaybackItem(url: url)
        precondition(direct.asset is AVURLAsset && direct.videoComposition == nil)
        vm.audioDelay = 0.3
        let delayed = try vm.makePlaybackItem(url: url)
        precondition(delayed.asset is AVComposition)
        vm.audioDelay = 0
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 960, height: 540), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = AVPlayerView(frame: window.contentView!.bounds)
        view.controlsStyle = .none
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        defer { view.player = nil; window.close() }
        for (name, item) in [("previous-composition", AVPlayerItem(asset: baseline)), ("native-file", direct)] {
            let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
            item.add(output)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            view.player = player
            player.play()
            let deadline = Date().addingTimeInterval(10)
            while player.currentTime().seconds < 1 {
                precondition(Date() < deadline, "Playback did not start")
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            let start = CACurrentMediaTime()
            var frames = 0, waiting = 0, maximumGap = 0.0, previousFrame = start
            let measurementSeconds = name == "native-file" ? 30.0 : 6.0
            while CACurrentMediaTime() - start < measurementSeconds {
                let now = CACurrentMediaTime()
                let time = output.itemTime(forHostTime: now)
                if output.hasNewPixelBuffer(forItemTime: time), output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) != nil {
                    frames += 1
                    maximumGap = max(maximumGap, now - previousFrame)
                    previousFrame = now
                }
                if player.timeControlStatus == .waitingToPlayAtSpecifiedRate { waiting += 1 }
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            print("\(name): decoded frames=\(frames), max output gap=\(String(format: "%.3f", maximumGap))s, waiting samples=\(waiting)")
            precondition(Double(frames) > measurementSeconds * 40 && player.currentTime().seconds > measurementSeconds)
            player.pause()
            view.player = nil
        }
        vm.currentVideoURL = url
        vm.loadEmbeddedSubtitles(url: url)
        try await Task.sleep(nanoseconds: 500_000_000)
        precondition(vm.subtitleStatus == "未发现内嵌文本字幕")
        print("PASS: single-audio file path, delayed-audio fallback and native subtitle preflight")
    }
}
