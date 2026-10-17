import SwiftUI

struct OutfitsView: View {
    private enum Mode: Hashable {
        case generate
        case saved
    }

    @State private var mode: Mode = .generate

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $mode) {
                Text("Generate").tag(Mode.generate)
                Text("Saved").tag(Mode.saved)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)

            // Both stay alive so generated suggestions survive a look at the saved list.
            ZStack {
                page(OutfitGeneratorView(), isActive: mode == .generate)
                page(SavedOutfitsView(), isActive: mode == .saved)
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Outfits")
    }

    private func page(_ content: some View, isActive: Bool) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}

#Preview {
    NavigationStack { OutfitsView() }
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
