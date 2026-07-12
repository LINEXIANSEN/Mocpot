import Foundation
import SwiftUI

class PlaylistManager: ObservableObject {
    @Published var tracks: [PlaylistTrack] = []
    @Published var currentIndex: Int = -1
    @Published var shuffleMode = false
    @Published var repeatMode: RepeatMode = .none

    private var originalOrder: [PlaylistTrack] = []

    enum RepeatMode: String, CaseIterable {
        case none = "None"
        case one = "Repeat One"
        case all = "Repeat All"

        var iconName: String {
            switch self {
            case .none: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }
    }

    struct PlaylistTrack: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let title: String
        let duration: Double?
        let fileSize: Int64?

        var displayTitle: String {
            title.isEmpty ? url.lastPathComponent : title
        }

        var formattedDuration: String {
            guard let duration = duration, !duration.isNaN else { return "--:--" }
            let totalSeconds = Int(duration)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }

        var formattedSize: String {
            guard let size = fileSize else { return "" }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }

        static func == (lhs: PlaylistTrack, rhs: PlaylistTrack) -> Bool {
            lhs.id == rhs.id
        }
    }

    var currentTrack: PlaylistTrack? {
        guard currentIndex >= 0 && currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    var hasNext: Bool {
        switch repeatMode {
        case .one:
            return true
        case .all:
            return currentIndex < tracks.count - 1 || tracks.count > 0
        case .none:
            return currentIndex < tracks.count - 1
        }
    }

    var hasPrevious: Bool {
        switch repeatMode {
        case .one:
            return true
        case .all:
            return currentIndex > 0 || tracks.count > 0
        case .none:
            return currentIndex > 0
        }
    }

    func addTrack(url: URL, title: String? = nil, duration: Double? = nil) {
        let track = PlaylistTrack(
            url: url,
            title: title ?? url.deletingPathExtension().lastPathComponent,
            duration: duration,
            fileSize: getFileSize(url: url)
        )
        tracks.append(track)
        originalOrder.append(track)
    }

    func addTracks(urls: [URL]) {
        for url in urls {
            addTrack(url: url)
        }
    }

    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        let track = tracks[index]
        tracks.remove(at: index)
        originalOrder.removeAll { $0.id == track.id }

        if currentIndex >= tracks.count {
            currentIndex = tracks.count - 1
        }
    }

    func removeTrack(_ track: PlaylistTrack) {
        if let index = tracks.firstIndex(of: track) {
            removeTrack(at: index)
        }
    }

    func clear() {
        tracks.removeAll()
        originalOrder.removeAll()
        currentIndex = -1
    }

    func playTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        currentIndex = index
    }

    func nextTrack() -> PlaylistTrack? {
        guard hasNext else { return nil }

        switch repeatMode {
        case .one:
            return currentTrack
        case .all:
            currentIndex = (currentIndex + 1) % tracks.count
        case .none:
            currentIndex += 1
        }

        return currentTrack
    }

    func previousTrack() -> PlaylistTrack? {
        guard hasPrevious else { return nil }

        switch repeatMode {
        case .one:
            return currentTrack
        case .all:
            currentIndex = (currentIndex - 1 + tracks.count) % tracks.count
        case .none:
            currentIndex -= 1
        }

        return currentTrack
    }

    func shuffle() {
        guard tracks.count > 1 else { return }
        shuffleMode = true
        let currentTrack = self.currentTrack
        tracks.shuffle()

        if let current = currentTrack, let newIndex = tracks.firstIndex(of: current) {
            currentIndex = newIndex
        } else {
            currentIndex = 0
        }
    }

    func unshuffle() {
        guard shuffleMode else { return }
        shuffleMode = false

        let currentTrack = self.currentTrack
        tracks = originalOrder

        if let current = currentTrack, let newIndex = tracks.firstIndex(of: current) {
            currentIndex = newIndex
        } else {
            currentIndex = 0
        }
    }

    func moveTrack(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        updateOriginalOrder()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .none:
            repeatMode = .one
        case .one:
            repeatMode = .all
        case .all:
            repeatMode = .none
        }
    }

    private func updateOriginalOrder() {
        if !shuffleMode {
            originalOrder = tracks
        }
    }

    private func getFileSize(url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }

    func savePlaylist(to url: URL) {
        var content = "#EXTM3U\n"

        for track in tracks {
            if let duration = track.duration {
                content += "#EXTINF:\(Int(duration)),\(track.displayTitle)\n"
            }
            content += "\(track.url.path)\n"
        }

        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    func loadPlaylist(from url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        clear()

        let lines = content.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#EXTINF:") {
                let info = String(line.dropFirst(8))
                let parts = info.components(separatedBy: ",")
                let duration = Double(parts.first ?? "0") ?? 0

                i += 1
                if i < lines.count {
                    let path = lines[i].trimmingCharacters(in: .whitespaces)
                    let fileURL = URL(fileURLWithPath: path)
                    addTrack(url: fileURL, duration: duration > 0 ? duration : nil)
                }
            } else if !line.isEmpty && !line.hasPrefix("#") {
                let fileURL = URL(fileURLWithPath: line)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    addTrack(url: fileURL)
                }
            }

            i += 1
        }
    }
}
