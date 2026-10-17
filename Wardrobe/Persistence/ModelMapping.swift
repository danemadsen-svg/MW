import Foundation
import WardrobeCore

// Snapshots of SwiftData models as plain WardrobeCore values. Engines take these value types so
// they can run off the main actor without touching model objects.

extension SchemaV1.Item {
    var outfitCandidate: OutfitCandidate {
        OutfitCandidate(
            id: id,
            category: category,
            clothingType: clothingType,
            colors: colors,
            seasons: seasons,
            formality: formality,
            usageCount: outfits.count
        )
    }

    var insightItem: InsightItem {
        InsightItem(
            id: id,
            category: category,
            clothingType: clothingType,
            colors: colors,
            createdAt: createdAt,
            outfitCount: outfits.count
        )
    }

    var sketchPiece: SketchLayout.Piece {
        SketchLayout.Piece(id: id, category: category, clothingType: clothingType)
    }

    /// The name to show: the user's name, or the category (and clothing type) when unnamed.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if category == .clothing, let clothingType { return clothingType.displayName }
        return category.singularName
    }
}

extension SchemaV1.Outfit {
    /// The outfit's name, or a description built from its items.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let core = orderedItems.filter { $0.category == .clothing }.prefix(2).map(\.displayName)
        return core.isEmpty ? "Outfit" : core.joined(separator: " + ")
    }
}
