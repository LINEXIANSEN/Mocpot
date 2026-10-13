import AppKit
import SwiftUI

/// Reads a user-selected movie without modifying media or persistent preferences.
@main struct ReadOnlyPlaybackProbe {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let suite = "MocpotProbe-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = PlayerViewModel(defaults: defaults)
        vm.autoScanSiblings = false; vm.autoPlayNext = false
        vm.rememberLastPosition = false; vm.resumePlayback = false; vm.volume = 0
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1280, height: 720), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView().environmentObject(vm).environmentObject(ThemeManager(defaults: defaults)))
        window.makeKeyAndOrderFront(nil)
        defer { vm.returnToHome(); window.close() }
        vm.openFile(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let deadline = Date().addingTimeInterval(30)
        while vm.isLoading || vm.currentTime < 0.2 {
            if let error = vm.playbackError { fatalError(error) }
            precondition(Date() < deadline, "Playback startup timed out")
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard let direct = vm.directPlayback else { fatalError("This probe currently measures direct playback") }
        print("START", await direct.property("hwdec-current"), await direct.property("video-codec"))
        func closeButton(_ view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.identifier?.rawValue == "playlist.close" { return button }
            return view.subviews.lazy.compactMap { closeButton($0) }.first
        }
        for target in [0.0, 1200.0, 3000.0] where target < vm.duration {
            if target > 0 { vm.seek(to: target) }
            for sample in 0..<20 {
                let before = Date()
                try await Task.sleep(nanoseconds: 1_000_000_000)
                var data: [String: String] = ["target": String(target), "sample": String(sample), "interval": String(Date().timeIntervalSince(before))]
                for name in ["time-pos", "hwdec-current", "decoder-frame-drop-count", "frame-drop-count", "mistimed-frame-count", "avsync", "demuxer-cache-duration", "paused-for-cache", "cache-buffering-state"] {
                    data[name] = await direct.property(name)
                }
                let json = try JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])
                print(String(data: json, encoding: .utf8)!)
                if sample == 5 || sample == 10 || sample == 15 {
                    vm.showPlaylist = true
                    try await Task.sleep(nanoseconds: 200_000_000)
                    guard let button = closeButton(window.contentView!) else { fatalError("Playlist close control missing") }
                    let event = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                        context: nil, eventNumber: sample, clickCount: 1, pressure: 1)!
                    button.mouseDown(with: event)
                    precondition(!vm.showPlaylist)
                    try await Task.sleep(nanoseconds: 200_000_000)
                    precondition(closeButton(window.contentView!) == nil)
                    print("PASS: playlist dismissed during direct playback")
                }
            }
        }
        precondition(vm.playbackError == nil)
        print("Probe complete")
    }
}
