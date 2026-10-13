import SwiftUI

enum AppTab: Hashable {
    case closet
    case outfits
    case insights
    case settings
}

struct RootView: View {
    @State private var selection: AppTab = .closet

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { ClosetView() }
                .tabItem { Label("Closet", systemImage: "hanger") }
                .tag(AppTab.closet)

            NavigationStack { OutfitsView() }
                .tabItem { Label("Outfits", systemImage: "sparkles") }
                .tag(AppTab.outfits)

            NavigationStack { InsightsView() }
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(AppTab.insights)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
