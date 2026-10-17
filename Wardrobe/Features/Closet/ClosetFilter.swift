import Foundation
import WardrobeCore

/// What the closet grid shows: a search, a category or "needs details" scope, and a color.
struct ClosetFilter: Equatable {
    enum Scope: Hashable {
        case all
        case category(ItemCategory)
        case needsDetails
    }

    /// CIEDE2000 distance within which an item color counts as the chosen swatch.
    static let colorMatchThreshold = 12.0

    var searchText = ""
    var scope: Scope = .all
    var swatch: GarmentSwatch?

    var isActive: Bool {
        !searchTerms.isEmpty || scope != .all || swatch != nil
    }

    /// Whitespace-separated search words. An item matches when every word appears in its name or notes.
    var searchTerms: [String] {
        searchText.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    func matches(name: String, notes: String, category: ItemCategory, colors: [RGBColor], isIncomplete: Bool) -> Bool {
        matches(
            name: name,
            notes: notes,
            category: category,
            colors: colors,
            isIncomplete: isIncomplete,
            swatchLab: swatch.map { LabColor($0.color) }
        )
    }

    /// Case- and diacritic-insensitive.
    func matchesSearch(name: String, notes: String) -> Bool {
        searchTerms.allSatisfy { term in
            name.localizedStandardContains(term) || notes.localizedStandardContains(term)
        }
    }

    func matchesScope(category: ItemCategory, isIncomplete: Bool) -> Bool {
        switch scope {
        case .all: true
        case .category(let wanted): category == wanted
        case .needsDetails: isIncomplete
        }
    }

    /// Whether the primary or secondary color is within `colorMatchThreshold` of `swatch`.
    static func anyColor(in colors: [RGBColor], isNear swatch: RGBColor) -> Bool {
        anyColor(in: colors, isNear: LabColor(swatch))
    }

    /// Categories that occur in `categories`, in `ItemCategory.allCases` order, for the filter chips.
    static func categoriesPresent(in categories: [ItemCategory]) -> [ItemCategory] {
        let present = Set(categories)
        return ItemCategory.allCases.filter { present.contains($0) }
    }

    private static func anyColor(in colors: [RGBColor], isNear swatch: LabColor) -> Bool {
        colors.contains { LabColor($0).deltaE2000(swatch) <= colorMatchThreshold }
    }

    private func matches(
        name: String,
        notes: String,
        category: ItemCategory,
        colors: [RGBColor],
        isIncomplete: Bool,
        swatchLab: LabColor?
    ) -> Bool {
        guard matchesScope(category: category, isIncomplete: isIncomplete) else { return false }
        if let swatchLab, !Self.anyColor(in: colors, isNear: swatchLab) { return false }
        return matchesSearch(name: name, notes: notes)
    }
}

extension ClosetFilter {
    /// The items to show, in their original order. Searches the name as displayed, so unnamed
    /// items are found by their category ("watch").
    func apply(to items: [Item]) -> [Item] {
        guard isActive else { return items }
        let swatchLab = swatch.map { LabColor($0.color) }
        return items.filter { item in
            matches(
                name: item.displayName,
                notes: item.notes,
                category: item.category,
                colors: item.colors,
                isIncomplete: item.isIncomplete,
                swatchLab: swatchLab
            )
        }
    }
}
