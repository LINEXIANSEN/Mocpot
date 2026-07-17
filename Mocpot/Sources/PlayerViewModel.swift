import AVFoundation
import AVKit
import SwiftUI
import AppKit

enum PlaybackSpeed: String, CaseIterable, Identifiable {
    case quarter = "0.25"
    case half = "0.5"
    case threeQuarter = "0.75"
    case normal = "1.0"
    case oneAndQuarter = "1.25"
    case oneAndHalf = "1.5"
    case double = "2.0"
    case triple = "3.0"
    case quad = "4.0"

    var id: String { rawValue }
    var value: Float {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.5
        case .threeQuarter: return 0.75
        case .normal: return 1.0
        case .oneAndQuarter: return 1.25
        case .oneAndHalf: return 1.5
        case .double: return 2.0
        case .triple: return 3.0
        case .quad: return 4.0
        }
    }
}

enum VRMode: String, CaseIterable, Identifiable {
    case none = "关闭"
    case mono = "360° 全景"
    case stereo = "360° 立体"
    case dome = "180° 半球"

    var id: String { rawValue }
}

enum ThreeDMode: String, CaseIterable, Identifiable {
    case none = "关闭"
    case sideBySide = "左右格式"
    case overUnder = "上下格式"
    case anaglyphRedCyan = "红蓝3D"
    case anaglyphYellowBlue = "红黄3D"

    var id: String { rawValue }
}

enum VideoLayout: String, CaseIterable, Identifiable {
    case original = "原始"
    case fill = "填充"
    case fit = "适合"
    case stretch = "拉伸"
    case centerCrop = "居中裁剪"

    var id: String { rawValue }
}

enum SubtitleEncoding: String, CaseIterable, Identifiable {
    case utf8 = "UTF-8"
    case gbk = "GBK"
    case big5 = "Big5"
    case shiftJIS = "Shift JIS"
    case eucKR = "EUC-KR"
    case isoLatin1 = "ISO-8859-1"
    case auto = "自动检测"

    var id: String { rawValue }
}

struct SubtitleTrack: Identifiable {
    let id: Int
    let name: String
    let language: String
}

struct AudioTrack: Identifiable {
    let id: Int
    let name: String
    let language: String
    let channelCount: Int
}

struct VideoMetadata {
    var width: Int = 0
    var height: Int = 0
    var duration: Double = 0
    var bitrate: Int = 0
    var fps: Double = 0
    var codec: String = ""
    var audioCodec: String = ""
    var audioSampleRate: Int = 0
    var audioChannels: Int = 0
    var fileSize: Int64 = 0
    var creationDate: Date?
    var isHDR: Bool = false
}

class PlayerViewModel: NSObject, ObservableObject {
    @Published var player: AVPlayer?
    @Published var currentVideoURL: URL?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 1.0
    @Published var isMuted = false
    @Published var playbackSpeed: PlaybackSpeed = .normal
    @Published var vrMode: VRMode = .none
    @Published var threeDMode: ThreeDMode = .none
    @Published var videoLayout: VideoLayout = .original
    @Published var isLooping = false
    @Published var isFullscreen = false
    @Published var videoTitle: String = "Mocpot"
    @Published var videoMetadata: VideoMetadata = VideoMetadata()
    @Published var pendingURLs: [URL] = []
    @Published var playlist: [URL] = []
    @Published var currentPlaylistIndex: Int = -1
    @Published var subtitleTracks: [SubtitleTrack] = []
    @Published var audioTracks: [AudioTrack] = []
    @Published var selectedSubtitleTrack: Int = -1
    @Published var selectedAudioTrack: Int = 0
    @Published var audioDelay: Double = 0
    @Published var subtitleDelay: Double = 0
    @Published var brightness: Double = 0
    @Published var contrast: Double = 0
    @Published var saturation: Double = 0
    @Published var hue: Double = 0
    @Published var sharpness: Double = 0
    @Published var deinterlace: Bool = false
    @Published var autoFit: Bool = true
    @Published var recentFiles: [URL] = []
    @Published var aspectRatio: CGFloat = 16.0 / 9.0
    @Published var showInspector: Bool = false
    @Published var showPlaylist: Bool = false

    // Scrubbing state
    @Published var isScrubbing: Bool = false
    @Published var scrubTarget: Double = 0

    // A-B Loop
    @Published var loopPointA: Double?
    @Published var loopPointB: Double?
    @Published var isABLooping: Bool = false

    // Screenshot
    @Published var screenshotDirectory: URL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!

    // Subtitle
    @Published var subtitleEncoding: SubtitleEncoding = .auto
    @Published var subtitleFontSize: CGFloat = 24
    @Published var subtitleColor: Color = .white
    @Published var subtitleBackgroundColor: Color = .black
    @Published var showSubtitleBackground: Bool = true

    // Window
    @Published var windowFloat: Bool = false
    @Published var windowOpacity: Double = 1.0
    @Published var pauseWhenMinimized: Bool = false

    // PiP
    @Published var autoStartPiP: Bool = false

    // Playback
    @Published var resumePlayback: Bool = true
    @Published var autoPlayNext: Bool = true
    @Published var rememberLastPosition: Bool = true
    @Published var shufflePlayback: Bool = false

    // Hardware
    @Published var hardwareDecoding: Bool = true
    @Published var audioPassthrough: Bool = false

    // Picture-in-Picture
    @Published var isPiPActive = false
    @Published var pipController = PictureInPictureController()

    // Mouse
    @Published var singleClickAction: String = "播放/暂停"
    @Published var doubleClickAction: String = "全屏"
    @Published var rightClickAction: String = "显示菜单"
    @Published var scrollAction: String = "快进/快退"

    private var timeObserverToken: Any?
    private var playerItem: AVPlayerItem?

    override init() {
        super.init()
        loadRecentFiles()
        loadSettings()
    }

    deinit {
        removeTimeObserver()
    }

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "打开"
        panel.message = "选择要播放的视频文件"

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            if let first = urls.first {
                self?.playlist = urls
                self?.currentPlaylistIndex = 0
                self?.openFile(url: first)
            }
        }
    }

    func openFile(url: URL) {
        stopPlayback()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.allowsExternalPlayback = true
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        newPlayer.volume = Float(volume)
        newPlayer.isMuted = isMuted
        player = newPlayer

        currentVideoURL = url
        videoTitle = url.deletingPathExtension().lastPathComponent

        setupTimeObserver()
        loadMetadata(url: url)
        saveRecentFile(url: url)
        detectVideoType(url: url)
        loadSubtitlesForVideo(url: url)

        // Start playback immediately
        newPlayer.play()
        isPlaying = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateVideoInfo()
        }

        if resumePlayback {
            restorePlaybackPosition(url: url)
        }
    }

    func loadMetadata(url: URL) {
        let resourceValues = try? url.resourceValues(forKeys: [
            .fileSizeKey, .creationDateKey
        ])
        videoMetadata.fileSize = Int64(resourceValues?.fileSize ?? 0)
        videoMetadata.creationDate = resourceValues?.creationDate
    }

    func detectVideoType(url: URL) {
        let filename = url.lastPathComponent.lowercased()
        if filename.contains("360") || filename.contains("vr") {
            vrMode = .mono
        }
        if filename.contains("sbs") || filename.contains("side") {
            threeDMode = .sideBySide
        }
        if filename.contains("ou") || filename.contains("top") {
            threeDMode = .overUnder
        }
    }

    func loadSubtitlesForVideo(url: URL) {
        let dir = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let srtExtensions = ["srt", "ass", "ssa", "sub", "vtt"]

        subtitleTracks.removeAll()
        var trackId = 0

        for ext in srtExtensions {
            let subURL = dir.appendingPathComponent("\(baseName).\(ext)")
            if FileManager.default.fileExists(atPath: subURL.path) {
                subtitleTracks.append(SubtitleTrack(id: trackId, name: "\(baseName).\(ext)", language: "外挂字幕"))
                trackId += 1
            }
        }
    }

    func setupTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            if !self.isScrubbing {
                self.currentTime = time.seconds
            }

            if self.isABLooping, let a = self.loopPointA, let b = self.loopPointB {
                if time.seconds >= b {
                    self.player?.seek(to: CMTime(seconds: a, preferredTimescale: 600))
                }
            }

            if self.rememberLastPosition, let url = self.currentVideoURL {
                self.savePlaybackPosition(url: url, position: time.seconds)
            }
        }
    }

    func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    func updateVideoInfo() {
        guard let currentItem = player?.currentItem else { return }
        duration = currentItem.duration.seconds
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.rate = playbackSpeed.value
            isPlaying = true
        }
    }

    func stopPlayback() {
        player?.pause()
        isPlaying = false
        currentTime = 0
        removeTimeObserver()
        loopPointA = nil
        loopPointB = nil
        isABLooping = false
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func seekForward(seconds: Double = 10) {
        seek(to: min(currentTime + seconds, duration))
    }

    func seekBackward(seconds: Double = 10) {
        seek(to: max(currentTime - seconds, 0))
    }

    func seekPercentage(_ percentage: Double) {
        seek(to: duration * percentage / 100.0)
    }

    func nextTrack() {
        guard !playlist.isEmpty else { return }
        if shufflePlayback {
            currentPlaylistIndex = Int.random(in: 0..<playlist.count)
        } else {
            currentPlaylistIndex = min(currentPlaylistIndex + 1, playlist.count - 1)
        }
        openFile(url: playlist[currentPlaylistIndex])
    }

    func previousTrack() {
        guard !playlist.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
        } else {
            currentPlaylistIndex = max(currentPlaylistIndex - 1, 0)
            openFile(url: playlist[currentPlaylistIndex])
        }
    }

    // MARK: - A-B Loop

    func setLoopPointA() {
        loopPointA = currentTime
        if let b = loopPointB, currentTime >= b {
            loopPointB = nil
        }
    }

    func setLoopPointB() {
        guard let a = loopPointA, currentTime > a else { return }
        loopPointB = currentTime
        isABLooping = true
        player?.seek(to: CMTime(seconds: a, preferredTimescale: 600))
    }

    func clearABLoop() {
        loopPointA = nil
        loopPointB = nil
        isABLooping = false
    }

    // MARK: - Screenshot

    func takeScreenshot() {
        guard let player = player,
              let url = currentVideoURL else { return }

        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true

        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, cgImage, _, _, error in
            guard let cgImage = cgImage, error == nil else { return }

            let filename = "\(url.deletingPathExtension().lastPathComponent)_\(Int(self?.currentTime ?? 0))s.png"
            let saveURL = self?.screenshotDirectory.appendingPathComponent(filename) ?? FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            if let tiffData = nsImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: saveURL)
                DispatchQueue.main.async {
                    NSWorkspace.shared.activateFileViewerSelecting([saveURL])
                }
            }
        }
    }

    // MARK: - Volume

    func setVolume(_ vol: Double) {
        volume = max(0, min(1, vol))
        player?.volume = Float(volume)
        isMuted = volume == 0
    }

    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    // MARK: - Playlist

    func playURL(_ url: URL) {
        if let index = playlist.firstIndex(of: url) {
            currentPlaylistIndex = index
        }
        openFile(url: url)
    }

    func removeFromPlaylist(_ url: URL) {
        playlist.removeAll { $0 == url }
        if currentPlaylistIndex >= playlist.count {
            currentPlaylistIndex = max(0, playlist.count - 1)
        }
    }

    func clearPlaylist() {
        playlist.removeAll()
        currentPlaylistIndex = -1
    }

    func shufflePlaylist() {
        playlist.shuffle()
        currentPlaylistIndex = 0
    }

    func movePlaylistItem(from source: IndexSet, to destination: Int) {
        playlist.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Window

    func toggleLooping() {
        isLooping.toggle()
    }

    func toggleFullscreen() {
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.windows.first {
                window.toggleFullScreen(nil)
            }
        }
    }

    func toggleFloat() {
        windowFloat.toggle()
        let shouldFloat = windowFloat
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.windows.first {
                window.level = shouldFloat ? .floating : .normal
            }
        }
    }

    // MARK: - Picture-in-Picture
    
    func setupPiP(with playerView: AVPlayerView) {
        pipController.setup(with: playerView)
    }
    
    func togglePiP() {
        pipController.togglePiP()
        isPiPActive = pipController.isPiPActive
    }
    
    func startPiP() {
        pipController.startPiP()
        isPiPActive = true
    }
    
    func stopPiP() {
        pipController.stopPiP()
        isPiPActive = false
    }

    // MARK: - Folder Import

    enum FolderSortOrder: String, CaseIterable, Identifiable {
        case nameAsc = "名称 A→Z"
        case nameDesc = "名称 Z→A"
        case dateAsc = "时间 旧→新"
        case dateDesc = "时间 新→旧"
        case natural = "自然顺序"

        var id: String { rawValue }
    }

    @Published var folderSortOrder: FolderSortOrder = .natural

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "导入文件夹"

        panel.begin { [weak self] response in
            guard response == .OK, let folderURL = panel.url else { return }
            self?.importFolder(url: folderURL)
        }
    }

    func importFolder(url: URL) {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "ts", "mts", "m2ts", "3gp", "ogv"]

        guard let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey]) else { return }

        var videoFiles = items.filter { videoExtensions.contains($0.pathExtension.lowercased()) }

        switch folderSortOrder {
        case .nameAsc:
            videoFiles.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        case .nameDesc:
            videoFiles.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedDescending }
        case .dateAsc:
            videoFiles.sort { url1, url2 in
                let d1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 < d2
            }
        case .dateDesc:
            videoFiles.sort { url1, url2 in
                let d1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 > d2
            }
        case .natural:
            break
        }

        for video in videoFiles {
            if !playlist.contains(video) {
                playlist.append(video)
            }
        }

        if playlist.count > 0 && currentPlaylistIndex == -1 {
            currentPlaylistIndex = 0
            openFile(url: playlist[0])
        }
    }

    // MARK: - Playback Position

    func savePlaybackPosition(url: URL, position: Double) {
        var positions = UserDefaults.standard.dictionary(forKey: "playbackPositions") as? [String: Double] ?? [:]
        positions[url.absoluteString] = position
        UserDefaults.standard.set(positions, forKey: "playbackPositions")
    }

    func restorePlaybackPosition(url: URL) {
        guard let positions = UserDefaults.standard.dictionary(forKey: "playbackPositions") as? [String: Double],
              let position = positions[url.absoluteString],
              position > 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.seek(to: position)
        }
    }

    // MARK: - Recent Files

    func saveRecentFile(url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > 30 {
            recentFiles = Array(recentFiles.prefix(30))
        }
        saveRecentFiles()
    }

    func saveRecentFiles() {
        let urls = recentFiles.map { $0.absoluteString }
        UserDefaults.standard.set(urls, forKey: "recentFiles")
    }

    func loadRecentFiles() {
        guard let urls = UserDefaults.standard.stringArray(forKey: "recentFiles") else { return }
        recentFiles = urls.compactMap { URL(string: $0) }
    }

    func clearRecentFiles() {
        recentFiles.removeAll()
        saveRecentFiles()
    }

    // MARK: - Settings Persistence

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(volume, forKey: "volume")
        defaults.set(isMuted, forKey: "isMuted")
        defaults.set(playbackSpeed.rawValue, forKey: "playbackSpeed")
        defaults.set(isLooping, forKey: "isLooping")
        defaults.set(videoLayout.rawValue, forKey: "videoLayout")
        defaults.set(brightness, forKey: "brightness")
        defaults.set(contrast, forKey: "contrast")
        defaults.set(saturation, forKey: "saturation")
        defaults.set(hue, forKey: "hue")
        defaults.set(sharpness, forKey: "sharpness")
        defaults.set(deinterlace, forKey: "deinterlace")
        defaults.set(resumePlayback, forKey: "resumePlayback")
        defaults.set(autoPlayNext, forKey: "autoPlayNext")
        defaults.set(rememberLastPosition, forKey: "rememberLastPosition")
        defaults.set(subtitleFontSize, forKey: "subtitleFontSize")
        defaults.set(showSubtitleBackground, forKey: "showSubtitleBackground")
        defaults.set(hardwareDecoding, forKey: "hardwareDecoding")
        defaults.set(shufflePlayback, forKey: "shufflePlayback")
        defaults.set(autoStartPiP, forKey: "autoStartPiP")
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        volume = defaults.double(forKey: "volume") > 0 ? defaults.double(forKey: "volume") : 1.0
        isMuted = defaults.bool(forKey: "isMuted")
        if let speedStr = defaults.string(forKey: "playbackSpeed"),
           let speed = PlaybackSpeed(rawValue: speedStr) {
            playbackSpeed = speed
        }
        isLooping = defaults.bool(forKey: "isLooping")
        if let layoutStr = defaults.string(forKey: "videoLayout"),
           let layout = VideoLayout(rawValue: layoutStr) {
            videoLayout = layout
        }
        brightness = defaults.double(forKey: "brightness")
        contrast = defaults.double(forKey: "contrast")
        saturation = defaults.double(forKey: "saturation")
        hue = defaults.double(forKey: "hue")
        sharpness = defaults.double(forKey: "sharpness")
        deinterlace = defaults.bool(forKey: "deinterlace")
        resumePlayback = defaults.bool(forKey: "resumePlayback")
        autoPlayNext = defaults.bool(forKey: "autoPlayNext")
        rememberLastPosition = defaults.bool(forKey: "rememberLastPosition")
        subtitleFontSize = CGFloat(defaults.double(forKey: "subtitleFontSize") > 0 ? defaults.double(forKey: "subtitleFontSize") : 24)
        showSubtitleBackground = defaults.bool(forKey: "showSubtitleBackground")
        hardwareDecoding = defaults.object(forKey: "hardwareDecoding") as? Bool ?? true
        shufflePlayback = defaults.bool(forKey: "shufflePlayback")
        autoStartPiP = defaults.bool(forKey: "autoStartPiP")
    }

    // MARK: - Utilities

    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func selectSubtitle(index: Int) {
        selectedSubtitleTrack = index
    }

    func selectAudio(index: Int) {
        selectedAudioTrack = index
    }
}
