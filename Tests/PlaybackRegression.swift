import AVFoundation
import Foundation

@main
struct PlaybackRegression {
    @MainActor
    static func wait(_ description: String, timeout: Double = 8, until condition: () -> Bool) async throws {
        let end = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= end { throw NSError(domain: description, code: 1) }
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        print("PASS: \(description)")
    }

    @MainActor
    static func main() async throws {
        let suite = "MocpotRegression-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = PlayerViewModel(defaults: defaults)
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let first = folder.appendingPathComponent("sample.mp4")
        let second = folder.appendingPathComponent("sample-360.mp4")
        vm.saveRecentFile(url: first)
        precondition(vm.visibleRecentFiles == [first])
        vm.showRecentFiles = false
        precondition(vm.visibleRecentFiles.isEmpty && vm.recentFiles == [first])
        let reloaded = PlayerViewModel(defaults: defaults)
        precondition(!reloaded.showRecentFiles && reloaded.visibleRecentFiles.isEmpty)
        vm.showRecentFiles = true
        precondition(vm.visibleRecentFiles == [first])
        vm.showWelcomeScreen = false
        vm.openRecentOnLaunch = true
        vm.autoScanSiblings = true
        let launched = PlayerViewModel(defaults: defaults)
        precondition(!launched.showWelcomeScreen && launched.openRecentOnLaunch && launched.autoScanSiblings)
        launched.applyLaunchBehavior()
        try await wait("startup opens recent video and scans siblings") { launched.isPlaying && launched.playlist.count == 2 }
        launched.returnToHome()
        launched.applyLaunchBehavior()
        precondition(launched.currentVideoURL == nil)
        vm.autoScanSiblings = false
        vm.openRecentOnLaunch = false
        print("PASS: recent visibility, history preservation, persisted preferences and one-time startup")
        precondition(vm.resumePlayback && vm.autoPlayNext && vm.rememberLastPosition)
        vm.playbackSpeed = .oneAndHalf
        vm.openFile(url: first)
        try await wait("ready state and finite duration") { !vm.isLoading && vm.duration > 5 && vm.isPlaying }
        precondition(vm.player?.rate == 1.5)
        vm.volume = 0.25
        vm.isMuted = true
        precondition(vm.player?.volume == 0.25 && vm.player?.isMuted == true)
        vm.playbackSpeed = .double
        precondition(vm.player?.rate == 2)
        vm.singleClickAction = "无操作"
        vm.performClickAction()
        precondition(vm.isPlaying)
        vm.singleClickAction = "播放/暂停"
        vm.performClickAction()
        precondition(vm.player?.rate == 0 && !vm.isPlaying)
        vm.seek(to: 2)
        vm.seek(to: 5)
        vm.seek(to: 3)
        try await wait("latest seek wins") { !vm.isScrubbing && abs((vm.player?.currentTime().seconds ?? 0) - 3) < 0.1 }
        vm.stopPlayback()
        try await wait("stop rewinds actual player") { !vm.isScrubbing && abs(vm.player?.currentTime().seconds ?? 99) < 0.1 }
        vm.togglePlayPause()
        try await wait("progress observer survives stop and resume") { vm.currentTime > 0.5 }
        vm.togglePlayPause()
        vm.seek(to: 4)
        try await wait("pause seek completes") { !vm.isScrubbing }
        vm.persistCurrentPosition()
        let saved = defaults.dictionary(forKey: "playbackPositions") as? [String: Double]
        precondition(abs((saved?[first.absoluteString] ?? 0) - 4) < 0.1)
        vm.openFile(url: second)
        vm.openFile(url: first)
        vm.openFile(url: second)
        try await wait("rapid file switching ignores obsolete readiness callbacks") { !vm.isLoading && vm.currentVideoURL == second && vm.isPlaying }
        precondition(vm.vrMode == .mono)
        vm.detectVideoType(url: folder.appendingPathComponent("our-holiday.mp4"))
        precondition(vm.vrMode == .none && vm.threeDMode == .none)
        vm.playlist = [first, second]
        vm.currentPlaylistIndex = 1
        vm.shufflePlaylist()
        precondition(vm.playlist[vm.currentPlaylistIndex] == second)
        vm.autoPlayNext = false
        vm.isLooping = true
        vm.seek(to: vm.duration - 0.2)
        try await wait("single item loops after end") { !vm.isScrubbing && vm.currentTime < 2 && vm.isPlaying }
        vm.isLooping = false
        vm.seek(to: vm.duration - 0.2)
        try await wait("end updates playing state") { !vm.isPlaying }
        vm.playlist = [first, second]
        vm.autoPlayNext = true
        vm.resumePlayback = false
        vm.openFile(url: first)
        try await wait("ordinary video resets projection mode") { !vm.isLoading && vm.vrMode == .none }
        vm.seek(to: 2)
        try await wait("A-B setup seek") { !vm.isScrubbing }
        vm.setLoopPointA()
        vm.seek(to: 3)
        try await wait("B point setup seek") { !vm.isScrubbing }
        vm.setLoopPointB()
        try await wait("A-B loop returns to A") { vm.isABLooping && vm.currentTime < 2.6 }
        vm.clearABLoop()
        vm.seek(to: vm.duration - 0.2)
        try await wait("auto next opens following playlist item") { vm.currentVideoURL == second && !vm.isLoading }
        vm.openFile(url: folder.appendingPathComponent("missing.mp4"))
        try await wait("invalid media exits loading with error") { !vm.isLoading && vm.playbackError != nil }
        vm.openFile(url: first)
        vm.stopPlayback()
        try await wait("stop during loading cancels autoplay") { !vm.isLoading }
        try await Task.sleep(nanoseconds: 300_000_000)
        precondition(!vm.isPlaying && (vm.player == nil || vm.player?.rate == 0))
        vm.togglePlayPause()
        try await wait("play restarts cancelled preparation") { !vm.isLoading && vm.isPlaying }
        vm.stopPlayback()
        try await wait("stop before media settings tests") { !vm.isScrubbing }
        let srt = "1\n00:00:01,000 --> 00:00:03,000\nHello 世界\n\n2\n00:00:02,000 --> 00:00:04,000\nSecond line\n"
        let sub = folder.appendingPathComponent("sample.srt")
        try srt.write(to: sub, atomically: true, encoding: .utf8)
        vm.loadSubtitlesForVideo(url: first)
        precondition(vm.subtitleTracks.count == 1 && vm.subtitleCues.count == 2)
        precondition(vm.subtitleText(at: 0.9).isEmpty)
        precondition(vm.subtitleText(at: 2.5) == "Hello 世界\nSecond line")
        vm.subtitleDelay = 1
        precondition(vm.subtitleText(at: 1.5).isEmpty && vm.subtitleText(at: 2.5) == "Hello 世界")
        vm.subtitleDelay = -1
        precondition(vm.subtitleText(at: 0.5) == "Hello 世界")
        vm.selectedSubtitleTrack = -1
        precondition(vm.subtitleText(at: 2).isEmpty)
        vm.autoLoadMatchingSubtitles = false
        precondition(vm.subtitleTracks.isEmpty)
        vm.autoLoadDirectorySubtitles = true
        precondition(vm.subtitleTracks.count == 1)
        let ass = "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Hello, world\\NSecond"
        precondition(SubtitleParser.parse(ass, extension: "ass").first?.text == "Hello, world\nSecond")
        precondition(SubtitleParser.parse("WEBVTT\n\n00:01.000 --> 00:02.000 align:start\n<b>Test</b>\n", extension: "vtt").first?.text == "Test")
        for encoding in [SubtitleEncoding.gbk, .big5, .shiftJIS, .eucKR, .isoLatin1, .utf8] {
            precondition(SubtitleParser.decode(Data("ASCII text".utf8), encoding: encoding) == "ASCII text")
        }
        print("PASS: subtitle parsing, loading switches, selection, overlap and positive/negative delay")
        vm.subtitleDelay = 0.7
        vm.subtitleFontSize = 34
        vm.showSubtitleBackground = false
        vm.subtitleEncoding = .utf8
        vm.subtitleColor = .yellow
        vm.scrollAction = "音量调节"
        vm.saveSettings()
        let restored = PlayerViewModel(defaults: defaults)
        precondition(restored.subtitleDelay == 0.7 && restored.subtitleFontSize == 34 && !restored.showSubtitleBackground && restored.subtitleEncoding == .utf8)
        precondition(restored.autoLoadDirectorySubtitles && !restored.autoLoadMatchingSubtitles)
        let originalVolume = vm.volume
        vm.handleScroll(-10)
        precondition(vm.volume < originalVolume)
        vm.seek(to: 3)
        try await wait("seek before audio adjustment") { !vm.isScrubbing }
        vm.audioDelay = 1
        try await Task.sleep(nanoseconds: 400_000_000)
        try await wait("audio rebuild preserves paused state and position") { !vm.isLoading && !vm.isScrubbing }
        precondition(!vm.isPlaying && abs(vm.currentTime - 3) < 0.1 && vm.audioTracks.count == 2)
        let delayed = vm.player!.currentItem!.asset.tracks(withMediaType: .audio)[0] as! AVCompositionTrack
        let segment = delayed.segments.first { !$0.isEmpty }!
        precondition(abs(segment.timeMapping.target.start.seconds - 1) < 0.01)
        vm.audioDelay = -1
        vm.selectedAudioTrack = 1
        try await Task.sleep(nanoseconds: 400_000_000)
        try await wait("negative audio delay and track selection applied") { !vm.isLoading && !vm.isScrubbing }
        let advanced = vm.player!.currentItem!.asset.tracks(withMediaType: .audio)[0] as! AVCompositionTrack
        let advancedSegment = advanced.segments.first { !$0.isEmpty }!
        precondition(abs(advancedSegment.timeMapping.source.start.seconds - 1) < 0.01)
        precondition(advancedSegment.sourceTrackID == AVURLAsset(url: first).tracks(withMediaType: .audio)[1].trackID)
        let generator = AVAssetImageGenerator(asset: vm.player!.currentItem!.asset)
        let before = try generator.copyCGImage(at: CMTime(seconds: 2, preferredTimescale: 600), actualTime: nil)
        vm.brightness = 0.5
        generator.videoComposition = vm.player!.currentItem!.videoComposition
        let after = try generator.copyCGImage(at: CMTime(seconds: 2, preferredTimescale: 600), actualTime: nil)
        precondition(before.dataProvider!.data! != after.dataProvider!.data!)
        vm.brightness = 0
        precondition(vm.player!.currentItem!.videoComposition == nil)
        print("PASS: audio timeline offsets, selected source track and rendered color adjustment")
        vm.returnToHome()
        print("All playback regression checks passed.")
    }
}
