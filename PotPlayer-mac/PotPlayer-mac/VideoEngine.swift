import AVFoundation
import Foundation

class VideoEngine {
    static let shared = VideoEngine()

    private init() {}

    func detectVideoType(from url: URL) -> VideoType {
        let filename = url.lastPathComponent.lowercased()

        if filename.contains("360") || filename.contains("vr") {
            return .vr360
        }
        if filename.contains("sbs") || filename.contains("sidebyside") {
            return .threeDSideBySide
        }
        if filename.contains("ou") || filename.contains("overunder") {
            return .threeDOverUnder
        }
        if filename.contains("3d") || filename.contains("stereo") {
            return .threeDSideBySide
        }
        if filename.contains("180") || filename.contains("dome") {
            return .vr180
        }

        return .standard
    }

    func analyzeVideo(url: URL) async -> VideoAnalysis {
        let asset = AVURLAsset(url: url)
        var analysis = VideoAnalysis()

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
        analysis.fileSize = Int64(resourceValues?.fileSize ?? 0)
        analysis.creationDate = resourceValues?.creationDate

        return analysis
    }

    func getSupportedFormats() -> [String] {
        return [
            "mp4", "mkv", "avi", "mov", "wmv", "flv",
            "webm", "m4v", "3gp", "ogv", "mpg", "mpeg",
            "ts", "mts", "m2ts", "vob"
        ]
    }

    func isSupportedFormat(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return getSupportedFormats().contains(ext)
    }

    func getVideoInfo(from url: URL) -> VideoInfo {
        var info = VideoInfo()
        info.filename = url.lastPathComponent
        info.path = url.path
        info.format = url.pathExtension.uppercased()

        let resourceValues = try? url.resourceValues(forKeys: [
            .fileSizeKey, .creationDateKey, .contentModificationDateKey
        ])
        info.fileSize = Int64(resourceValues?.fileSize ?? 0)
        info.creationDate = resourceValues?.creationDate
        info.modificationDate = resourceValues?.contentModificationDate

        return info
    }
}

enum VideoType {
    case standard
    case vr360
    case vr180
    case threeDSideBySide
    case threeDOverUnder
    case threeDAnaglyph
}

struct VideoAnalysis {
    var width: Int = 0
    var height: Int = 0
    var duration: Double = 0
    var fps: Double = 0
    var bitrate: Int = 0
    var codec: String = ""
    var hasAudio: Bool = false
    var hasSubtitles: Bool = false
    var fileSize: Int64 = 0
    var creationDate: Date?
}

struct VideoInfo {
    var filename: String = ""
    var path: String = ""
    var format: String = ""
    var fileSize: Int64 = 0
    var creationDate: Date?
    var modificationDate: Date?
}
