import Foundation
import SwiftData
import WardrobeCore

typealias Item = SchemaV1.Item
typealias Outfit = SchemaV1.Outfit
typealias AvatarProfile = SchemaV1.AvatarProfile
typealias AvatarReference = SchemaV1.AvatarReference
typealias TryOnRender = SchemaV1.TryOnRender

/// First on-disk schema.
///
/// Until the first App Store release this schema may be edited in place (reinstall the app on
/// dev devices if the store fails to open). After release, freeze it: copy it to `SchemaV2`,
/// make changes there, and add a `MigrationStage` to `WardrobeMigrationPlan`.
///
/// Enums are stored as raw values so they work in `#Predicate`; the typed accessors in the
/// extensions below wrap them.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self, Outfit.self, AvatarProfile.self, AvatarReference.self, TryOnRender.self]
    }

    @Model
    final class Item {
        @Attribute(.unique) var id: UUID
        /// May be empty; the UI falls back to the category name.
        var name: String
        /// `ItemCategory.rawValue`.
        var categoryRaw: String
        /// `ClothingType.rawValue`. Only meaningful for `.clothing`; `nil` until chosen.
        var clothingTypeRaw: String?
        /// Dominant color as packed `0xRRGGBB`. `nil` until the item is tagged.
        var primaryColorRGB: Int?
        /// Secondary color for patterned items, packed `0xRRGGBB`.
        var secondaryColorRGB: Int?
        /// `SeasonSet.rawValue`. 0 means any season.
        var seasonsRaw: Int = 0
        /// `Formality.rawValue`. `nil` works with any formality.
        var formalityRaw: Int?
        var notes: String
        @Attribute(.externalStorage) var photoData: Data?
        @Attribute(.externalStorage) var thumbnailData: Data?
        var createdAt: Date
        var updatedAt: Date

        // MARK: Auto-tagging (Chapter 3)
        //
        // Suggestions never overwrite what the user chose. The tagger writes `suggested*`, sets
        // `needsReview`, and the confirm-or-correct UI copies accepted values into the real fields.

        /// Version of the auto-tagger that last looked at this item's photo. Background re-tagging
        /// revisits items whose version is older than `AutoTagger.currentVersion`.
        var autoTagVersion: Int = 0
        var suggestedCategoryRaw: String?
        var suggestedClothingTypeRaw: String?
        var suggestedPrimaryColorRGB: Int?
        var suggestedSecondaryColorRGB: Int?
        /// Classifier confidence for the suggested category, 0...1.
        var suggestionConfidence: Double?
        /// There are suggestions the user hasn't accepted or dismissed yet.
        var needsReview: Bool = false

        /// Inverse of `Outfit.items`.
        var outfits: [Outfit] = []

        init(
            id: UUID = UUID(),
            name: String = "",
            category: ItemCategory,
            clothingType: ClothingType? = nil,
            primaryColor: RGBColor? = nil,
            secondaryColor: RGBColor? = nil,
            seasons: SeasonSet = [],
            formality: Formality? = nil,
            notes: String = "",
            photoData: Data? = nil,
            thumbnailData: Data? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRaw = category.rawValue
            self.clothingTypeRaw = clothingType?.rawValue
            self.primaryColorRGB = primaryColor?.packed
            self.secondaryColorRGB = secondaryColor?.packed
            self.seasonsRaw = seasons.rawValue
            self.formalityRaw = formality?.rawValue
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
        /// Generator score when saved, 0...1. `nil` for hand-built outfits.
        var score: Double?
        /// The book combination the outfit's accents come from, if any.
        var paletteCombinationID: Int?
        /// `Season.rawValue` the outfit was generated for.
        var seasonRaw: String?
        /// `Formality.rawValue` the outfit was generated for.
        var formalityRaw: Int?
        /// Display order of `items` by id (SwiftData to-many relationships are unordered).
        var itemOrder: [UUID] = []

        /// Deleting an item removes it from its outfits; deleting an outfit leaves its items alone.
        /// Assign after inserting the outfit into a context: setting relationships on an
        /// uninserted model is unreliable on iOS 17.
        @Relationship(deleteRule: .nullify, inverse: \Item.outfits)
        var items: [Item] = []

        /// Try-on renders of this outfit; deleted with it.
        @Relationship(deleteRule: .cascade, inverse: \TryOnRender.outfit)
        var renders: [TryOnRender] = []

        init(
            id: UUID = UUID(),
            name: String = "",
            isFavorite: Bool = false,
            createdAt: Date = .now,
            score: Double? = nil,
            paletteCombinationID: Int? = nil
        ) {
            self.id = id
            self.name = name
            self.isFavorite = isFavorite
            self.createdAt = createdAt
            self.score = score
            self.paletteCombinationID = paletteCombinationID
        }
    }

    /// The user's likeness for try-on previews (Chapter 4). One profile is current at a time.
    @Model
    final class AvatarProfile {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var isCurrent: Bool
        /// The generated (or, on sketch-only devices, a cleaned-up reference) full-body image.
        @Attribute(.externalStorage) var avatarImageData: Data?
        /// Seed used to generate `avatarImageData`, so regenerating with tweaks stays consistent.
        var seed: Int
        /// Identifier of the model that produced the avatar, e.g. "sd21-base-palettized".
        var modelIdentifier: String?
        /// Optional user-written description added to prompts ("short dark hair, glasses").
        var appearanceNotes: String

        @Relationship(deleteRule: .cascade, inverse: \AvatarReference.profile)
        var references: [AvatarReference] = []

        init(id: UUID = UUID(), createdAt: Date = .now, isCurrent: Bool = true, seed: Int, appearanceNotes: String = "") {
            self.id = id
            self.createdAt = createdAt
            self.isCurrent = isCurrent
            self.seed = seed
            self.appearanceNotes = appearanceNotes
        }
    }

    /// One reference photo of the user (three to five per profile).
    @Model
    final class AvatarReference {
        @Attribute(.unique) var id: UUID
        /// `AvatarPose.rawValue`: which shot this is (front, side, full body...).
        var poseRaw: String
        @Attribute(.externalStorage) var imageData: Data
        var createdAt: Date
        var profile: AvatarProfile?

        init(id: UUID = UUID(), poseRaw: String, imageData: Data, createdAt: Date = .now) {
            self.id = id
            self.poseRaw = poseRaw
            self.imageData = imageData
            self.createdAt = createdAt
        }
    }

    /// A rendered preview of an outfit (Chapter 5).
    @Model
    final class TryOnRender {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        /// `RenderKind.rawValue`: "sketch" or "diffusion".
        var kindRaw: String
        @Attribute(.externalStorage) var imageData: Data
        var seed: Int?
        var modelIdentifier: String?
        var outfit: Outfit?

        init(id: UUID = UUID(), createdAt: Date = .now, kindRaw: String, imageData: Data, seed: Int? = nil, modelIdentifier: String? = nil) {
            self.id = id
            self.createdAt = createdAt
            self.kindRaw = kindRaw
            self.imageData = imageData
            self.seed = seed
            self.modelIdentifier = modelIdentifier
        }
    }
}

// MARK: - Typed accessors

extension SchemaV1.Item {
    var category: ItemCategory {
        get { ItemCategory(storedValue: categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var clothingType: ClothingType? {
        get { clothingTypeRaw.flatMap(ClothingType.init(rawValue:)) }
        set { clothingTypeRaw = newValue?.rawValue }
    }

    var primaryColor: RGBColor? {
        get { primaryColorRGB.flatMap(RGBColor.init(packed:)) }
        set { primaryColorRGB = newValue?.packed }
    }

    var secondaryColor: RGBColor? {
        get { secondaryColorRGB.flatMap(RGBColor.init(packed:)) }
        set { secondaryColorRGB = newValue?.packed }
    }

    var seasons: SeasonSet {
        get { SeasonSet(rawValue: seasonsRaw) }
        set { seasonsRaw = newValue.rawValue }
    }

    var formality: Formality? {
        get { formalityRaw.flatMap(Formality.init(rawValue:)) }
        set { formalityRaw = newValue?.rawValue }
    }

    var suggestedCategory: ItemCategory? {
        suggestedCategoryRaw.map(ItemCategory.init(storedValue:))
    }

    var suggestedClothingType: ClothingType? {
        suggestedClothingTypeRaw.flatMap(ClothingType.init(rawValue:))
    }

    var suggestedPrimaryColor: RGBColor? {
        suggestedPrimaryColorRGB.flatMap(RGBColor.init(packed:))
    }

    var suggestedSecondaryColor: RGBColor? {
        suggestedSecondaryColorRGB.flatMap(RGBColor.init(packed:))
    }

    /// The item's colors for outfit logic: primary, then secondary. Empty when untagged.
    var colors: [RGBColor] {
        [primaryColor, secondaryColor].compactMap { $0 }
    }

    /// Missing what the outfit generator needs: a color (unless the category ignores color) or,
    /// for clothing, a clothing type.
    var isIncomplete: Bool {
        if category == .clothing && clothingType == nil { return true }
        return colors.isEmpty && !OutfitGenerator.colorNeutralCategories.contains(category)
    }

    /// Marks the item as edited now. Call after any user-visible change.
    func touch() {
        updatedAt = .now
    }
}

extension SchemaV1.Outfit {
    /// Items in display order. Items missing from `itemOrder` (shouldn't happen) go last.
    var orderedItems: [Item] {
        let position = Dictionary(itemOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return items.sorted { (position[$0.id] ?? .max, $0.createdAt) < (position[$1.id] ?? .max, $1.createdAt) }
    }

    /// Replaces the outfit's items, keeping their order. The outfit must already be inserted.
    func setItems(_ newItems: [Item]) {
        items = newItems
        itemOrder = newItems.map(\.id)
    }

    var season: Season? {
        get { seasonRaw.flatMap(Season.init(rawValue:)) }
        set { seasonRaw = newValue?.rawValue }
    }

    var formality: Formality? {
        get { formalityRaw.flatMap(Formality.init(rawValue:)) }
        set { formalityRaw = newValue?.rawValue }
    }
}

enum RenderKind: String, Sendable {
    /// Flat-lay lookbook composed from item photos; works on every device.
    case sketch
    /// Generated on device with a diffusion model.
    case diffusion
}

enum AvatarPose: String, CaseIterable, Sendable, Identifiable {
    case front
    case leftProfile
    case rightProfile
    case fullBody
    case smile

    var id: String { rawValue }
}
