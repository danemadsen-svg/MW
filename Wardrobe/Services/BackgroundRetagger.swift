import Foundation
import SwiftData
import WardrobeCore

/// Re-runs the auto-tagger over items whose photos were last tagged by an older tagger version,
/// or never (Chapter 3.5). It only writes suggestions; the user accepts them in
/// `ReviewSuggestionsView`. Runs on its own model context, off the main actor.
@ModelActor
actor BackgroundRetagger {
    /// Items saved between progress saves, so a long run doesn't lose all work if interrupted.
    private static let saveInterval = 5

    func run(tagger: any AutoTagging) async {
        let current = AutoTaggerInfo.currentVersion
        // Filter on the version only: predicates over external-storage attributes (the photo)
        // aren't reliable, so photo-less items are skipped below.
        let descriptor = FetchDescriptor<Item>(
            predicate: #Predicate { $0.autoTagVersion < current },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let identifiers = try? modelContext.fetchIdentifiers(descriptor), !identifiers.isEmpty else { return }

        var unsaved = 0
        for identifier in identifiers {
            if Task.isCancelled { break }
            guard let item = modelContext.model(for: identifier) as? Item, item.autoTagVersion < current else { continue }
            guard let photo = item.photoData else {
                // Nothing to tag. The editor resets the version when a photo is added later.
                item.autoTagVersion = current
                unsaved += 1
                continue
            }

            let suggestion = await tagger.suggest(forPhoto: photo)
            // The item may have been deleted or re-tagged in the editor while we waited.
            guard !item.isDeleted, item.autoTagVersion < current else { continue }
            Self.record(suggestion, on: item, version: current)

            unsaved += 1
            if unsaved >= Self.saveInterval {
                try? modelContext.save()
                unsaved = 0
            }
        }
        if unsaved > 0 {
            try? modelContext.save()
        }
    }

    /// Stores the suggestion beside the user's own values and flags the item for review when the
    /// suggestion would change something. Never touches the user's fields.
    static func record(_ suggestion: TagSuggestion?, on item: Item, version: Int) {
        item.autoTagVersion = version
        item.suggestedCategoryRaw = suggestion?.category?.rawValue
        item.suggestedClothingTypeRaw = suggestion?.clothingType?.rawValue
        item.suggestedPrimaryColorRGB = suggestion?.primaryColor?.packed
        item.suggestedSecondaryColorRGB = suggestion?.secondaryColor?.packed
        item.suggestionConfidence = suggestion?.categoryConfidence
        if let suggestion, differs(suggestion, from: item) {
            item.needsReview = true
        }
    }

    /// Whether accepting the suggestion would change any of the item's fields.
    static func differs(_ suggestion: TagSuggestion, from item: Item) -> Bool {
        if let category = suggestion.category, category != item.category { return true }
        if suggestion.category == .clothing, let type = suggestion.clothingType, type != item.clothingType { return true }
        if let primary = suggestion.primaryColor, primary != item.primaryColor { return true }
        if let secondary = suggestion.secondaryColor, secondary != item.secondaryColor, secondary != item.primaryColor { return true }
        return false
    }
}
