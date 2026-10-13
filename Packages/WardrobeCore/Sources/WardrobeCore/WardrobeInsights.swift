import Foundation

/// The insights screen's view of an item.
public struct InsightItem: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var category: ItemCategory
    public var clothingType: ClothingType?
    /// Primary color first. Empty when untagged.
    public var colors: [RGBColor]
    public var createdAt: Date
    /// Number of saved outfits that include the item.
    public var outfitCount: Int

    public init(id: UUID, category: ItemCategory, clothingType: ClothingType? = nil, colors: [RGBColor], createdAt: Date, outfitCount: Int) {
        self.id = id
        self.category = category
        self.clothingType = clothingType
        self.colors = colors
        self.createdAt = createdAt
        self.outfitCount = outfitCount
    }
}

public struct WardrobeInsights: Hashable, Sendable {
    public enum Gap: Hashable, Sendable {
        case noTops
        case noBottoms
        case noShoes
        case noOuterwear
        /// Many more tops than bottoms (or the reverse), which limits combinations.
        case unbalanced(tops: Int, bottoms: Int)
        /// No accent colors at all: everything is neutral.
        case onlyNeutrals
    }

    /// In no saved outfit and older than the grace period, oldest first.
    public let unusedItemIDs: [UUID]
    /// Used far more than the average item, most used first.
    public let overusedItemIDs: [UUID]
    public let gaps: [Gap]
    /// Missing a color tag or (for clothing) a clothing type, so the generator skips them.
    public let incompleteItemIDs: [UUID]
    /// Dictionary colors that would pair with the most of the wardrobe's existing accents.
    public let accentSuggestions: [DictionaryColor]
}

public struct InsightsAnalyzer: Sendable {
    /// New items aren't flagged as unused until they've had time to be worn.
    public var unusedGracePeriod: TimeInterval = 14 * 24 * 60 * 60
    /// An item is over-used when it's in at least this many outfits...
    public var overuseMinimum = 4
    /// ...and at least this multiple of the average outfit count.
    public var overuseFactor = 2.0
    public var suggestionCount = 3

    public let dictionary: ColorDictionary
    public let policy: HarmonyPolicy

    public init(dictionary: ColorDictionary = .standard, policy: HarmonyPolicy = .standard) {
        self.dictionary = dictionary
        self.policy = policy
    }

    public func analyze(_ items: [InsightItem], now: Date) -> WardrobeInsights {
        let harmony = ColorHarmony(dictionary: dictionary, policy: policy)

        let unused = items
            .filter { $0.outfitCount == 0 && now.timeIntervalSince($0.createdAt) >= unusedGracePeriod }
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.id)

        let average = items.isEmpty ? 0 : Double(items.map(\.outfitCount).reduce(0, +)) / Double(items.count)
        let overused = items
            .filter { $0.outfitCount >= overuseMinimum && Double($0.outfitCount) >= overuseFactor * average }
            .sorted { $0.outfitCount > $1.outfitCount }
            .map(\.id)

        let incomplete = items.filter { item in
            (item.category == .clothing && item.clothingType == nil)
                || (item.colors.isEmpty && !OutfitGenerator.colorNeutralCategories.contains(item.category))
        }.map(\.id)

        let accents = harmony.accentClusters(
            items.filter { !OutfitGenerator.colorNeutralCategories.contains($0.category) }.flatMap(\.colors)
        )

        return WardrobeInsights(
            unusedItemIDs: unused,
            overusedItemIDs: overused,
            gaps: gaps(in: items, hasAccents: !accents.isEmpty),
            incompleteItemIDs: incomplete,
            accentSuggestions: suggestions(for: accents, harmony: harmony)
        )
    }

    private func gaps(in items: [InsightItem], hasAccents: Bool) -> [WardrobeInsights.Gap] {
        guard !items.isEmpty else { return [] }
        func count(_ type: ClothingType) -> Int {
            items.filter { $0.category == .clothing && $0.clothingType == type }.count
        }
        let tops = count(.top), bottoms = count(.bottom), onePieces = count(.onePiece)

        var gaps: [WardrobeInsights.Gap] = []
        if tops == 0 && onePieces == 0 { gaps.append(.noTops) }
        if bottoms == 0 && onePieces == 0 { gaps.append(.noBottoms) }
        if !items.contains(where: { $0.category == .shoes }) { gaps.append(.noShoes) }
        if count(.outerwear) == 0 { gaps.append(.noOuterwear) }
        if tops > 0 && bottoms > 0 && (tops >= 4 * bottoms || bottoms >= 4 * tops) && tops + bottoms >= 5 {
            gaps.append(.unbalanced(tops: tops, bottoms: bottoms))
        }
        let hasColoredItems = items.contains { !$0.colors.isEmpty && !OutfitGenerator.colorNeutralCategories.contains($0.category) }
        if hasColoredItems && !hasAccents { gaps.append(.onlyNeutrals) }
        return gaps
    }

    /// Accent colors that the book pairs with as many existing accents as possible. With no
    /// accents yet, the dictionary's most versatile colors (those in the most combinations).
    private func suggestions(for accents: [RGBColor], harmony: ColorHarmony) -> [DictionaryColor] {
        let candidates = dictionary.colors.filter { color in
            harmony.role(of: color.rgb) == .accent
                && !accents.contains { harmony.lab($0).deltaE2000(color.lab) <= policy.tonalThreshold }
        }
        let scored = candidates.map { color -> (color: DictionaryColor, pairs: Int, versatility: Int) in
            let pairs = accents.filter { harmony.sanction(color.rgb, $0) != nil }.count
            return (color, pairs, dictionary.combinationIDs(containing: color.id).count)
        }
        return scored
            .filter { accents.isEmpty || $0.pairs > 0 }
            .sorted { lhs, rhs in
                if lhs.pairs != rhs.pairs { return lhs.pairs > rhs.pairs }
                if lhs.versatility != rhs.versatility { return lhs.versatility > rhs.versatility }
                return lhs.color.id < rhs.color.id
            }
            .prefix(suggestionCount)
            .map(\.color)
    }
}
