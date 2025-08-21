import SwiftUI

// Enum representing available theme colors
enum Theme: String, CaseIterable {
    case light
    case dark
    case pink
}

/// Helper responsible for providing colors for a given theme
struct ThemeManager {
    /// Background color for a theme
    static func backgroundColor(for theme: Theme) -> Color {
        switch theme {
        case .light:
            return Color.white
        case .dark:
            return Color.black
        case .pink:
            return Color.pink
        }
    }
    
    /// Foreground color suitable for content on a theme background
    static func foregroundColor(for theme: Theme) -> Color {
        switch theme {
        case .light:
            return Color.black
        case .dark:
            return Color.white
        case .pink:
            return Color.white
        }
    }
}
