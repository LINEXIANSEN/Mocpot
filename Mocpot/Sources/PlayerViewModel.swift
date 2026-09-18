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
    @Published var volume: Double = 1.0 { didSet { player?.volume = Float(volume) } }
    @Published var isMuted = false { didSet { player?.isMuted = isMuted } }
    @Published var playbackSpeed: PlaybackSpeed = .normal {
        didSet { if isPlaying { player?.rate = playbackSpeed.value } }
    }
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
    @Published var isLoading = false
    @Published var playbackError: String?
    private var itemObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var lastPositionSave = Date.distantPast
    private var seekGeneration = 0
    private var wantsPlayback = false


    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        defaults.register(defaults: [
            "resumePlayback": true, "autoPlayNext": true,
            "rememberLastPosition": true, "showSubtitleBackground": true
        ])
        loadRecentFiles()
        loadSettings()
    }

    deinit {
        removeTimeObserver()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
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
        guard validateLocalMediaURL(url) else {
            playbackError = "只能打开本地视频文件。"
            return
        }
        persistCurrentPosition()
        player?.pause()
        removeTimeObserver()
        itemObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        seekGeneration += 1
        isScrubbing = false
        currentTime = 0
        duration = 0
        clearABLoop()
        videoMetadata = VideoMetadata()
        playbackError = nil
        isLoading = true
        isPlaying = false
        wantsPlayback = true

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.allowsExternalPlayback = true
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.volume = Float(volume)
        newPlayer.isMuted = isMuted
        player = newPlayer
        currentVideoURL = url
        currentPlaylistIndex = playlist.firstIndex(of: url) ?? -1
        videoTitle = url.deletingPathExtension().lastPathComponent
        loadMetadata(url: url)
        saveRecentFile(url: url)
        detectVideoType(url: url)
        loadSubtitlesForVideo(url: url)
        setupTimeObserver()
        lastPositionSave = Date()

        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, self.player?.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    guard self.isLoading else { return }
                    self.isLoading = false
                    self.updateVideoInfo()
                    if self.resumePlayback && self.wantsPlayback { self.restorePlaybackPosition(url: url) }
                    if self.wantsPlayback {
                        self.player?.rate = self.playbackSpeed.value
                        self.isPlaying = true
                    }
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    self.wantsPlayback = false
                    self.playbackError = item.error?.localizedDescription ?? "无法播放此文件，请检查文件或编码格式。"
                default: break
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self, self.player?.currentItem === item else { return }
            if self.isLooping {
                self.seek(to: 0)
                self.player?.rate = self.playbackSpeed.value
            } else if self.autoPlayNext && (self.shufflePlayback || self.currentPlaylistIndex + 1 < self.playlist.count) {
                self.nextTrack()
            } else {
                self.isPlaying = false
                self.wantsPlayback = false
                self.persistCurrentPosition()
            }
        }
    }

    private func validateLocalMediaURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        return values?.isDirectory == false && values?.isRegularFile == true
    }

    func loadMetadata(url: URL) {
        let resourceValues = try? url.resourceValues(forKeys: [
            .fileSizeKey, .creationDateKey
        ])
        videoMetadata.fileSize = Int64(resourceValues?.fileSize ?? 0)
        videoMetadata.creationDate = resourceValues?.creationDate
    }

    func detectVideoType(url: URL) {
        let tokens = Set(url.deletingPathExtension().lastPathComponent.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted))
        vrMode = tokens.contains("360") || tokens.contains("vr") ? .mono : .none
        threeDMode = .none
        if vrMode == .none {
            if tokens.contains("sbs") { threeDMode = .sideBySide }
            if tokens.contains("ou") || tokens.contains("tb") { threeDMode = .overUnder }
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
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        guard let observedPlayer = player else { return }
        timeObserverToken = observedPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self, weak observedPlayer] time in
            guard let self, self.player === observedPlayer, time.seconds.isFinite else { return }

            if !self.isScrubbing {
                self.currentTime = time.seconds
            }

            if !self.isScrubbing, self.isABLooping, let a = self.loopPointA, let b = self.loopPointB {
                if time.seconds >= b {
                    self.seek(to: a)
                }
            }

            if !self.isScrubbing, Date().timeIntervalSince(self.lastPositionSave) >= 5 {
                self.persistCurrentPosition()
                self.lastPositionSave = Date()
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
        let seconds = currentItem.duration.seconds
        duration = seconds.isFinite && seconds > 0 ? seconds : 0
        videoMetadata.duration = duration
        let size = currentItem.presentationSize
        videoMetadata.width = Int(size.width)
        videoMetadata.height = Int(size.height)
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player = player else { return }
        if isLoading { wantsPlayback.toggle(); return }
        guard playbackError == nil, player.currentItem?.status == .readyToPlay else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            wantsPlayback = false
            persistCurrentPosition()
        } else {
            if duration > 0 && currentTime >= duration - 0.1 { seek(to: 0) }
            player.rate = playbackSpeed.value
            isPlaying = true
            wantsPlayback = true
        }
    }

    func stopPlayback() {
        persistCurrentPosition()
        wantsPlayback = false
        player?.pause()
        isPlaying = false
        seek(to: 0)
        clearABLoop()
    }

    func returnToHome() {
        persistCurrentPosition()
        wantsPlayback = false
        player?.pause()
        removeTimeObserver()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        itemObservation = nil
        player = nil
        currentVideoURL = nil
        isPlaying = false
        isLoading = false
        playbackError = nil
        currentTime = 0
        duration = 0
        clearABLoop()
        vrMode = .none
        threeDMode = .none
    }

    func seek(to time: Double) {
        guard time.isFinite, duration > 0, let player else {
            isScrubbing = false
            return
        }
        let target = max(0, min(time, duration))
        seekGeneration += 1
        let generation = seekGeneration
        isScrubbing = true
        scrubTarget = target
        currentTime = target
        player.currentItem?.cancelPendingSeeks()
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] _ in
            DispatchQueue.main.async {
                guard let self, self.player === player, self.seekGeneration == generation else { return }
                self.isScrubbing = false
            }
        }
    }

    func beginScrubbing() {
        scrubTarget = currentTime
        isScrubbing = true
    }

    func persistCurrentPosition() {
        guard rememberLastPosition, let url = currentVideoURL,
              currentTime.isFinite, duration > 0 else { return }
        savePlaybackPosition(url: url, position: currentTime)
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
        guard player != nil, let url = currentVideoURL else { return }

        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true

        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, cgImage, _, _, error in
            guard let cgImage = cgImage, error == nil else { return }

            let baseName = url.deletingPathExtension().lastPathComponent
                .components(separatedBy: CharacterSet(charactersIn: "/:\\0")).joined()
            let filename = "\(baseName)_\(Int(self?.currentTime ?? 0))s_\(UUID().uuidString.prefix(8)).png"
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
        currentPlaylistIndex = currentVideoURL.flatMap { playlist.firstIndex(of: $0) } ?? -1
    }

    func clearPlaylist() {
        playlist.removeAll()
        currentPlaylistIndex = -1
    }

    func shufflePlaylist() {
        playlist.shuffle()
        currentPlaylistIndex = currentVideoURL.flatMap { playlist.firstIndex(of: $0) } ?? -1
    }

    func movePlaylistItem(from source: IndexSet, to destination: Int) {
        playlist.move(fromOffsets: source, toOffset: destination)
        currentPlaylistIndex = currentVideoURL.flatMap { playlist.firstIndex(of: $0) } ?? -1
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
    
    func setupPiP() {
        guard let player = player else { return }
        pipController.setup(with: player)
    }
    
    func togglePiP() {
        pipController.togglePiP()
    }
    
    func startPiP() {
        pipController.startPiP()
    }
    
    func stopPiP() {
        pipController.stopPiP()
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
        guard url.isFileURL else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "ts", "mts", "m2ts", "3gp", "ogv"]

        guard let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey]) else { return }

        var videoFiles = items.filter {
            guard videoExtensions.contains($0.pathExtension.lowercased()) else { return false }
            return validateLocalMediaURL($0)
        }

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
            videoFiles.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
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
        var positions = defaults.dictionary(forKey: "playbackPositions") as? [String: Double] ?? [:]
        positions[url.absoluteString] = position
        defaults.set(positions, forKey: "playbackPositions")
    }

    func restorePlaybackPosition(url: URL) {
        guard let positions = defaults.dictionary(forKey: "playbackPositions") as? [String: Double],
              let position = positions[url.absoluteString],
              position > 3 else { return }
        guard currentVideoURL == url, position < duration - 3 else { return }
        seek(to: position)
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
        defaults.set(urls, forKey: "recentFiles")
    }

    func loadRecentFiles() {
        guard let urls = defaults.stringArray(forKey: "recentFiles") else { return }
        recentFiles = urls.compactMap { value in
            guard let url = URL(string: value), validateLocalMediaURL(url) else { return nil }
            return url
        }
    }

    func clearRecentFiles() {
        recentFiles.removeAll()
        saveRecentFiles()
    }

    // MARK: - Settings Persistence

    func saveSettings() {
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
        volume = defaults.object(forKey: "volume") as? Double ?? 1.0
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
