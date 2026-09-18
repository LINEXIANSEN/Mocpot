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
        vm.togglePlayPause()
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
        precondition(!vm.isPlaying && vm.player?.rate == 0)
        print("All playback regression checks passed.")
    }
}
