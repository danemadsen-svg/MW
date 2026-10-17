import SwiftData
import SwiftUI
import WardrobeCore

/// One item: its photo and attributes, with edit, delete and "build an outfit" (Chapter 1.7).
struct ItemDetailView: View {
    let item: Item

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var isBuildingOutfit = false
    @State private var isConfirmingDelete = false
    /// Set before deleting so the body stops reading the deleted model while dismissing.
    @State private var isDeleted = false
    @State private var errorMessage: String?

    init(item: Item) {
        self.item = item
    }

    var body: some View {
        if isDeleted {
            Theme.Palette.background.ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        List {
            Section {
                ItemThumbnail(data: item.photoData ?? item.thumbnailData, category: item.category, cornerRadius: Theme.Radius.m)
                    .aspectRatio(1, contentMode: .fit)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.m, leading: Theme.Spacing.m, bottom: Theme.Spacing.m, trailing: Theme.Spacing.m))
                    .accessibilityLabel("Photo of \(item.displayName)")
            }
            .listRowBackground(Theme.Palette.surface)

            if item.isIncomplete {
                Section {
                    Label {
                        Text(missingDetailsText)
                            .foregroundStyle(Theme.Palette.textPrimary)
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    Button("Add Details") { isEditing = true }
                }
                .listRowBackground(Theme.Palette.surface)
            }

            Section("Details") {
                LabeledContent("Category", value: item.category.displayName)
                if item.category == .clothing {
                    LabeledContent("Type", value: item.clothingType?.displayName ?? "Not set")
                }
                LabeledContent("Colors") {
                    colorValue
                }
                LabeledContent("Seasons", value: item.seasons.summary)
                LabeledContent("Formality", value: item.formality?.displayName ?? "Any")
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .listRowBackground(Theme.Palette.surface)

            if !item.notes.isEmpty {
                Section("Notes") {
                    Text(item.notes)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                .listRowBackground(Theme.Palette.surface)
            }

            Section {
                Button {
                    isBuildingOutfit = true
                } label: {
                    Label("Build an Outfit with This", systemImage: "sparkles")
                }
                .disabled(item.isIncomplete)
                LabeledContent("Saved outfits", value: "\(item.outfits.count)")
                    .foregroundStyle(Theme.Palette.textPrimary)
                LabeledContent("Added", value: item.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(Theme.Palette.textPrimary)
            } footer: {
                if item.isIncomplete {
                    Text("Add the missing details to build outfits around this item.")
                }
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                Button("Delete Item", role: .destructive) { isConfirmingDelete = true }
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .themedScreen()
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack { ItemEditorView(item: item) }
        }
        .sheet(isPresented: $isBuildingOutfit) {
            NavigationStack {
                OutfitGeneratorView(anchorItemID: item.id)
                    .navigationTitle("Build an Outfit")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { isBuildingOutfit = false }
                        }
                    }
            }
        }
        .confirmationDialog("Delete this item?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Item", role: .destructive) { delete() }
        } message: {
            Text(item.outfits.isEmpty ? "This can't be undone." : "It will also be removed from its saved outfits. This can't be undone.")
        }
        .alert("Couldn't Save", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var colorValue: some View {
        let colors = item.colors
        if colors.isEmpty {
            Text(item.category.usesColor ? "Not set" : "Goes with everything")
                .foregroundStyle(Theme.Palette.textSecondary)
        } else {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    ColorSwatchView(color: color, size: 16)
                    Text(GarmentSwatches.nearest(to: color).name)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var missingDetailsText: String {
        let needsType = item.category == .clothing && item.clothingType == nil
        let needsColor = item.colors.isEmpty && item.category.usesColor
        switch (needsType, needsColor) {
        case (true, true): return "Add a clothing type and a color so outfits can include this."
        case (true, false): return "Add a clothing type so outfits can include this."
        default: return "Add a color so outfits can include this."
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func delete() {
        isDeleted = true
        modelContext.delete(item)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            isDeleted = false
            errorMessage = "This item couldn't be deleted. \(error.localizedDescription)"
        }
    }
}
