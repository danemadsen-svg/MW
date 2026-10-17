import SwiftData
import SwiftUI
import WardrobeCore

/// Closet insights: gaps, items the generator can't use, unused and over-used pieces, and accent
/// colors that would pair with what's already there.
struct InsightsView: View {
    @Query(sort: \Item.createdAt) private var items: [Item]
    @State private var analysis: Analysis?

    /// The analyzer's output, plus whether the closet has any accent colors yet (which changes
    /// what the color suggestions mean).
    private struct Analysis: Sendable {
        let insights: WardrobeInsights
        let hasAccents: Bool
    }

    var body: some View {
        let snapshot = items.map(\.insightItem)
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to report", systemImage: "chart.bar")
                } description: {
                    Text("Add items to your closet to see wardrobe gaps, unworn pieces and color ideas.")
                }
                .foregroundStyle(Theme.Palette.textSecondary)
            } else if let analysis {
                list(analysis)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .themedScreen()
        .navigationTitle("Insights")
        // Keyed on the snapshot, so any change to the closet or its outfits recomputes.
        .task(id: snapshot) {
            await analyze(snapshot)
        }
    }

    private func list(_ analysis: Analysis) -> some View {
        let insights = analysis.insights
        let itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func resolve(_ ids: [UUID]) -> [Item] { ids.compactMap { itemsByID[$0] } }

        return List {
            if !insights.gaps.isEmpty {
                Section("Gaps") {
                    ForEach(insights.gaps, id: \.self) { gap in
                        let wording = InsightWording.gap(gap)
                        Label {
                            Text(wording.text)
                                .foregroundStyle(Theme.Palette.textPrimary)
                        } icon: {
                            Image(systemName: wording.symbol)
                                .foregroundStyle(Theme.Palette.accent)
                        }
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }

            itemSection(
                "Needs details",
                footer: "The outfit generator skips these until they have a color and, for clothing, a type.",
                items: resolve(insights.incompleteItemIDs),
                detail: InsightWording.missingDetails
            )
            itemSection(
                "Unused",
                footer: "Not in any saved outfit yet. Try building an outfit around one.",
                items: resolve(insights.unusedItemIDs),
                detail: { "Added \($0.createdAt.formatted(.relative(presentation: .named)))" }
            )
            itemSection(
                "Over-used",
                footer: "In far more outfits than the rest of your closet.",
                items: resolve(insights.overusedItemIDs),
                detail: { $0.outfits.count == 1 ? "In 1 outfit" : "In \($0.outfits.count) outfits" }
            )

            if !insights.accentSuggestions.isEmpty {
                Section {
                    ForEach(insights.accentSuggestions) { color in
                        HStack(spacing: Theme.Spacing.m) {
                            ColorSwatchView(color: color.rgb, size: 32)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(color.name)
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(analysis.hasAccents
                                    ? "Pairs with colors you already own."
                                    : "One of the most versatile colors in the dictionary.")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Suggested colors")
                } footer: {
                    Text("From A Dictionary of Color Combinations. A piece in one of these opens up new outfits.")
                }
                .listRowBackground(Theme.Palette.surface)
            }
        }
    }

    @ViewBuilder
    private func itemSection(_ title: String, footer: String, items: [Item], detail: @escaping (Item) -> String) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            ItemThumbnail(data: item.thumbnailData, category: item.category, cornerRadius: Theme.Radius.s)
                                .frame(width: 44, height: 44)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(item.displayName)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(detail(item))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                }
            } header: {
                Text(title)
            } footer: {
                Text(footer)
            }
            .listRowBackground(Theme.Palette.surface)
        }
    }

    // MARK: - Analysis

    @MainActor
    private func analyze(_ snapshot: [InsightItem]) async {
        let result = await Task.detached(priority: .utility) { () -> Analysis in
            let insights = InsightsAnalyzer().analyze(snapshot, now: .now)
            let colors = snapshot
                .filter { !OutfitGenerator.colorNeutralCategories.contains($0.category) }
                .flatMap(\.colors)
            return Analysis(insights: insights, hasAccents: !ColorHarmony().accentClusters(colors).isEmpty)
        }.value
        guard !Task.isCancelled else { return }
        analysis = result
    }
}

/// User-facing wording for insights.
private enum InsightWording {
    static func gap(_ gap: WardrobeInsights.Gap) -> (symbol: String, text: String) {
        switch gap {
        case .noTops:
            return (ClothingType.top.systemImage, "No tops yet. Add a top or a one-piece to start building outfits.")
        case .noBottoms:
            return (ClothingType.bottom.systemImage, "No bottoms yet. Add a bottom or a one-piece to start building outfits.")
        case .noShoes:
            return (ItemCategory.shoes.systemImage, "No shoes yet. A pair finishes every outfit.")
        case .noOuterwear:
            return (ClothingType.outerwear.systemImage, "No outerwear yet. A jacket or coat covers the colder months.")
        case let .unbalanced(tops, bottoms):
            if tops > bottoms {
                return ("scalemass", "\(count(tops, "top")) but only \(count(bottoms, "bottom")) — another bottom unlocks more outfits.")
            }
            return ("scalemass", "\(count(bottoms, "bottom")) but only \(count(tops, "top")) — another top unlocks more outfits.")
        case .onlyNeutrals:
            return ("paintpalette", "Everything is neutral. One accent color would give your outfits more character.")
        }
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    static func missingDetails(_ item: Item) -> String {
        let needsType = item.category == .clothing && item.clothingType == nil
        let needsColor = item.colors.isEmpty && item.category.usesColor
        switch (needsType, needsColor) {
        case (true, true): return "Needs a clothing type and a color"
        case (true, false): return "Needs a clothing type"
        default: return "Needs a color"
        }
    }
}

#Preview {
    NavigationStack { InsightsView() }
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
