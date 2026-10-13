import UIKit

/// UIKit-level appearance for chrome SwiftUI doesn't fully expose (navigation and tab bars).
enum Appearance {
    static func configure() {
        let background = UIColor(Theme.Palette.background)
        let surface = UIColor(Theme.Palette.surface)
        let textPrimary = UIColor(Theme.Palette.textPrimary)
        let textTertiary = UIColor(Theme.Palette.textTertiary)
        let accent = UIColor(Theme.Palette.accent)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = background
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: serifFont(style: .headline, weight: .semibold),
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: serifFont(style: .largeTitle, weight: .semibold),
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = surface
        tab.shadowColor = UIColor(Theme.Palette.separator)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = textTertiary
            item.normal.titleTextAttributes = [.foregroundColor: textTertiary]
            item.selected.iconColor = accent
            item.selected.titleTextAttributes = [.foregroundColor: accent]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    private static func serifFont(style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let weighted = base.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight],
        ])
        let descriptor = weighted.withDesign(.serif) ?? weighted
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }
}
