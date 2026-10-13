import SwiftUI

@main
struct WardrobeApp: App {
    init() {
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.Palette.accent)
        }
    }
}
