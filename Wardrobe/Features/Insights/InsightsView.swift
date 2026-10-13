import SwiftUI

struct InsightsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Nothing to report", systemImage: "chart.bar")
        } description: {
            Text("Unworn pieces, wardrobe gaps and over-used favorites will show up as your closet grows.")
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .themedScreen()
        .navigationTitle("Insights")
    }
}

#Preview {
    NavigationStack { InsightsView() }
        .preferredColorScheme(.dark)
}
