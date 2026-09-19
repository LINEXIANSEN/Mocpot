import AppKit
import Combine
import SwiftUI

/// Renders only our own SwiftUI components into local bitmaps; no screen capture.
@main
struct ThemeSnapshots {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let suite = "MocpotThemeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let theme = ThemeManager(defaults: defaults)
        var changes = 0
        let subscription = theme.objectWillChange.sink { changes += 1 }
        for mode in ThemeManager.ThemeMode.allCases {
            theme.themeMode = mode
            precondition(ThemeManager(defaults: defaults).themeMode == mode)
            precondition(theme.colorScheme == (mode == .system ? nil : mode == .light ? .light : .dark))
        }
        precondition(changes == 3)
        withExtendedLifetime(subscription) {}
        print("PASS: all theme modes publish, persist and resolve correctly")

        let vm = PlayerViewModel(defaults: defaults)
        vm.recentFiles = [URL(fileURLWithPath: "/Movies/山野之间.mp4"), URL(fileURLWithPath: "/Movies/海岸线-360.mov")]
        vm.playlist = vm.recentFiles
        vm.duration = 120
        vm.currentTime = 36
        vm.subtitleCues = [SubtitleCue(start: 0, end: 120, text: "字幕样式预览 · Subtitle preview")]
        vm.subtitleTracks = [SubtitleTrack(id: 0, name: "示例字幕.srt", language: "中文")]
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            theme.themeMode = scheme == .light ? .light : .dark
            let suffix = scheme == .light ? "light" : "dark"
            let views: [(String, AnyView, CGSize)] = [
                ("welcome", AnyView(WelcomeView()), CGSize(width: 1000, height: 800)),
                ("controls", AnyView(VStack { BottomControls(showQuickSettings: .constant(false)); QuickSettingsPanel(showPanel: .constant(true)) }.padding(20).background(Color.black)), CGSize(width: 900, height: 700)),
                ("settings", AnyView(GeneralTab()), CGSize(width: 660, height: 550)),
                ("subtitle-settings", AnyView(ScrollView { SubtitleTab() }), CGSize(width: 660, height: 580)),
                ("audio-settings", AnyView(AudioTab()), CGSize(width: 660, height: 580)),
                ("subtitles", AnyView(PlaybackChrome { Color.black }), CGSize(width: 1000, height: 700)),
                ("playlist", AnyView(PlaylistView()), CGSize(width: 280, height: 600)),
                ("playlist-rows", AnyView(VStack {
                    PlaylistItemView(url: vm.recentFiles[0], isSelected: true)
                    PlaylistItemView(url: vm.recentFiles[1], isSelected: false)
                }.padding(16).modifier(PlayerSurface())), CGSize(width: 280, height: 160))
            ]
            for (name, view, size) in views {
                let content = view.environmentObject(vm).environmentObject(theme)
                    .environment(\.colorScheme, scheme).tint(PlayerPalette(scheme: scheme).accent)
                    .accentColor(PlayerPalette(scheme: scheme).accent)
                    .frame(width: size.width, height: size.height)
                let host = NSHostingView(rootView: content)
                host.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                host.frame = CGRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("No bitmap") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
                try png.write(to: folder.appendingPathComponent("\(name)-\(suffix).png"))
                print("Rendered: \(name)-\(suffix)")
            }
        }
    }
}
