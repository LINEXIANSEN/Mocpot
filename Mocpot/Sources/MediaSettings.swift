import Combine
import AVFoundation
import AVKit
import AppKit
import CoreAudio
import CoreImage
import SwiftUI

struct SubtitleCue: Equatable {
    let start: Double
    let end: Double
    let text: String
}

struct AudioOutputDevice: Identifiable {
    let id: String
    let name: String
}

enum SubtitleParser {
    static func timestamp(_ text: String) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard (2...3).contains(parts.count), let seconds = Double(parts.last!),
              let minutes = Double(parts[parts.count - 2]), seconds.isFinite else { return nil }
        let hours = parts.count == 3 ? Double(parts[0]) ?? 0 : 0
        let value = hours * 3600 + minutes * 60 + seconds
        return value.isFinite && value >= 0 ? value : nil
    }

    static func parse(_ input: String, extension ext: String) -> [SubtitleCue] {
        let lines = input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var cues: [SubtitleCue] = []
        if ["ass", "ssa"].contains(ext.lowercased()) {
            var fields = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]
            var inEvents = false
            for line in lines {
                if line.hasPrefix("[") { inEvents = line.lowercased() == "[events]" }
                guard inEvents else { continue }
                if line.lowercased().hasPrefix("format:") {
                    fields = line.dropFirst(7).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                }
                guard line.lowercased().hasPrefix("dialogue:"), let si = fields.firstIndex(of: "start"), let ei = fields.firstIndex(of: "end"), let ti = fields.firstIndex(of: "text") else { continue }
                let values = line.dropFirst(9).split(separator: ",", maxSplits: fields.count - 1, omittingEmptySubsequences: false).map(String.init)
                guard values.count == fields.count, let start = timestamp(values[si]), let end = timestamp(values[ei]), end > start else { continue }
                let text = values[ti].replacingOccurrences(of: #"\{[^}]*\}"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\N", with: "\n").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\h", with: " ")
                cues.append(SubtitleCue(start: start, end: end, text: text))
            }
        } else {
            for i in lines.indices where lines[i].contains("-->") {
                let timing = lines[i].components(separatedBy: "-->")
                guard timing.count == 2, let start = timestamp(timing[0]),
                      let endToken = timing[1].split(whereSeparator: { $0.isWhitespace }).first,
                      let end = timestamp(String(endToken)), end > start else { continue }
                var text: [String] = []
                var j = i + 1
                while j < lines.count && !lines[j].trimmingCharacters(in: .whitespaces).isEmpty {
                    text.append(lines[j]); j += 1
                }
                let cleaned = text.joined(separator: "\n").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&amp;", with: "&")
                if !cleaned.isEmpty { cues.append(SubtitleCue(start: start, end: end, text: cleaned)) }
            }
        }
        return cues.sorted { $0.start < $1.start }
    }

    static func decode(_ data: Data, encoding: SubtitleEncoding) -> String? {
        let legacy: [SubtitleEncoding: CFStringEncodings] = [.gbk: .GB_18030_2000, .big5: .big5, .shiftJIS: .shiftJIS, .eucKR: .EUC_KR]
        func decodeAs(_ encoding: SubtitleEncoding) -> String? {
            if let cf = legacy[encoding] {
                return String(data: data, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cf.rawValue))))
            }
            return String(data: data, encoding: encoding == .isoLatin1 ? .isoLatin1 : .utf8)
        }
        if encoding != .auto { return decodeAs(encoding) }
        if data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]) { return String(data: data, encoding: .utf16) }
        return decodeAs(.utf8) ?? decodeAs(.gbk) ?? decodeAs(.big5) ?? decodeAs(.shiftJIS) ?? decodeAs(.eucKR)
    }
}

extension PlayerViewModel {
    var activeSubtitleText: String { subtitleText(at: currentTime) }
    func subtitleText(at time: Double) -> String {
        let adjusted = time - subtitleDelay
        return subtitleCues.filter { $0.start <= adjusted && adjusted < $0.end }.map(\.text).joined(separator: "\n")
    }

    func reloadSubtitleDiscovery() {
        guard let url = currentVideoURL else { return }
        discoverSubtitles(for: url)
    }

    func discoverSubtitles(for video: URL) {
        let previous = subtitleURLs.indices.contains(selectedSubtitleTrack) ? subtitleURLs[selectedSubtitleTrack] : nil
        let supported = Set(["srt", "vtt", "ass", "ssa"])
        let stem = video.deletingPathExtension().lastPathComponent
        let files = (try? FileManager.default.contentsOfDirectory(at: video.deletingLastPathComponent(), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        func matches(_ url: URL) -> Bool {
            let name = url.deletingPathExtension().lastPathComponent
            return name == stem || name.hasPrefix(stem + ".")
        }
        subtitleURLs = files.filter {
            supported.contains($0.pathExtension.lowercased()) &&
            ((autoLoadMatchingSubtitles && matches($0)) || autoLoadDirectorySubtitles) &&
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted {
            if matches($0) != matches($1) { return matches($0) }
            return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        for url in manualSubtitleURLs + embeddedSubtitleFiles.map(\.url) where !subtitleURLs.contains(url) { subtitleURLs.append(url) }
        subtitleTracks = subtitleURLs.enumerated().map { entry in
            let embedded = embeddedSubtitleFiles.first { $0.url == entry.element }
            return SubtitleTrack(id: entry.offset, name: embedded?.title ?? entry.element.lastPathComponent, language: embedded == nil ? "外挂字幕" : "内嵌字幕")
        }
        selectedSubtitleTrack = previous.flatMap { subtitleURLs.firstIndex(of: $0) } ?? (subtitleURLs.isEmpty ? -1 : 0)
    }

    func openSubtitlePanel() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["srt", "vtt", "ass", "ssa"]
        panel.canChooseDirectories = false
        guard currentVideoURL != nil, panel.runModal() == .OK, let url = panel.url else { return }
        importSubtitle(url)
    }

    func handleDroppedFiles(_ urls: [URL]) {
        let subs = urls.filter { ["srt", "vtt", "ass", "ssa"].contains($0.pathExtension.lowercased()) }
        if let video = urls.first(where: { !subs.contains($0) }) { openFile(url: video) }
        for subtitle in subs { importSubtitle(subtitle) }
    }

    func importSubtitle(_ url: URL) {
        guard currentVideoURL != nil else { subtitleError = "请先打开视频，再拖入字幕。"; return }
        guard url.isFileURL, ["srt", "vtt", "ass", "ssa"].contains(url.pathExtension.lowercased()),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            subtitleError = "请选择 SRT、WebVTT、ASS 或 SSA 字幕文件。"; return
        }
        if !manualSubtitleURLs.contains(url) { manualSubtitleURLs.append(url) }
        if !subtitleURLs.contains(url) {
            subtitleURLs.append(url)
            subtitleTracks.append(SubtitleTrack(id: subtitleURLs.count - 1, name: url.lastPathComponent, language: "外挂字幕"))
        }
        selectedSubtitleTrack = subtitleURLs.firstIndex(of: url) ?? -1
    }

    func loadEmbeddedSubtitles(url: URL) {
        subtitleExtractionTask?.cancel()
        subtitleExtractor?.cancel()
        let id = UUID()
        subtitleRequestID = id
        let extractor = FormatCompatibility(toolsDirectory: compatibility.toolsDirectory,
            cacheDirectory: compatibility.cacheDirectory.appendingPathComponent("Subtitles"))
        subtitleExtractor = extractor
        subtitleStatus = "正在读取内嵌字幕…"
        subtitleExtractionTask = Task { @MainActor [weak self] in
            do {
                let files = try await extractor.extractSubtitles(url)
                guard let self, !Task.isCancelled, self.subtitleRequestID == id, self.currentVideoURL == url else { return }
                let previous = self.subtitleURLs.indices.contains(self.selectedSubtitleTrack) ? self.subtitleURLs[self.selectedSubtitleTrack] : nil
                let wasOff = self.selectedSubtitleTrack == -1 && !self.subtitleTracks.isEmpty
                self.embeddedSubtitleFiles = files
                self.discoverSubtitles(for: url)
                if wasOff { self.selectedSubtitleTrack = -1 }
                else if let previous, let index = self.subtitleURLs.firstIndex(of: previous) { self.selectedSubtitleTrack = index }
                self.subtitleStatus = files.isEmpty ? "未发现可用的内嵌文本字幕" : "已读取 \(files.count) 条内嵌文本字幕"
            } catch {
                guard let self, !Task.isCancelled, self.subtitleRequestID == id else { return }
                self.subtitleStatus = "内嵌字幕读取失败，仍可加载外挂字幕。"
            }
        }
    }

    func adjustSubtitleSync(_ amount: Double) {
        subtitleDelay = max(-60, min(60, ((subtitleDelay + amount) * 10).rounded() / 10))
        subtitleStatus = String(format: "字幕同步：%+.1f 秒", subtitleDelay)
        subtitleFeedback = subtitleStatus
        subtitleFeedbackTask?.cancel()
        subtitleFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.subtitleFeedback = nil
        }
    }

    func loadSelectedSubtitle() {
        subtitleCues = []; subtitleError = nil
        guard subtitleURLs.indices.contains(selectedSubtitleTrack) else { return }
        let url = subtitleURLs[selectedSubtitleTrack]
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 8 * 1024 * 1024 else { throw NSError(domain: "字幕文件超过 8 MB", code: 1) }
            let data = try Data(contentsOf: url)
            guard let text = SubtitleParser.decode(data, encoding: subtitleEncoding) else {
                subtitleError = "无法解码字幕，请更换字幕编码。"; return
            }
            subtitleCues = SubtitleParser.parse(text, extension: url.pathExtension)
            if subtitleCues.isEmpty { subtitleError = "没有读到有效的字幕时间轴。支持 SRT、WebVTT 和 ASS/SSA 文本字幕。" }
        } catch { subtitleError = "无法读取字幕：\(error.localizedDescription)" }
    }

    func makePlaybackItem(url: URL) throws -> AVPlayerItem {
        audioProcessingError = nil
        let asset = AVURLAsset(url: url)
        let tracks = asset.tracks(withMediaType: .audio)
        audioTracks = tracks.enumerated().map { AudioTrack(id: $0.offset, name: "音轨 \($0.offset + 1)", language: $0.element.languageCode ?? "未标记", channelCount: 0) }
        guard !tracks.isEmpty else { return AVPlayerItem(asset: asset) }
        let composition = AVMutableComposition()
        let total = asset.duration
        guard total.isNumeric, total.seconds > 0 else { return AVPlayerItem(asset: asset) }
        for source in asset.tracks where source.mediaType != .audio {
            guard let target = composition.addMutableTrack(withMediaType: source.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
            try target.insertTimeRange(source.timeRange, of: source, at: source.timeRange.start)
            target.preferredTransform = source.preferredTransform
        }
        let source = tracks[min(max(selectedAudioTrack, 0), tracks.count - 1)]
        if let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let offset = CMTime(seconds: max(-5, min(5, audioDelay)), preferredTimescale: 60000)
            let start = CMTimeMaximum(source.timeRange.start, CMTimeSubtract(.zero, offset))
            let end = CMTimeMinimum(CMTimeRangeGetEnd(source.timeRange), CMTimeSubtract(total, offset))
            if end > start {
                try target.insertTimeRange(CMTimeRange(start: start, end: end), of: source, at: CMTimeAdd(start, offset))
            }
        }
        return AVPlayerItem(asset: composition)
    }

    func applyVideoFilters() {
        guard let item = player?.currentItem else { return }
        let b = brightness, c = contrast, s = saturation, h = hue, sharp = sharpness
        guard [b, c, s, h, sharp].contains(where: { $0 != 0 }) else { item.videoComposition = nil; return }
        guard !item.asset.tracks(withMediaType: .video).isEmpty else { return }
        item.videoComposition = AVVideoComposition(asset: item.asset) { request in
            var image = request.sourceImage.clampedToExtent()
                .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: b, kCIInputContrastKey: 1 + c, kCIInputSaturationKey: 1 + s])
                .applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: h * .pi / 180])
            if sharp > 0 { image = image.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: sharp]) }
            if sharp < 0 { image = image.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: -sharp * 3]) }
            request.finish(with: image.cropped(to: request.sourceImage.extent), context: nil)
        }
    }

    func refreshAudioDevices() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return }
        func string(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            let value = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
            value.initialize(to: nil)
            defer { value.deinitialize(count: 1); value.deallocate() }
            var size = UInt32(MemoryLayout<CFString?>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, value) == noErr else { return nil }
            return value.pointee as String?
        }
        outputDevices = ids.compactMap { device in
            var output = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var bytes: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &output, 0, nil, &bytes) == noErr, bytes > 0,
                  let uid = string(device, kAudioDevicePropertyDeviceUID) else { return nil }
            return AudioOutputDevice(id: uid, name: string(device, kAudioObjectPropertyName) ?? uid)
        }
        applyAudioOutput()
    }

    func applyAudioOutput() {
        let available = outputDevices.contains { $0.id == audioOutputDeviceID }
        player?.audioOutputDeviceUniqueID = available ? audioOutputDeviceID : nil
    }

    func observeMediaSettings() {
        let changes: [AnyPublisher<Void, Never>] = [
            $audioDelay.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $subtitlePosition.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $subtitleOpacity.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $subtitleDelay.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $subtitleEncoding.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $subtitleFontSize.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $subtitleColor.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $subtitleBackgroundColor.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $showSubtitleBackground.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $autoLoadMatchingSubtitles.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $autoLoadDirectorySubtitles.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $audioOutputDeviceID.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $brightness.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $contrast.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $saturation.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $hue.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $sharpness.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $volume.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $isMuted.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $rightClickAction.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $scrollAction.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pinchToZoom.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $swipeToSeek.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $screenshotDirectory.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ]
        mediaSettingsSubscription = Publishers.MergeMany(changes)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] in self?.saveSettings() }
    }

    func saveMediaSettings() {
        defaults.set(subtitlePosition, forKey: "subtitlePosition")
        defaults.set(subtitleOpacity, forKey: "subtitleOpacity")
        defaults.set(screenshotDirectory.path, forKey: "screenshotDirectory")
        defaults.set(rightClickAction, forKey: "rightClickAction")
        defaults.set(scrollAction, forKey: "scrollAction")
        defaults.set(pinchToZoom, forKey: "pinchToZoom")
        defaults.set(swipeToSeek, forKey: "swipeToSeek")
        defaults.set(audioDelay, forKey: "audioDelay")
        defaults.set(subtitleDelay, forKey: "subtitleDelay")
        defaults.set(subtitleEncoding.rawValue, forKey: "subtitleEncoding")
        defaults.set(autoLoadMatchingSubtitles, forKey: "autoLoadMatchingSubtitles")
        defaults.set(autoLoadDirectorySubtitles, forKey: "autoLoadDirectorySubtitles")
        defaults.set(audioOutputDeviceID, forKey: "audioOutputDeviceID")
        for (key, color) in [("subtitleColor", subtitleColor), ("subtitleBackgroundColor", subtitleBackgroundColor)] {
            if let c = NSColor(color).usingColorSpace(.sRGB) { defaults.set([c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent], forKey: key) }
        }
    }

    func loadMediaSettings() {
        subtitlePosition = max(0, min(0.8, defaults.object(forKey: "subtitlePosition") as? Double ?? 0.05))
        subtitleOpacity = max(0, min(1, defaults.object(forKey: "subtitleOpacity") as? Double ?? 1))
        if let path = defaults.string(forKey: "screenshotDirectory") { screenshotDirectory = URL(fileURLWithPath: path, isDirectory: true) }
        rightClickAction = defaults.string(forKey: "rightClickAction") ?? "显示菜单"
        scrollAction = defaults.string(forKey: "scrollAction") ?? "快进/快退"
        pinchToZoom = defaults.object(forKey: "pinchToZoom") as? Bool ?? true
        swipeToSeek = defaults.object(forKey: "swipeToSeek") as? Bool ?? true
        audioDelay = defaults.double(forKey: "audioDelay")
        subtitleDelay = defaults.double(forKey: "subtitleDelay")
        subtitleEncoding = SubtitleEncoding(rawValue: defaults.string(forKey: "subtitleEncoding") ?? "") ?? .auto
        autoLoadMatchingSubtitles = defaults.object(forKey: "autoLoadMatchingSubtitles") as? Bool ?? true
        autoLoadDirectorySubtitles = defaults.bool(forKey: "autoLoadDirectorySubtitles")
        audioOutputDeviceID = defaults.string(forKey: "audioOutputDeviceID") ?? ""
        func color(_ key: String, fallback: Color) -> Color {
            guard let v = defaults.array(forKey: key) as? [Double], v.count == 4 else { return fallback }
            return Color(.sRGB, red: v[0], green: v[1], blue: v[2], opacity: v[3])
        }
        subtitleColor = color("subtitleColor", fallback: .white)
        subtitleBackgroundColor = color("subtitleBackgroundColor", fallback: .black)
    }
}

final class InteractivePlayerView: AVPlayerView {
    weak var viewModel: PlayerViewModel?
    override func rightMouseDown(with event: NSEvent) { viewModel?.handleRightClick(event, in: self) }
    override func scrollWheel(with event: NSEvent) { viewModel?.handleScroll(event.scrollingDeltaY) }
    override func magnify(with event: NSEvent) {
        guard let vm = viewModel, vm.pinchToZoom else { return }
        vm.videoZoom = max(0.5, min(3, vm.videoZoom * (1 + event.magnification)))
    }
    override func swipe(with event: NSEvent) { viewModel?.handleSwipe(event.deltaX) }
}

extension PlayerViewModel {
    func handleScroll(_ delta: CGFloat) {
        switch scrollAction {
        case "音量调节": setVolume(volume + Double(delta) * 0.005)
        case "缩放": videoZoom = max(0.5, min(3, videoZoom - delta * 0.005))
        default: seek(to: currentTime - Double(delta) * 0.1)
        }
    }
    func handleSwipe(_ delta: CGFloat) {
        guard swipeToSeek, delta != 0 else { return }
        if delta > 0 { seekBackward() } else { seekForward() }
    }
    func handleRightClick(_ event: NSEvent, in view: NSView) {
        switch rightClickAction {
        case "全屏": toggleFullscreen()
        case "显示菜单":
            let menu = NSMenu()
            for (title, action) in [(isPlaying ? "暂停" : "播放", #selector(menuPlayback)),
                                    (isFullscreen ? "退出全屏" : "进入全屏", #selector(menuFullscreen)),
                                    ("播放列表", #selector(menuPlaylist)), ("加载字幕…", #selector(menuSubtitle))] {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self; menu.addItem(item)
            }
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        default: break
        }
    }
    @objc func menuPlayback() { togglePlayPause() }
    @objc func menuFullscreen() { toggleFullscreen() }
    @objc func menuPlaylist() { showPlaylist.toggle() }
    @objc func menuSubtitle() { openSubtitlePanel() }
}
