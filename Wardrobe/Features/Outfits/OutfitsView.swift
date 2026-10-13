import SwiftUI

struct OutfitsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No outfits yet", systemImage: "sparkles")
        } description: {
            Text("Generated and saved outfits will appear here, built from color pairings that work together.")
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .themedScreen()
        .navigationTitle("Outfits")
    }
}

#Preview {
    NavigationStack { OutfitsView() }
        .preferredColorScheme(.dark)
}
