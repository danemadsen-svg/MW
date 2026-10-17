import SwiftData
import SwiftUI
import WardrobeCore

/// The closet: every item in a grid, with search, category and color filters (Chapter 1.6).
struct ClosetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]

    @State private var filter = ClosetFilter()
    @State private var addRequest: AddItemSource?
    @State private var editingItem: Item?
    @State private var itemPendingDelete: Item?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: Theme.Spacing.s)]

    var body: some View {
        Group {
            if items.isEmpty {
                emptyCloset
            } else {
                grid
            }
        }
        .themedScreen()
        .navigationTitle("Closet")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AddItemButton { addRequest = $0 }
            }
        }
        .addItemFlow($addRequest, itemCount: items.count)
        .sheet(item: $editingItem) { item in
            NavigationStack { ItemEditorView(item: item) }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: isConfirmingDelete,
            titleVisibility: .visible,
            presenting: itemPendingDelete
        ) { item in
            Button("Delete Item", role: .destructive) { delete(item) }
        } message: { item in
            Text(deleteMessage(for: item))
        }
        .alert("Couldn't Save", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Content

    private var emptyCloset: some View {
        ContentUnavailableView {
            Label("Your closet is empty", systemImage: "hanger")
        } description: {
            Text("Add clothing, shoes, watches, rings, cologne and more. Everything stays on this iPhone.")
        } actions: {
            AddItemButton(style: .prominent) { addRequest = $0 }
        }
        .foregroundStyle(Theme.Palette.textSecondary)
    }

    private var grid: some View {
        let visible = filter.apply(to: items)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                reviewBanner
                filterBar
                if visible.isEmpty {
                    ContentUnavailableView.search(text: filter.searchText)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.top, Theme.Spacing.xxl)
                } else {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                        ForEach(visible) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ClosetCell(item: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editingItem = item }
                                Button("Delete", systemImage: "trash", role: .destructive) { itemPendingDelete = item }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .searchable(text: $filter.searchText, prompt: "Search names and notes")
    }

    @ViewBuilder
    private var reviewBanner: some View {
        let count = items.filter(\.needsReview).count
        if count > 0 {
            NavigationLink {
                ReviewSuggestionsView()
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.Palette.accent)
                    Text(count == 1 ? "1 item has new suggestions" : "\(count) items have new suggestions")
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ChipButton(title: "All", isSelected: filter.scope == .all) {
                    filter.scope = .all
                }
                ForEach(ClosetFilter.categoriesPresent(in: items.map(\.category))) { category in
                    ChipButton(title: category.displayName, systemImage: category.systemImage, isSelected: filter.scope == .category(category)) {
                        filter.scope = filter.scope == .category(category) ? .all : .category(category)
                    }
                }
                if items.contains(where: \.isIncomplete) {
                    ChipButton(title: "Needs details", systemImage: "exclamationmark.circle", isSelected: filter.scope == .needsDetails) {
                        filter.scope = filter.scope == .needsDetails ? .all : .needsDetails
                    }
                }
                colorMenu
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private var colorMenu: some View {
        Menu {
            if filter.swatch != nil {
                Button("Any Color", systemImage: "xmark.circle") { filter.swatch = nil }
            }
            ForEach(GarmentSwatches.all) { swatch in
                Button {
                    filter.swatch = swatch
                } label: {
                    if filter.swatch == swatch {
                        Label(swatch.name, systemImage: "checkmark")
                    } else {
                        Text(swatch.name)
                    }
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if let swatch = filter.swatch {
                    ColorSwatchView(color: swatch.color, size: 14)
                    Text(swatch.name)
                } else {
                    Image(systemName: "paintpalette")
                    Text("Color")
                }
            }
            .font(.subheadline.weight(filter.swatch == nil ? .regular : .semibold))
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .foregroundStyle(filter.swatch == nil ? Theme.Palette.textPrimary : Theme.Palette.background)
            .background(filter.swatch == nil ? Theme.Palette.surfaceRaised : Theme.Palette.accent, in: Capsule())
        }
        .accessibilityLabel(filter.swatch.map { "Color filter: \($0.name)" } ?? "Filter by color")
    }

    // MARK: - Actions

    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { itemPendingDelete != nil }, set: { if !$0 { itemPendingDelete = nil } })
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func deleteMessage(for item: Item) -> String {
        let count = item.outfits.count
        switch count {
        case 0: return "This can't be undone."
        case 1: return "It will also be removed from 1 saved outfit. This can't be undone."
        default: return "It will also be removed from \(count) saved outfits. This can't be undone."
        }
    }

    private func delete(_ item: Item) {
        modelContext.delete(item)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "This item couldn't be deleted. \(error.localizedDescription)"
        }
        itemPendingDelete = nil
    }
}

/// One grid cell: thumbnail, name, and a badge when the item needs details.
private struct ClosetCell: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ItemThumbnail(data: item.thumbnailData, category: item.category)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if item.isIncomplete {
                        IncompleteBadge()
                    }
                }
            HStack(spacing: Theme.Spacing.xs) {
                if let color = item.primaryColor {
                    ColorSwatchView(color: color, size: 10)
                }
                Text(item.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [item.displayName]
        if let color = item.primaryColor {
            parts.append(GarmentSwatches.nearest(to: color).name)
        }
        if item.isIncomplete {
            parts.append("needs details")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack { ClosetView() }
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .environment(PurchaseManager())
        .preferredColorScheme(.dark)
}
