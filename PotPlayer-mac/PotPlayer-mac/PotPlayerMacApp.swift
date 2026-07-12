import SwiftUI

@main
struct MocpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
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
        guard let url = urls.first else { return }
        viewModel?.openFile(url: url)
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
        let isOption = flags.contains(.option)
        let keyCode = event.keyCode

        guard let vm = viewModel else { return }

        if isCommand {
            switch keyCode {
            case 49:
                vm.togglePlayPause()
            default:
                break
            }
        }

        if isOption {
            switch keyCode {
            case 49:
                vm.stopPlayback()
            default:
                break
            }
        }
    }
}
