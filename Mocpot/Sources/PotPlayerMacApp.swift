import SwiftUI

@main
struct MocpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = PlayerViewModel()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    setupMenu()
                    viewModel.applyLaunchBehavior()
                    DispatchQueue.main.async {
                        NSApp.keyWindow?.identifier = NSUserInterfaceItemIdentifier("MocpotPlayer")
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
        #endif
    }

    private func setupMenu() {
        appDelegate.viewModel = viewModel
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: PlayerViewModel?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalHotkeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            viewModel?.openFile(url: url)
            break
        }
    }

    private var keyMonitor: Any?

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.persistCurrentPosition()
        viewModel?.saveSettings()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    func setupGlobalHotkeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.handleKeyDown(event) else { return event }
            return nil
        }
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let vm = viewModel, let window = NSApp.keyWindow,
              window.identifier?.rawValue == "MocpotPlayer",
              window.styleMask.contains(.resizable), window.attachedSheet == nil,
              !(window.firstResponder is NSTextView), !(window.firstResponder is NSTextField) else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        if flags == .command {
            switch event.keyCode {
            case 123: vm.seekBackward(seconds: 5)
            case 124: vm.seekForward(seconds: 5)
            case 126: vm.setVolume(vm.volume + 0.05)
            case 125: vm.setVolume(vm.volume - 0.05)
            case 1: vm.takeScreenshot()
            case 15: vm.toggleLooping()
            case 33: vm.previousTrack()
            case 30: vm.nextTrack()
            default: return false
            }
            return true
        }
        if flags == .shift, event.keyCode == 6, vm.currentVideoURL != nil {
            vm.subtitleDelay = 0
            vm.adjustSubtitleSync(0)
            return true
        }
        guard flags.isEmpty, vm.currentVideoURL != nil else { return false }
        switch event.keyCode {
        case 6: vm.adjustSubtitleSync(-0.1)
        case 7: vm.adjustSubtitleSync(0.1)
        case 49, 36: vm.togglePlayPause()
        case 3: vm.toggleFullscreen()
        case 35: vm.togglePiP()
        case 46: vm.toggleMute()
        case 123: vm.seekBackward()
        case 124: vm.seekForward()
        case 0: vm.setLoopPointA()
        case 11: vm.setLoopPointB()
        case 51: vm.clearABLoop()
        case 53:
            if window.styleMask.contains(.fullScreen) { vm.toggleFullscreen() }
            else { vm.stopPlayback() }
        default: return false
        }
        return true
    }
}
