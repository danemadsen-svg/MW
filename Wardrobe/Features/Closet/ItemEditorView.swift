import PhotosUI
import SwiftData
import SwiftUI
import WardrobeCore

/// Adds a new item or edits an existing one. Present it in a `NavigationStack`.
///
/// Edits go into an `ItemDraft` and reach the model only on Save, so Cancel needs no undo.
/// A new photo is processed off the main actor and then shown to the auto-tagger, whose
/// suggestion appears as a banner the user can apply or dismiss.
struct ItemEditorView: View {
    private enum Tagging: Equatable {
        case idle
        case running
        /// The tagger's raw answer for the current photo.
        case finished(TagSuggestion?)
    }

    private struct EditorPhoto {
        let fullData: Data
        let thumbnailData: Data
    }

    private struct PhotoRequest {
        let id = UUID()
        let photo: PendingItemPhoto
    }

    private let item: Item?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.autoTagger) private var autoTagger

    @State private var draft: ItemDraft
    @State private var original: ItemDraft
    @State private var photo: EditorPhoto? = nil
    @State private var photoChanged = false
    /// The photo being loaded and processed; `nil` when idle.
    @State private var photoRequest: PhotoRequest? = nil
    @State private var photoSource: ItemPhotoSource? = nil
    @State private var photoError: String? = nil
    /// Identifies the photo the tagger is looking at; changing it cancels the previous run.
    @State private var taggingID: UUID? = nil
    @State private var tagging: Tagging = .idle
    @State private var suggestion: TagSuggestion? = nil
    @State private var isSuggestionDismissed = false
    @State private var isConfirmingDiscard = false
    @State private var saveError: String? = nil

    /// Adds a new item, starting with `newItemPhoto` when there is one.
    init(newItemPhoto: PendingItemPhoto? = nil) {
        item = nil
        _draft = State(initialValue: ItemDraft())
        _original = State(initialValue: ItemDraft())
        _photoRequest = State(initialValue: newItemPhoto.map { PhotoRequest(photo: $0) })
    }

    /// Edits `item`, showing any suggestions waiting for review.
    init(item: Item) {
        self.item = item
        let draft = ItemDraft(item: item)
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
        _photo = State(initialValue: item.photoData.map { EditorPhoto(fullData: $0, thumbnailData: item.thumbnailData ?? $0) })
        _suggestion = State(initialValue: ItemDraft.pendingSuggestion(on: item))
    }

    private var isNew: Bool { item == nil }
    private var isProcessingPhoto: Bool { photoRequest != nil }
    private var hasChanges: Bool { draft != original || photoChanged }
    private var canSave: Bool { draft.category != nil && !isProcessingPhoto }

    var body: some View {
        Form {
            photoSection

            if let suggestion, !isSuggestionDismissed, ItemDraft.summary(of: suggestion) != nil {
                Section {
                    SuggestionBanner(
                        suggestion: suggestion,
                        isApplied: draft.reflects(suggestion),
                        onApply: { draft.apply(suggestion) },
                        onDismiss: { isSuggestionDismissed = true }
                    )
                }
                .listRowBackground(Theme.Palette.surfaceRaised)
            }

            Section("Name") {
                TextField("Name", text: $draft.name, prompt: Text("Optional, like “Oxford shirt”"))
                    .textInputAutocapitalization(.sentences)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                CategoryPickerView(category: $draft.category, clothingType: $draft.clothingType)
            } header: {
                Text("Category")
            } footer: {
                if draft.category == nil {
                    Text("Choose a category to save this item.")
                }
            }
            .listRowBackground(Theme.Palette.surface)

            colorSection
            seasonSection

            Section {
                Picker("Formality", selection: $draft.formality) {
                    Text("Any").tag(Formality?.none)
                    ForEach(Formality.allCases) { formality in
                        Text(formality.displayName).tag(Optional(formality))
                    }
                }
                .foregroundStyle(Theme.Palette.textPrimary)
            } footer: {
                Text("Leave it at Any for pieces that dress up or down.")
            }
            .listRowBackground(Theme.Palette.surface)

            Section("Notes") {
                TextField("Notes", text: $draft.notes, prompt: Text("Fit, fabric, care…"), axis: .vertical)
                    .lineLimit(3...8)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .themedScreen()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? "New Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") { save() }
                    .disabled(!canSave)
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .itemPhotoPicker($photoSource) { picked in
            photoError = nil
            photoRequest = PhotoRequest(photo: picked)
        }
        .task(id: photoRequest?.id) { await processRequestedPhoto() }
        .task(id: taggingID) { await runTagger() }
        .confirmationDialog(
            isNew ? "Discard this item?" : "Discard your changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .alert("Couldn't Save", isPresented: isShowingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            photoPreview
                .listRowInsets(EdgeInsets(top: Theme.Spacing.m, leading: Theme.Spacing.m, bottom: Theme.Spacing.m, trailing: Theme.Spacing.m))

            if let photoError {
                Label(photoError, systemImage: "exclamationmark.triangle")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.destructive)
            }

            if tagging == .running {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView()
                    Text("Looking for details in your photo…")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }

            Menu {
                if ItemPhotoSource.isCameraAvailable {
                    Button("Take Photo", systemImage: "camera") { photoSource = .camera }
                }
                Button("Choose from Library", systemImage: "photo.on.rectangle") { photoSource = .library }
                if photo != nil {
                    Button("Remove Photo", systemImage: "trash", role: .destructive) { removePhoto() }
                }
            } label: {
                Label(photo == nil ? "Add Photo" : "Replace Photo", systemImage: "photo")
            }
            .disabled(isProcessingPhoto)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var photoPreview: some View {
        Theme.Palette.surfaceRaised
            .frame(height: 240)
            .overlay {
                if let photo {
                    ItemThumbnail(data: photo.fullData, category: draft.category ?? .other, cornerRadius: 0)
                } else {
                    VStack(spacing: Theme.Spacing.s) {
                        Image(systemName: (draft.category ?? .other).systemImage)
                            .font(.largeTitle)
                        Text("No photo")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .overlay {
                if isProcessingPhoto {
                    ProgressView("Preparing photo…")
                        .padding(Theme.Spacing.l)
                        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(photoAccessibilityLabel)
    }

    private var photoAccessibilityLabel: String {
        if isProcessingPhoto { return "Preparing photo" }
        return photo == nil ? "No photo" : "Item photo"
    }

    private var colorSection: some View {
        Section {
            NavigationLink {
                ColorTagPicker(
                    primary: $draft.primaryColor,
                    secondary: $draft.secondaryColor,
                    photoData: photo?.fullData,
                    category: draft.category ?? .other
                )
            } label: {
                colorSummary
            }
        } header: {
            Text("Colors")
        } footer: {
            if let category = draft.category, !category.usesColor {
                Text("Optional for \(category.displayName.lowercased()). Outfits treat them as going with everything.")
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var colorSummary: some View {
        let colors = [draft.primaryColor, draft.secondaryColor].compactMap { $0 }
        return HStack(spacing: Theme.Spacing.s) {
            if colors.isEmpty {
                Text("Not set")
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    ColorSwatchView(color: color)
                    Text(ColorTagPicker.name(for: color))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
        }
    }

    private var seasonSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(Season.allCases) { season in
                        ChipButton(
                            title: season.displayName,
                            systemImage: season.systemImage,
                            isSelected: draft.seasons.contains(SeasonSet(season))
                        ) {
                            draft.seasons.formSymmetricDifference(SeasonSet(season))
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        } header: {
            Text("Seasons")
        } footer: {
            Text(draft.seasons.isEmpty ? "None selected means any season." : draft.seasons.summary)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var isShowingSaveError: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    // MARK: - Photo and tagging

    @MainActor
    private func processRequestedPhoto() async {
        guard let request = photoRequest else { return }
        do {
            let processed = try await Self.process(request.photo)
            guard !Task.isCancelled, photoRequest?.id == request.id else { return }
            photo = EditorPhoto(fullData: processed.fullData, thumbnailData: processed.thumbnailData)
            photoChanged = true
            photoError = nil
            startTagging()
        } catch {
            guard !Task.isCancelled, photoRequest?.id == request.id else { return }
            photoError = (error as? LocalizedError)?.errorDescription
                ?? "This photo couldn't be loaded. Try a different one."
        }
        photoRequest = nil
    }

    /// Loads and re-encodes a picked photo (downscaled, metadata stripped) off the main actor.
    private static func process(_ photo: PendingItemPhoto) async throws -> ProcessedPhoto {
        switch photo {
        case .captured(let image):
            return try await Task.detached(priority: .userInitiated) {
                try PhotoProcessor.process(image)
            }.value
        case .library(let pickerItem):
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                throw PhotoProcessingError.unreadableImage
            }
            return try await Task.detached(priority: .userInitiated) {
                try PhotoProcessor.process(data)
            }.value
        }
    }

    @MainActor
    private func startTagging() {
        suggestion = nil
        isSuggestionDismissed = false
        tagging = .running
        taggingID = UUID()
    }

    @MainActor
    private func runTagger() async {
        guard let id = taggingID, let data = photo?.fullData else { return }
        let result = await autoTagger.suggest(forPhoto: data)
        guard !Task.isCancelled, taggingID == id else { return }
        tagging = .finished(result)

        guard let result, ItemDraft.summary(of: result) != nil else { return }
        suggestion = result
        isSuggestionDismissed = false
        if isNew, result.categoryConfidence >= AutoTaggerInfo.confidentThreshold {
            draft.prefillEmptyFields(from: result)
        }
    }

    @MainActor
    private func removePhoto() {
        photo = nil
        photoChanged = true
        photoRequest = nil
        photoError = nil
        taggingID = nil
        tagging = .idle
        suggestion = nil
    }

    // MARK: - Saving

    @MainActor
    private func cancel() {
        if hasChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    @MainActor
    private func save() {
        guard let category = draft.category else { return }
        let target = item ?? Item(category: category)
        if item == nil {
            modelContext.insert(target)
        }
        draft.write(to: target)
        if photoChanged {
            target.photoData = photo?.fullData
            target.thumbnailData = photo?.thumbnailData
        }

        switch tagging {
        case .finished(let result):
            ItemDraft.recordSuggestion(result, on: target)
        case .running:
            // Saved before the tagger finished: let background re-tagging look at this photo.
            ItemDraft.clearSuggestions(on: target)
        case .idle:
            if photoChanged { ItemDraft.clearSuggestions(on: target) }
        }
        // Any suggestions were in front of the user in this editor.
        target.needsReview = false
        if item != nil { target.touch() }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "Your closet couldn't be updated. Make sure your iPhone has free storage, then try again."
        }
    }
}

// MARK: - Draft

/// The editor's working copy of an item's attributes.
struct ItemDraft: Equatable {
    var name = ""
    /// `nil` for a new item until the user (or a confident suggestion) picks one.
    var category: ItemCategory?
    /// Kept while switching categories, but only saved for clothing.
    var clothingType: ClothingType?
    var primaryColor: RGBColor?
    var secondaryColor: RGBColor?
    /// Empty means any season.
    var seasons: SeasonSet = []
    var formality: Formality?
    var notes = ""

    init() {}

    init(item: Item) {
        name = item.name
        category = item.category
        clothingType = item.clothingType
        primaryColor = item.primaryColor
        secondaryColor = item.secondaryColor
        seasons = item.seasons
        formality = item.formality
        notes = item.notes
    }

    /// Fills only the fields that are still empty.
    mutating func prefillEmptyFields(from suggestion: TagSuggestion) {
        if category == nil, let suggested = suggestion.category {
            category = suggested
        }
        if category == .clothing, suggestion.category == .clothing, clothingType == nil {
            clothingType = suggestion.clothingType
        }
        if primaryColor == nil, secondaryColor == nil, let suggestedPrimary = suggestion.primaryColor {
            primaryColor = suggestedPrimary
            secondaryColor = Self.secondary(suggestion.secondaryColor, distinctFrom: suggestedPrimary)
        }
    }

    /// Takes everything the suggestion has, replacing current values.
    mutating func apply(_ suggestion: TagSuggestion) {
        if let suggested = suggestion.category {
            category = suggested
            if suggested == .clothing, let type = suggestion.clothingType {
                clothingType = type
            }
        }
        if let suggestedPrimary = suggestion.primaryColor {
            primaryColor = suggestedPrimary
            secondaryColor = Self.secondary(suggestion.secondaryColor, distinctFrom: suggestedPrimary)
        }
    }

    /// Whether applying `suggestion` would change nothing.
    func reflects(_ suggestion: TagSuggestion) -> Bool {
        if let suggested = suggestion.category {
            guard suggested == category else { return false }
            if suggested == .clothing, let type = suggestion.clothingType, type != clothingType {
                return false
            }
        }
        if let suggestedPrimary = suggestion.primaryColor {
            guard suggestedPrimary == primaryColor,
                  Self.secondary(suggestion.secondaryColor, distinctFrom: suggestedPrimary) == secondaryColor
            else { return false }
        }
        return true
    }

    /// Writes the draft's attributes. Trims text, drops the clothing type for other categories,
    /// and never leaves a secondary color without a primary one.
    func write(to item: Item) {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category {
            item.category = category
        }
        item.clothingType = item.category == .clothing ? clothingType : nil
        if let primaryColor {
            item.primaryColor = primaryColor
            item.secondaryColor = Self.secondary(secondaryColor, distinctFrom: primaryColor)
        } else {
            item.primaryColor = secondaryColor
            item.secondaryColor = nil
        }
        item.seasons = seasons
        item.formality = formality
        item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func secondary(_ secondary: RGBColor?, distinctFrom primary: RGBColor) -> RGBColor? {
        secondary == primary ? nil : secondary
    }
}

extension ItemDraft {
    /// "Bottom · Navy", "Watch", or "Navy and Cream". `nil` when there's nothing to show.
    static func summary(of suggestion: TagSuggestion) -> String? {
        var parts: [String] = []
        if let category = suggestion.category {
            if category == .clothing {
                parts.append(suggestion.clothingType?.displayName ?? category.displayName)
            } else {
                parts.append(category.singularName)
            }
        }
        var colorNames: [String] = []
        for color in [suggestion.primaryColor, suggestion.secondaryColor].compactMap({ $0 }) {
            let name = ColorTagPicker.name(for: color)
            if !colorNames.contains(name) { colorNames.append(name) }
        }
        if !colorNames.isEmpty {
            parts.append(colorNames.joined(separator: " and "))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Suggestions the background re-tagger left for review, if any.
    static func pendingSuggestion(on item: Item) -> TagSuggestion? {
        guard item.needsReview else { return nil }
        let suggestion = TagSuggestion(
            category: item.suggestedCategory,
            clothingType: item.suggestedClothingType,
            categoryConfidence: item.suggestionConfidence ?? 0,
            primaryColor: item.suggestedPrimaryColor,
            secondaryColor: item.suggestedSecondaryColor
        )
        return suggestion.isEmpty ? nil : suggestion
    }

    /// Records the tagger's raw answer for the item's current photo. Suggestions are kept apart
    /// from what the user chose.
    static func recordSuggestion(_ suggestion: TagSuggestion?, on item: Item) {
        item.autoTagVersion = AutoTaggerInfo.currentVersion
        item.suggestedCategoryRaw = suggestion?.category?.rawValue
        item.suggestedClothingTypeRaw = suggestion?.clothingType?.rawValue
        item.suggestedPrimaryColorRGB = suggestion?.primaryColor?.packed
        item.suggestedSecondaryColorRGB = suggestion?.secondaryColor?.packed
        item.suggestionConfidence = suggestion?.categoryConfidence
    }

    /// Forgets suggestions made for a photo the item no longer has, so background re-tagging
    /// revisits it.
    static func clearSuggestions(on item: Item) {
        item.autoTagVersion = 0
        item.suggestedCategoryRaw = nil
        item.suggestedClothingTypeRaw = nil
        item.suggestedPrimaryColorRGB = nil
        item.suggestedSecondaryColorRGB = nil
        item.suggestionConfidence = nil
    }
}

// MARK: - Suggestion banner

private struct SuggestionBanner: View {
    let suggestion: TagSuggestion
    /// The draft already matches the suggestion (prefilled or applied).
    let isApplied: Bool
    let onApply: () -> Void
    let onDismiss: () -> Void

    private var title: String {
        let summary = ItemDraft.summary(of: suggestion) ?? ""
        if isApplied { return "From your photo: \(summary)" }
        let isConfident = suggestion.category == nil
            || suggestion.categoryConfidence >= AutoTaggerInfo.confidentThreshold
        return isConfident ? "Looks like: \(summary)" : "Might be: \(summary)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.Palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(isApplied ? "Check it and change anything that's off." : "Suggested from your photo.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if !isApplied {
                    Button("Apply", action: onApply)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderless)
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(Theme.Spacing.xs)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss Suggestion")
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
