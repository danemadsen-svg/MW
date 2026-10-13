import Foundation
import SwiftData
import WardrobeCore

typealias Item = SchemaV1.Item
typealias Outfit = SchemaV1.Outfit

/// First on-disk schema.
///
/// Until the first App Store release this schema may be edited in place (reinstall the app on
/// dev devices if the store fails to open). After release, freeze it: copy it to `SchemaV2`,
/// make changes there, and add a `MigrationStage` to `WardrobeMigrationPlan`.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self, Outfit.self]
    }

    @Model
    final class Item {
        @Attribute(.unique) var id: UUID
        /// May be empty; the UI falls back to the category name.
        var name: String
        /// `ItemCategory.rawValue`. Stored as a string so it can be used in `#Predicate`.
        var categoryRaw: String
        /// Dominant color as packed `0xRRGGBB`. `nil` until the item is tagged.
        var primaryColorRGB: Int?
        /// Secondary color for patterned items, packed `0xRRGGBB`.
        var secondaryColorRGB: Int?
        var notes: String
        @Attribute(.externalStorage) var photoData: Data?
        @Attribute(.externalStorage) var thumbnailData: Data?
        var createdAt: Date
        var updatedAt: Date

        /// Inverse of `Outfit.items`.
        var outfits: [Outfit] = []

        init(
            id: UUID = UUID(),
            name: String = "",
            category: ItemCategory,
            primaryColor: RGBColor? = nil,
            secondaryColor: RGBColor? = nil,
            notes: String = "",
            photoData: Data? = nil,
            thumbnailData: Data? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRaw = category.rawValue
            self.primaryColorRGB = primaryColor?.packed
            self.secondaryColorRGB = secondaryColor?.packed
            self.notes = notes
            self.photoData = photoData
            self.thumbnailData = thumbnailData
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    @Model
    final class Outfit {
        @Attribute(.unique) var id: UUID
        var name: String
        var isFavorite: Bool
        var createdAt: Date

        /// Deleting an item removes it from its outfits; deleting an outfit leaves its items alone.
        /// Assign after inserting the outfit into a context: setting relationships on an
        /// uninserted model is unreliable on iOS 17.
        @Relationship(deleteRule: .nullify, inverse: \Item.outfits)
        var items: [Item] = []

        init(
            id: UUID = UUID(),
            name: String = "",
            isFavorite: Bool = false,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.isFavorite = isFavorite
            self.createdAt = createdAt
        }
    }
}

extension SchemaV1.Item {
    var category: ItemCategory {
        get { ItemCategory(storedValue: categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var primaryColor: RGBColor? {
        get { primaryColorRGB.flatMap(RGBColor.init(packed:)) }
        set { primaryColorRGB = newValue?.packed }
    }

    var secondaryColor: RGBColor? {
        get { secondaryColorRGB.flatMap(RGBColor.init(packed:)) }
        set { secondaryColorRGB = newValue?.packed }
    }
}
