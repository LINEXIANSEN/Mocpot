import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("themeMode") var themeMode: ThemeMode = .system
    
    enum ThemeMode: String, CaseIterable {
        case system = "跟随系统"
        case light = "浅色"
        case dark = "深色"
    }
    
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
