import SwiftData
import SwiftUI
import WardrobeCore

/// Generate outfits from the closet (Chapter 2.5). Has no navigation stack of its own; presenters
/// showing it as a sheet wrap it in one.
struct OutfitGeneratorView: View {
    /// Every suggestion includes this item ("Build an outfit" from item detail).
    let anchorItemID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var season: Season? = Season.current()
    @State private var formality: Formality?
    @State private var maxAccessories = 3
    @State private var includeCologne = true

    @State private var isGenerating = false
    @State private var generation: Generation?
    /// Item ids of suggestions saved from the current results.
    @State private var savedOutfits: Set<[UUID]> = []
    @State private var errorMessage: String?

    init(anchorItemID: UUID? = nil) {
        self.anchorItemID = anchorItemID
    }

    /// A finished run and the request behind it; saved outfits take the request's season and formality.
    private struct Generation {
        let request: OutfitRequest
        let result: OutfitGenerationResult
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Your closet is empty", systemImage: "hanger")
                } description: {
                    Text("Add a few pieces, like a top, a bottom and shoes, to start generating outfits.")
                }
                .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                form
            }
        }
        .themedScreen()
        .alert("Couldn't save", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var form: some View {
        let itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return List {
            if let anchorItemID {
                anchorSection(anchorItemID, itemsByID: itemsByID)
            }
            filtersSection
            generateSection
            results(itemsByID: itemsByID)
        }
    }

    // MARK: - Sections

    private func anchorSection(_ anchorID: UUID, itemsByID: [UUID: Item]) -> some View {
        Section {
            if let anchor = itemsByID[anchorID] {
                HStack(spacing: Theme.Spacing.m) {
                    ItemThumbnail(data: anchor.thumbnailData, category: anchor.category, cornerRadius: Theme.Radius.s)
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Built around \(anchor.displayName)")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Every suggestion includes this piece.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("This item is no longer in your closet.")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var filtersSection: some View {
        Section("Filters") {
            Picker("Season", selection: $season) {
                Text("Any").tag(Season?.none)
                ForEach(Season.allCases) { season in
                    Label(season.displayName, systemImage: season.systemImage).tag(Season?.some(season))
                }
            }
            Picker("Formality", selection: $formality) {
                Text("Any").tag(Formality?.none)
                ForEach(Formality.allCases) { formality in
                    Text(formality.displayName).tag(Formality?.some(formality))
                }
            }
            Stepper(value: $maxAccessories, in: 0...5) {
                LabeledContent("Accessories", value: maxAccessories == 0 ? "None" : "Up to \(maxAccessories)")
            }
            Toggle("Include cologne", isOn: $includeCologne)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var generateSection: some View {
        Section {
            Button {
                Task { await generate() }
            } label: {
                Label(generation == nil ? "Generate" : "Generate again", systemImage: "sparkles")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.s)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Theme.Palette.background)
        }
    }

    @ViewBuilder
    private func results(itemsByID: [UUID: Item]) -> some View {
        if isGenerating {
            Section {
                HStack(spacing: Theme.Spacing.m) {
                    ProgressView()
                    Text("Finding combinations…")
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
            }
            .listRowBackground(Theme.Palette.surface)
        } else if let generation {
            let result = generation.result
            if let shortfall = result.shortfall {
                Section {
                    shortfallView(shortfall)
                }
                .listRowBackground(Theme.Palette.surface)
            }
            if !result.outfits.isEmpty {
                Section("Suggestions") {
                    ForEach(result.outfits, id: \.self) { outfit in
                        GeneratedOutfitCard(
                            outfit: outfit,
                            itemsByID: itemsByID,
                            isSaved: savedOutfits.contains(outfit.itemIDs),
                            onSave: { save(outfit, request: generation.request, itemsByID: itemsByID) }
                        )
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }
            if !result.incompleteItemIDs.isEmpty {
                Section {
                    Label(incompleteNote(count: result.incompleteItemIDs.count), systemImage: "exclamationmark.circle")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .listRowBackground(Theme.Palette.surface)
            }
        }
    }

    private func shortfallView(_ shortfall: OutfitGenerationResult.Shortfall) -> some View {
        let title: String
        let symbol: String
        let message: String
        switch shortfall {
        case .noBase:
            title = "Not enough to build on"
            symbol = "tshirt"
            message = "Add a top and a bottom, or a one-piece, to start building outfits."
        case .noHarmoniousCombination:
            title = "No colors work together yet"
            symbol = "paintpalette"
            message = "None of these pieces pass the color rules together. Add neutrals or pieces in more colors."
        case .anchorUnavailable:
            title = "This item needs details"
            symbol = "exclamationmark.circle"
            message = "Add its color and, for clothing, its type so outfits can be built around it."
        }
        return ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
        .foregroundStyle(Theme.Palette.textSecondary)
    }

    private func incompleteNote(count: Int) -> String {
        count == 1 ? "1 item needs details to be included" : "\(count) items need details to be included"
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Actions

    @MainActor
    private func generate() async {
        let candidates = items.map(\.outfitCandidate)
        let request = OutfitRequest(
            season: season,
            formality: formality,
            anchorItemID: anchorItemID,
            maxAccessories: maxAccessories,
            includeCologne: includeCologne,
            seed: UInt64.random(in: .min ... .max)
        )
        isGenerating = true
        let result = await Task.detached(priority: .userInitiated) {
            OutfitGenerator().generate(from: candidates, request: request)
        }.value
        generation = Generation(request: request, result: result)
        savedOutfits = []
        isGenerating = false
    }

    private func save(_ outfit: GeneratedOutfit, request: OutfitRequest, itemsByID: [UUID: Item]) {
        do {
            try modelContext.saveGeneratedOutfit(outfit, itemsByID: itemsByID, request: request)
            savedOutfits.insert(outfit.itemIDs)
        } catch {
            errorMessage = "This outfit couldn't be saved. \(error.localizedDescription)"
        }
    }
}

extension ModelContext {
    /// Inserts and saves a generated outfit with its items in generated order, its score and book
    /// palette, and the request's season and formality. Ids with no item (deleted since generating)
    /// are skipped. On failure nothing is left inserted.
    @discardableResult
    func saveGeneratedOutfit(_ generated: GeneratedOutfit, itemsByID: [UUID: Item], request: OutfitRequest) throws -> Outfit {
        let outfit = Outfit(score: generated.score, paletteCombinationID: generated.harmony.paletteCombinationID)
        insert(outfit)
        outfit.season = request.season
        outfit.formality = request.formality
        outfit.setItems(generated.itemIDs.compactMap { itemsByID[$0] })
        do {
            try save()
        } catch {
            delete(outfit)
            throw error
        }
        return outfit
    }
}

#Preview {
    NavigationStack { OutfitGeneratorView() }
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
