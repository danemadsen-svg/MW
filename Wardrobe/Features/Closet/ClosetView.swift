import SwiftUI

struct ClosetView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Your closet is empty", systemImage: "hanger")
        } description: {
            Text("Clothing, shoes, watches, rings, cologne and more will live here once you start adding items.")
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .themedScreen()
        .navigationTitle("Closet")
    }
}

#Preview {
    NavigationStack { ClosetView() }
        .preferredColorScheme(.dark)
}
