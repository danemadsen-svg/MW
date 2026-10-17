import SwiftData
import SwiftUI
import WardrobeCore

/// Items with auto-tag suggestions waiting for the user (Chapter 3.4): accept or dismiss each, or
/// accept them all.
struct ReviewSuggestionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Item> { $0.needsReview }, sort: \Item.createdAt, order: .reverse)
    private var items: [Item]

    @State private var errorMessage: String?

    init() {}

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("All caught up", systemImage: "checkmark.circle")
                } description: {
                    Text("New suggestions from your photos will appear here.")
                }
                .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                List {
                    Section {
                        ForEach(items) { item in
                            SuggestionRow(item: item, onAccept: { accept(item) }, onDismiss: { dismissSuggestion(on: item) })
                        }
                    } footer: {
                        Text("Suggestions come from your photos, on this iPhone. Accepting one replaces the current value.")
                    }
                    .listRowBackground(Theme.Palette.surface)
                }
            }
        }
        .themedScreen()
        .navigationTitle("Suggestions")
        .toolbar {
            if items.count > 1 {
                ToolbarItem(placement: .primaryAction) {
                    Button("Accept All") { acceptAll() }
                }
            }
        }
        .alert("Couldn't Save", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func accept(_ item: Item) {
        item.acceptSuggestions()
        save()
    }

    private func dismissSuggestion(on item: Item) {
        item.needsReview = false
        save()
    }

    private func acceptAll() {
        for item in items {
            item.acceptSuggestions()
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Your changes couldn't be saved. \(error.localizedDescription)"
        }
    }
}

extension SchemaV1.Item {
    /// Copies every suggested value into the item's own fields and clears the review flag.
    /// A suggested clothing type only applies when the item ends up as clothing.
    func acceptSuggestions() {
        if let category = suggestedCategory {
            self.category = category
        }
        if category == .clothing {
            if let type = suggestedClothingType {
                clothingType = type
            }
        } else {
            clothingType = nil
        }
        if let primary = suggestedPrimaryColor {
            primaryColor = primary
            let secondary = suggestedSecondaryColor
            secondaryColor = secondary == primary ? nil : secondary
        }
        needsReview = false
        touch()
    }
}

/// One item's current values beside the suggestion.
private struct SuggestionRow: View {
    let item: Item
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                ItemThumbnail(data: item.thumbnailData, category: item.category, cornerRadius: Theme.Radius.s)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                Text(item.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }

            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.s) {
                GridRow {
                    Text("")
                    Text("Now").font(Theme.Typography.caption).foregroundStyle(Theme.Palette.textTertiary)
                    Text("Suggested").font(Theme.Typography.caption).foregroundStyle(Theme.Palette.textTertiary)
                }
                GridRow {
                    Text("Type").font(Theme.Typography.caption).foregroundStyle(Theme.Palette.textSecondary)
                    Text(kind(category: item.category, type: item.clothingType))
                    Text(suggestedKind)
                }
                GridRow {
                    Text("Colors").font(Theme.Typography.caption).foregroundStyle(Theme.Palette.textSecondary)
                    colors(item.colors)
                    colors([item.suggestedPrimaryColor, item.suggestedSecondaryColor].compactMap { $0 })
                }
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Palette.textPrimary)

            HStack(spacing: Theme.Spacing.m) {
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    private var suggestedKind: String {
        guard let category = item.suggestedCategory else { return "—" }
        return kind(category: category, type: item.suggestedClothingType)
    }

    private func kind(category: ItemCategory, type: ClothingType?) -> String {
        if category == .clothing, let type { return type.displayName }
        return category.singularName
    }

    @ViewBuilder
    private func colors(_ colors: [RGBColor]) -> some View {
        if colors.isEmpty {
            Text("—")
        } else {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    ColorSwatchView(color: color, size: 14)
                    Text(GarmentSwatches.nearest(to: color).name)
                        .font(Theme.Typography.caption)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
