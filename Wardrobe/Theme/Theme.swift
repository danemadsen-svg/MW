import SwiftUI

/// Design tokens for the app. The app is dark-only (see `UIUserInterfaceStyle` in project.yml),
/// so the palette is defined once rather than per color scheme.
enum Theme {
    enum Palette {
        static let background = Color(hex: 0x0E0E10)
        static let surface = Color(hex: 0x18181B)
        static let surfaceRaised = Color(hex: 0x232328)
        static let separator = Color(hex: 0x2E2E34)

        static let textPrimary = Color(hex: 0xF4F1EC)
        static let textSecondary = Color(hex: 0xA19D96)
        static let textTertiary = Color(hex: 0x6B6862)

        /// Muted brass. Mirrors `AccentColor` in the asset catalog.
        static let accent = Color(hex: 0xC9A66B)
        static let destructive = Color(hex: 0xE5484D)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 20
    }

    enum Typography {
        static let display = Font.system(.largeTitle, design: .serif).weight(.semibold)
        static let title = Font.system(.title2, design: .serif).weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let caption = Font.caption
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    /// Fills the screen with the app background and hides the default list/form background
    /// so scrolling containers pick up the theme.
    func themedScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
    }
}
