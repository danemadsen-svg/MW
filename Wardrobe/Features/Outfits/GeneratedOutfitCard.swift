import SwiftUI
import WardrobeCore

/// One generator suggestion: its pieces, accent palette, harmony and a save button.
struct GeneratedOutfitCard: View {
    let outfit: GeneratedOutfit
    let itemsByID: [UUID: Item]
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            pieces
            palette
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("\(outfit.harmony.score.formatted(.percent.precision(.fractionLength(0)))) harmony")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let combinationID = outfit.harmony.paletteCombinationID {
                        Text("Book combination #\(combinationID)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onSave) {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "checkmark" : "bookmark")
                }
                .buttonStyle(.bordered)
                .disabled(isSaved)
            }
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    private var items: [Item] {
        outfit.itemIDs.compactMap { itemsByID[$0] }
    }

    private var pieces: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(items) { item in
                    ItemThumbnail(data: item.thumbnailData, category: item.category, cornerRadius: Theme.Radius.s)
                        .frame(width: 72, height: 72)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(item.displayName)
                }
            }
        }
    }

    @ViewBuilder
    private var palette: some View {
        let colors = outfit.harmony.matchedColors
        if colors.isEmpty {
            Text("All neutrals")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.m) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                        HStack(spacing: Theme.Spacing.xs) {
                            ColorSwatchView(color: color.rgb, size: 18)
                            Text(color.name)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Palette: \(colors.map(\.name).joined(separator: ", "))")
        }
    }
}
