import AVFoundation
import CryptoKit
import Foundation
import Darwin

/// Runs only local-file demuxers in a standalone helper. User media is never overwritten.
final class FormatCompatibility {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    private let lock = NSLock()
    private let worker = DispatchQueue(label: "com.mocpot.compatibility", qos: .userInitiated)
    private var process: Process?
    private var generation = UUID()
    let toolsDirectory: URL
    let cacheDirectory: URL

    init(toolsDirectory: URL? = nil, cacheDirectory: URL? = nil) {
        self.toolsDirectory = toolsDirectory ?? (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Helpers")
        self.cacheDirectory = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("com.mocpot.mac/CompatibleMedia-v1", isDirectory: true)
    }
    func cancel() {
        lock.lock()
        generation = UUID()
        let running = process
        lock.unlock()
        if let running, running.isRunning {
            running.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if running.isRunning { kill(running.processIdentifier, SIGKILL) }
            }
        }
    }
    private func currentGeneration() -> UUID {
        lock.lock(); defer { lock.unlock() }
        return generation
    }
    private func check(_ id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        if generation != id { throw CancellationError() }
    }

    /// Test actual decoding, not just the extension or isPlayable flag (audio may fail independently).
    static func canDecode(_ url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        guard asset.isPlayable, asset.duration.seconds.isFinite, asset.duration.seconds > 0,
              !asset.tracks(withMediaType: .video).isEmpty else { return false }
        for type in [AVMediaType.video, .audio] {
            for track in asset.tracks(withMediaType: type) {
                do {
                    let reader = try AVAssetReader(asset: asset)
                    let settings: [String: Any] = type == .video
                        ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                        : [AVFormatIDKey: kAudioFormatLinearPCM]
                    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
                    guard reader.canAdd(output) else { return false }
                    reader.add(output)
                    guard reader.startReading() else { return false }
                    let sample = output.copyNextSampleBuffer()
                    reader.cancelReading()
                    if sample == nil { return false }
                } catch { return false }
            }
        }
        return true
    }

    func prepare(_ url: URL, force: Bool = false, status: @escaping (String) -> Void) async throws -> URL {
        cancel()
        let id = currentGeneration()
        return try await withCheckedThrowingContinuation { continuation in
            worker.async {
                do { continuation.resume(returning: try self.prepareSync(url, force: force, id: id, status: status)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func extractSubtitles(_ url: URL) async throws -> [(url: URL, title: String)] {
        cancel()
        let id = currentGeneration()
        return try await withCheckedThrowingContinuation { continuation in
            worker.async {
                do {
                    let input = ["-protocol_whitelist", "file,pipe", "-format_whitelist", "mov,matroska,webm,avi,asf,mpeg,mpegts,flv,ogg,rm", "-i", url.path]
                    let probe = try self.run("ffprobe", ["-v", "error"] + input + ["-show_streams", "-of", "json"], id: id)
                    let json = try JSONSerialization.jsonObject(with: probe) as? [String: Any]
                    let streams = (json?["streams"] as? [[String: Any]] ?? []).filter { $0["codec_type"] as? String == "subtitle" }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let key = SHA256.hash(data: Data("\(url.path)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)".utf8)).map { String(format: "%02x", $0) }.joined()
                    try FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
                    var result: [(url: URL, title: String)] = []
                    var pending: [(temporary: URL, output: URL, index: Int)] = []
                    defer { for item in pending { try? FileManager.default.removeItem(at: item.temporary) } }
                    for stream in streams.prefix(32) {
                        try self.check(id)
                        guard let index = stream["index"] as? Int,
                              ["subrip", "ass", "ssa", "webvtt", "mov_text"].contains(stream["codec_name"] as? String ?? "") else { continue }
                        let output = self.cacheDirectory.appendingPathComponent(key + ".embedded.\(index).srt")
                        if !FileManager.default.fileExists(atPath: output.path) {
                            let temporary = self.cacheDirectory.appendingPathComponent(UUID().uuidString + ".srt")
                            pending.append((temporary, output, index))
                        }
                        let tags = stream["tags"] as? [String: String] ?? [:]
                        let title = [tags["title"], tags["language"]].compactMap { $0 }.joined(separator: " · ")
                        result.append((output, "内嵌字幕 \(result.count + 1)" + (title.isEmpty ? "" : " · " + title)))
                    }
                    // Demux once for every missing track, rather than reading the movie once per language.
                    if !pending.isEmpty {
                        let outputs = pending.flatMap { ["-map", "0:\($0.index)", "-c:s", "subrip", $0.temporary.path] }
                        _ = try self.run("ffmpeg", ["-nostdin", "-v", "error", "-y"] + input + outputs, id: id)
                        try self.check(id)
                        for item in pending { try FileManager.default.moveItem(at: item.temporary, to: item.output) }
                    }
                    try self.check(id)
                    continuation.resume(returning: result)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func prepareSync(_ url: URL, force: Bool, id: UUID, status: @escaping (String) -> Void) throws -> URL {
        try check(id)
        let fm = FileManager.default
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let identity = "\(url.standardizedFileURL.path)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        let cached = cacheDirectory.appendingPathComponent(key + ".mov")
        if fm.fileExists(atPath: cached.path), Self.canDecode(cached) { try check(id); status("使用兼容缓存"); return cached }
        if !force && Self.canDecode(url) { try check(id); return url }
        guard fm.isExecutableFile(atPath: toolsDirectory.appendingPathComponent("ffmpeg").path),
              fm.isExecutableFile(atPath: toolsDirectory.appendingPathComponent("ffprobe").path) else {
            throw Failure(message: "系统无法解码这个文件，且当前应用缺少兼容组件。请安装包含兼容组件的完整版本。")
        }
        try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let allowed = "mov,matroska,webm,avi,asf,mpeg,mpegts,flv,ogg,rm,3g2,3gp"
        let input = ["-protocol_whitelist", "file,pipe", "-format_whitelist", allowed, "-i", url.path]
        let probe = try run("ffprobe", ["-v", "error"] + input + ["-show_streams", "-show_format", "-of", "json"], id: id)
        guard let object = try JSONSerialization.jsonObject(with: probe) as? [String: Any],
              let streams = object["streams"] as? [[String: Any]],
              let video = streams.first(where: { $0["codec_type"] as? String == "video" }) else {
            throw Failure(message: "没有找到可播放的视频轨道。")
        }
        let duration = ((object["format"] as? [String: Any])?["duration"] as? String).flatMap(Double.init) ?? 0
        let hdr = ["smpte2084", "arib-std-b67"].contains(video["color_transfer"] as? String ?? "")
        // Known unsupported video codecs cannot benefit from a whole-file MOV copy attempt.
        let needsVideoEncoding = ["wmv1", "wmv2", "wmv3", "vc1", "flv1", "vp8", "theora"].contains(video["codec_name"] as? String ?? "")
        let needsAudioEncoding = streams.contains { $0["codec_type"] as? String == "audio" && ["dts", "wmav1", "wmav2", "wmapro", "vorbis"].contains($0["codec_name"] as? String ?? "") }
        let copyAttempts: [(String, [String])] = [
            ("正在无损转换封装", ["-c", "copy"]),
            ("正在转换音频", ["-c:v", "copy", "-c:a", "aac", "-b:a", "192k"])
        ]
        let attempts = (needsVideoEncoding ? [] : (needsAudioEncoding ? Array(copyAttempts.dropFirst()) : copyAttempts)) + (hdr ? [] : [("正在转换视频", ["-c:v", "h264_videotoolbox", "-b:v", "12M", "-pix_fmt", "yuv420p", "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:a", "aac", "-b:a", "192k"])])
        for (label, codecs) in attempts {
            try check(id)
            let available = (try? fm.attributesOfFileSystem(forPath: cacheDirectory.path)[.systemFreeSize] as? NSNumber)?.int64Value ?? Int64.max
            guard available > 512 * 1024 * 1024 else { throw Failure(message: "磁盘空间不足，请清理兼容缓存后重试。") }
            status(label + "…首次打开可能需要等待")
            let temp = cacheDirectory.appendingPathComponent(UUID().uuidString + ".partial.mov")
            defer { try? fm.removeItem(at: temp) }
            do {
                _ = try run("ffmpeg", ["-nostdin", "-v", "error", "-y", "-threads", "2"] + input +
                    ["-map", "0:v:0", "-map", "0:a?", "-sn", "-dn"] + codecs +
                    ["-threads", "2", "-movflags", "+faststart", "-progress", "pipe:1", temp.path], id: id, progress: { seconds in
                        let detail = duration > 0 ? "\(min(99, Int(seconds / duration * 100)))%" : "已处理 \(Int(seconds)) 秒"
                        status(label + " · " + detail)
                    })
                try check(id)
                guard Self.canDecode(temp) else { continue }
                if duration > 0 && AVURLAsset(url: temp).duration.seconds + 2 < duration { continue }
                // Only fully converted and decoded results become reusable cache entries.
                if fm.fileExists(atPath: cached.path) { try fm.removeItem(at: cached) }
                try fm.moveItem(at: temp, to: cached)
                try check(id)
                pruneCache(keeping: cached)
                return cached
            } catch is CancellationError { throw CancellationError() }
            catch { try check(id) }
        }
        throw Failure(message: hdr ? "此文件的 HDR 编码仍无法播放；为避免错误的色彩转换，未进行 SDR 转码。" : "兼容转换失败。文件可能损坏、加密，或使用尚不支持的编码。")
    }

    private func run(_ tool: String, _ arguments: [String], id: UUID, progress: ((Double) -> Void)? = nil) throws -> Data {
        try check(id)
        let task = Process()
        task.executableURL = toolsDirectory.appendingPathComponent(tool)
        task.arguments = arguments
        task.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        lock.lock()
        guard generation == id else { lock.unlock(); throw CancellationError() }
        process = task
        do { try task.run() } catch { lock.unlock(); throw error }
        lock.unlock()
        var data = Data()
        while true {
            let chunk = pipe.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            data.append(chunk)
            if let progress {
                // Consume completed lines: replaying the buffer flooded the main queue with stale progress.
                if let newline = data.lastIndex(of: 10) {
                    let completed = data.prefix(through: newline)
                    data = Data(data.suffix(from: data.index(after: newline)))
                    if let text = String(data: completed, encoding: .utf8) {
                        for line in text.split(separator: "\n") where line.hasPrefix("out_time_us=") {
                            if let microseconds = Double(line.dropFirst(12)), microseconds.isFinite, microseconds >= 0 { progress(microseconds / 1_000_000) }
                        }
                    }
                }
                if data.count > 8192 { data.removeAll(keepingCapacity: true) }
            } else if data.count > 4 * 1024 * 1024 {
                task.terminate(); task.waitUntilExit()
                throw Failure(message: "媒体信息过大，无法安全读取。")
            }
        }
        task.waitUntilExit()
        try check(id)
        guard task.terminationStatus == 0 else { throw Failure(message: "无法读取或转换媒体文件。") }
        return data
    }

    func subtitleFiles(for media: URL?) -> [URL] {
        guard let media, media.deletingLastPathComponent().standardizedFileURL.path == cacheDirectory.standardizedFileURL.path else { return [] }
        let prefix = media.deletingPathExtension().lastPathComponent + ".s"
        return ((try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "srt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func clearCache(keeping current: URL?) {
        let preserved = Set(([current].compactMap { $0 }) + subtitleFiles(for: current))
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !preserved.contains(file) {
            if current != nil && file.lastPathComponent == "Subtitles" { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func pruneCache(keeping current: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        let entries = files.filter { $0.pathExtension == "mov" && !$0.lastPathComponent.contains("partial") }.map { url in
            (url, (try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])))
        }.sorted { ($0.1?.contentModificationDate ?? .distantPast) < ($1.1?.contentModificationDate ?? .distantPast) }
        var total = entries.reduce(Int64(0)) { $0 + Int64($1.1?.fileSize ?? 0) }
        for (url, values) in entries where total > 5 * 1024 * 1024 * 1024 && url != current {
            if (try? FileManager.default.removeItem(at: url)) != nil {
                total -= Int64(values?.fileSize ?? 0)
                for subtitle in subtitleFiles(for: url) { try? FileManager.default.removeItem(at: subtitle) }
            }
        }
    }
}
