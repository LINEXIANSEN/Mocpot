import SwiftUI

final class ThemeManager: ObservableObject {
    // Publish explicitly so every window updates when a setting changes.
    @Published var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: "themeMode") }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        themeMode = ThemeMode(rawValue: defaults.string(forKey: "themeMode") ?? "") ?? .system
    }

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system = "跟随系统"
        case light = "浅色"
        case dark = "深色"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max"
            case .dark: return "moon"
            }
        }
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Material surfaces keep controls readable while letting the content behind softly show through.
struct PlayerPalette {
    let scheme: ColorScheme
    private var isDark: Bool { scheme == .dark }
    var canvas: Color { isDark ? Color(red: 0.065, green: 0.075, blue: 0.095) : Color(red: 0.95, green: 0.96, blue: 0.98) }
    var surface: Color { isDark ? Color(red: 0.11, green: 0.125, blue: 0.15) : .white }
    var inset: Color { isDark ? Color(red: 0.15, green: 0.165, blue: 0.20) : Color(red: 0.925, green: 0.94, blue: 0.96) }
    var border: Color { isDark ? .white.opacity(0.13) : .black.opacity(0.1) }
    var accent: Color { isDark ? Color(red: 0.46, green: 0.70, blue: 1) : Color(red: 0.12, green: 0.34, blue: 0.72) }
}

struct PlayerSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        let palette = PlayerPalette(scheme: scheme)
        content
            .foregroundColor(.primary)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .background(palette.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(palette.border, lineWidth: 1))
    }
}

struct ThemeModePicker: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        HStack(spacing: 12) {
            ForEach(ThemeManager.ThemeMode.allCases) { mode in
                Button { themeManager.themeMode = mode } label: {
                    VStack(spacing: 10) {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 4).fill(mode == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 5) {
                                Capsule().fill(mode == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.65)).frame(width: 38, height: 4)
                                RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.25))
                            }.padding(8)
                        }
                        .frame(height: 44)
                        .background(mode == .dark ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                            Spacer(minLength: 0)
                            if themeManager.themeMode == mode { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
                        }.font(.caption)
                    }
                    .padding(12)
                    .background(themeManager.themeMode == mode ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeManager.themeMode == mode ? Color.accentColor : .clear, lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.rawValue)
                .accessibilityAddTraits(themeManager.themeMode == mode ? .isSelected : [])
            }
        }
    }
}
