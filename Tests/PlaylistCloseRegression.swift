import AppKit
import SwiftUI

final class TestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@main struct PlaylistCloseRegression {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let suite = "MocpotPlaylistClose-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = PlayerViewModel(defaults: defaults)
        let theme = ThemeManager(defaults: defaults)
        let item = URL(fileURLWithPath: "/tmp/playlist-test.mp4")
        vm.playlist = [item]
        let window = TestWindow(contentRect: NSRect(x: 100, y: 100, width: 1100, height: 700),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: ContentView().environmentObject(vm).environmentObject(theme).frame(width: 1100, height: 700))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        defer { window.close() }
        func closeButton(_ view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.identifier?.rawValue == "playlist.close" { return button }
            return view.subviews.lazy.compactMap { closeButton($0) }.first
        }
        for fullscreen in [false, true] {
            for playing in [false, true] {
                vm.isFullscreen = fullscreen
                vm.currentVideoURL = playing ? item : nil
                vm.isPlaying = playing
                for _ in 0..<2 {
                    vm.showPlaylist = true
                    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                    host.layoutSubtreeIfNeeded()
                    guard let button = closeButton(host) else { fatalError("Missing close button") }
                    // Exercise the real native target/action and subsequent SwiftUI
                    // removal. Physical pointer routing requires a foreground UI test.
                    precondition(button.isEnabled && !button.isHiddenOrHasHiddenAncestor)
                    button.performClick(nil)
                    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                    precondition(!vm.showPlaylist && closeButton(host) == nil)
                    precondition(vm.playlist == [item] && vm.currentVideoURL == (playing ? item : nil))
                }
                print("PASS: native close action removes sidebar and preserves queue; fullscreen=\(fullscreen), playing=\(playing)")
            }
        }
    }
}
