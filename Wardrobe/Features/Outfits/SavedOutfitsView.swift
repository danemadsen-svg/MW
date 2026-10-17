import SwiftData
import SwiftUI
import WardrobeCore

/// Saved outfits, newest first (Chapter 2.6).
struct SavedOutfitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]

    @State private var favoritesOnly = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if outfits.isEmpty {
                ContentUnavailableView {
                    Label("No saved outfits", systemImage: "bookmark")
                } description: {
                    Text("Generate outfits and save the ones you like. They'll be here to come back to.")
                }
                .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                list
            }
        }
        .themedScreen()
        .alert("Couldn't save", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var list: some View {
        let visible = favoritesOnly ? outfits.filter(\.isFavorite) : outfits
        return List {
            Section {
                Toggle(isOn: $favoritesOnly) {
                    Label("Favorites only", systemImage: "star")
                }
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                if visible.isEmpty {
                    ContentUnavailableView {
                        Label("No favorites yet", systemImage: "star")
                    } description: {
                        Text("Star an outfit to find it here quickly.")
                    }
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .listRowBackground(Theme.Palette.background)
                } else {
                    ForEach(visible) { outfit in
                        NavigationLink {
                            OutfitDetailView(outfit: outfit)
                        } label: {
                            SavedOutfitRow(outfit: outfit)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                toggleFavorite(outfit)
                            } label: {
                                Label(outfit.isFavorite ? "Unfavorite" : "Favorite", systemImage: outfit.isFavorite ? "star.slash" : "star")
                            }
                            .tint(Theme.Palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(outfit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listRowBackground(Theme.Palette.surface)
                }
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func toggleFavorite(_ outfit: Outfit) {
        outfit.isFavorite.toggle()
        save()
    }

    private func delete(_ outfit: Outfit) {
        modelContext.delete(outfit)
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Your change couldn't be saved. \(error.localizedDescription)"
        }
    }
}

private struct SavedOutfitRow: View {
    let outfit: Outfit

    var body: some View {
        let items = outfit.orderedItems
        HStack(spacing: Theme.Spacing.m) {
            HStack(spacing: -Theme.Spacing.s) {
                ForEach(Array(items.prefix(3))) { item in
                    ItemThumbnail(data: item.thumbnailData, category: item.category, cornerRadius: Theme.Radius.s)
                        .frame(width: 40, height: 40)
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous)
                                .strokeBorder(Theme.Palette.surface, lineWidth: 2)
                        }
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(outfit.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)
                Text(summary(itemCount: items.count))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            if outfit.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.Palette.accent)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func summary(itemCount: Int) -> String {
        var parts = [itemCount == 1 ? "1 piece" : "\(itemCount) pieces"]
        if let season = outfit.season { parts.append(season.displayName) }
        if let formality = outfit.formality { parts.append(formality.displayName) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { SavedOutfitsView() }
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
