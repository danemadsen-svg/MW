import SwiftData
import SwiftUI

@main
struct WardrobeApp: App {
    private let container: Result<ModelContainer, any Error>

    init() {
        Appearance.configure()
        container = Result { try Persistence.makeContainer() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch container {
                case .success(let container):
                    RootView()
                        .modelContainer(container)
                case .failure(let error):
                    StorageErrorView(error: error)
                }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.Palette.accent)
        }
    }
}
