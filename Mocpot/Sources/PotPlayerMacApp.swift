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
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
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

    func setupGlobalHotkeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyDown(event)
            return event
        }
    }

    func handleKeyDown(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommand = flags.contains(.command)
        let keyCode = event.keyCode

        guard let vm = viewModel else { return }

        // F key = fullscreen (no modifiers)
        if !isCommand && keyCode == 3 {
            vm.toggleFullscreen()
            return
        }

        // Space = play/pause (no modifiers)
        if !isCommand && keyCode == 49 {
            vm.togglePlayPause()
            return
        }

        if isCommand {
            switch keyCode {
            case 49:
                vm.togglePlayPause()
            case 3:
                vm.toggleFullscreen()
            default:
                break
            }
        }
    }
}
