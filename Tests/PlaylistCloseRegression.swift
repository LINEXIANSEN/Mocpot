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
                for attempt in 0..<10 {
                    vm.showPlaylist = true
                    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                    host.layoutSubtreeIfNeeded()
                    guard let button = closeButton(host) else { fatalError("Missing close button") }
                    precondition(button.isEnabled && !button.isHiddenOrHasHiddenAncestor)
                    precondition(button.acceptsFirstMouse(for: nil))
                    // Deliver mouse-down to the actual control while the clock
                    // changes; no mouse-up is needed to dismiss it.
                    vm.currentTime = Double(attempt)
                    if attempt % 2 == 0 {
                        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                            windowNumber: window.windowNumber, context: nil, eventNumber: attempt,
                            clickCount: 1, pressure: 1)!
                        button.mouseDown(with: event)
                    } else { button.performClick(nil) }
                    precondition(!vm.showPlaylist)
                    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                    precondition(!vm.showPlaylist && closeButton(host) == nil)
                    precondition(vm.playlist == [item] && vm.currentVideoURL == (playing ? item : nil))
                }
                print("PASS: native close action removes sidebar and preserves queue; fullscreen=\(fullscreen), playing=\(playing)")
            }
        }
    }
}
