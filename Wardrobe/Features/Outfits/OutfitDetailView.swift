import SwiftData
import SwiftUI
import WardrobeCore

/// A saved outfit: sketch preview, pieces, details, and rename / favorite / share / delete.
struct OutfitDetailView: View {
    let outfit: Outfit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sketch: UIImage?
    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var isConfirmingDelete = false
    /// Set before deleting so the body stops reading the deleted model while the view is dismissed.
    @State private var isDeleted = false
    @State private var errorMessage: String?

    init(outfit: Outfit) {
        self.outfit = outfit
    }

    /// What the sketch depends on: the pieces, in order, and when each was last edited.
    private struct SketchInput: Equatable {
        let itemIDs: [UUID]
        let edits: [Date]
    }

    var body: some View {
        if isDeleted {
            Theme.Palette.background.ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        let items = outfit.orderedItems
        return List {
            Section {
                sketchPreview
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                    .padding(Theme.Spacing.m)
                    .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Theme.Palette.surface)

            Section("Pieces") {
                if items.isEmpty {
                    Text("This outfit's pieces are no longer in your closet.")
                        .foregroundStyle(Theme.Palette.textSecondary)
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            pieceRow(item)
                        }
                    }
                }
            }
            .listRowBackground(Theme.Palette.surface)

            detailsSection
        }
        .themedScreen()
        .navigationTitle(outfit.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task(id: SketchInput(itemIDs: items.map(\.id), edits: items.map(\.updatedAt))) {
            await renderSketch()
        }
        .alert("Rename outfit", isPresented: $isRenaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { rename() }
        } message: {
            Text("Leave it empty to name the outfit after its pieces.")
        }
        .confirmationDialog("Delete this outfit?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Outfit", role: .destructive) { delete() }
        } message: {
            Text("Its pieces stay in your closet.")
        }
        .alert("Couldn't save", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Parts

    @ViewBuilder
    private var sketchPreview: some View {
        if let sketch {
            Image(uiImage: sketch)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Sketch preview of \(outfit.displayName)")
        } else {
            Theme.Palette.background
                .aspectRatio(0.75, contentMode: .fit)
                .overlay { ProgressView() }
                .accessibilityElement()
                .accessibilityLabel("Drawing sketch preview")
        }
    }

    private func pieceRow(_ item: Item) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            ItemThumbnail(data: item.thumbnailData, category: item.category, cornerRadius: Theme.Radius.s)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.displayName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(item.category.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Season", value: outfit.season?.displayName ?? "Any season")
            LabeledContent("Formality", value: outfit.formality?.displayName ?? "Any")
            if let score = outfit.score {
                LabeledContent("Score", value: score.formatted(.percent.precision(.fractionLength(0))))
            }
            if let combinationID = outfit.paletteCombinationID {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    LabeledContent("Palette", value: "Book combination #\(combinationID)")
                    paletteColors(combinationID)
                }
            }
            LabeledContent("Saved", value: outfit.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func paletteColors(_ combinationID: Int) -> some View {
        let dictionary = ColorDictionary.standard
        let colors = dictionary.combination(id: combinationID)?.colorIDs.compactMap(dictionary.color(id:)) ?? []
        return HStack(spacing: Theme.Spacing.m) {
            ForEach(colors) { color in
                HStack(spacing: Theme.Spacing.xs) {
                    ColorSwatchView(color: color.rgb, size: 18)
                    Text(color.name)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let sketch {
                let image = Image(uiImage: sketch)
                ShareLink(item: image, preview: SharePreview(outfit.displayName, image: image))
            }
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: outfit.isFavorite ? "star.fill" : "star")
            }
            .accessibilityLabel(outfit.isFavorite ? "Remove from favorites" : "Add to favorites")
            Menu {
                Button("Rename", systemImage: "pencil") {
                    draftName = outfit.name
                    isRenaming = true
                }
                Button("Delete Outfit", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Actions

    @MainActor
    private func renderSketch() async {
        let items = outfit.orderedItems
        let pieces = items.map { ($0.sketchPiece, $0.thumbnailData) }
        let fills = Dictionary(
            items.compactMap { item in item.primaryColor.map { (item.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        let size = CGSize(width: 900, height: 1200)
        let image = await Task.detached(priority: .userInitiated) {
            SketchRenderer.render(pieces: pieces, fillColors: fills, size: size)
        }.value
        guard !Task.isCancelled else { return }
        sketch = image
    }

    private func rename() {
        outfit.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    private func toggleFavorite() {
        outfit.isFavorite.toggle()
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

    private func delete() {
        isDeleted = true
        modelContext.delete(outfit)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            isDeleted = false
            errorMessage = "This outfit couldn't be deleted. \(error.localizedDescription)"
        }
    }
}
