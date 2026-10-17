import SwiftData
import SwiftUI

@main
struct WardrobeApp: App {
    private let container: Result<ModelContainer, any Error>
    @State private var purchases = PurchaseManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
                        .environment(purchases)
                        .task { purchases.start() }
                        .task {
                            // Suggest tags for photos the current auto-tagger hasn't seen yet.
                            await BackgroundRetagger(modelContainer: container).run(tagger: VisionAutoTagger())
                        }
                        .fullScreenCover(isPresented: showsOnboarding) {
                            OnboardingView { hasCompletedOnboarding = true }
                        }
                case .failure(let error):
                    StorageErrorView(error: error)
                }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.Palette.accent)
        }
    }

    private var showsOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { isPresented in
                if !isPresented { hasCompletedOnboarding = true }
            }
        )
    }
}
