import Foundation

/// The generator's view of a cataloged item: only what outfit building needs.
public struct OutfitCandidate: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var category: ItemCategory
    /// Required for `.clothing`; ignored otherwise.
    public var clothingType: ClothingType?
    /// Primary color first, then the secondary color for patterns. Empty when untagged.
    public var colors: [RGBColor]
    /// Empty means any season.
    public var seasons: SeasonSet
    /// `nil` works with any formality.
    public var formality: Formality?
    /// How many saved outfits already use the item; less-used items get a variety boost.
    public var usageCount: Int

    public init(
        id: UUID,
        category: ItemCategory,
        clothingType: ClothingType? = nil,
        colors: [RGBColor],
        seasons: SeasonSet = [],
        formality: Formality? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.category = category
        self.clothingType = clothingType
        self.colors = colors
        self.seasons = seasons
        self.formality = formality
        self.usageCount = usageCount
    }
}

public struct OutfitRequest: Hashable, Sendable {
    /// Only use items suited to this season. `nil` ignores seasons.
    public var season: Season?
    /// Only use items within one step of this formality. `nil` ignores formality.
    public var formality: Formality?
    /// Maximum number of outfits to return.
    public var count: Int
    /// Every outfit must include this item. It bypasses the season and formality filters.
    public var anchorItemID: UUID?
    public var excludedItemIDs: Set<UUID>
    /// Maximum accessories (hats, scarves, gloves, belts, bags, watches, rings, other) per outfit.
    public var maxAccessories: Int
    public var includeCologne: Bool
    /// Different seeds give different suggestions; the same seed gives the same suggestions.
    public var seed: UInt64

    public init(
        season: Season? = nil,
        formality: Formality? = nil,
        count: Int = 10,
        anchorItemID: UUID? = nil,
        excludedItemIDs: Set<UUID> = [],
        maxAccessories: Int = 3,
        includeCologne: Bool = true,
        seed: UInt64 = 0
    ) {
        self.season = season
        self.formality = formality
        self.count = count
        self.anchorItemID = anchorItemID
        self.excludedItemIDs = excludedItemIDs
        self.maxAccessories = maxAccessories
        self.includeCologne = includeCologne
        self.seed = seed
    }
}

public struct GeneratedOutfit: Hashable, Sendable {
    /// Clothing first (one-piece or top, bottom, layer, outerwear), then shoes, accessories, cologne.
    public let itemIDs: [UUID]
    /// 0...1: mostly color harmony, plus a boost for rarely used items.
    public let score: Double
    public let harmony: HarmonyResult
}

public struct OutfitGenerationResult: Hashable, Sendable {
    public enum Shortfall: Hashable, Sendable {
        /// No usable top-and-bottom pair or one-piece for the request.
        case noBase
        /// Bases exist, but no combination passes the color rules.
        case noHarmoniousCombination
        /// The anchor item is excluded, missing, or not usable (e.g. untagged).
        case anchorUnavailable
    }

    public let outfits: [GeneratedOutfit]
    /// Items left out because they lack a color tag or, for clothing, a clothing type.
    public let incompleteItemIDs: [UUID]
    /// Why fewer outfits than requested came back, when the reason is structural.
    public let shortfall: Shortfall?
}

/// Builds outfits from a wardrobe using the color dictionary plus wearability rules:
/// a one-piece or a top with a bottom, shoes when any are available, at most one layer and one
/// outerwear piece, per-category accessory limits (one hat max), and season and formality filters.
public struct OutfitGenerator: Sendable {
    /// Per-outfit limits for accessory categories.
    public static let accessoryLimits: [ItemCategory: Int] = [
        .hats: 1, .scarves: 1, .gloves: 1, .belts: 1, .bags: 1, .watches: 1, .rings: 2, .other: 1,
    ]
    /// Categories whose colors don't take part in harmony: metals go with anything, cologne is invisible.
    public static let colorNeutralCategories: Set<ItemCategory> = [.rings, .watches, .cologne]
    /// Seasons assumed for items that don't specify any.
    public static func defaultSeasons(for category: ItemCategory) -> SeasonSet {
        switch category {
        case .gloves: [.autumn, .winter]
        case .scarves: [.spring, .autumn, .winter]
        default: []
        }
    }

    public let dictionary: ColorDictionary
    public let policy: HarmonyPolicy
    /// Upper bound on complete outfits assembled before ranking, keeping generation fast on large closets.
    public var candidateBudget: Int = 600

    public init(dictionary: ColorDictionary = .standard, policy: HarmonyPolicy = .standard) {
        self.dictionary = dictionary
        self.policy = policy
    }

    public func generate(from items: [OutfitCandidate], request: OutfitRequest) -> OutfitGenerationResult {
        var run = Run(generator: self, items: items, request: request)
        return run.execute()
    }
}

// MARK: - Run

private struct Run {
    let generator: OutfitGenerator
    let request: OutfitRequest
    let harmony: ColorHarmony
    var rng: SeededGenerator

    var tops: [OutfitCandidate] = []
    var bottoms: [OutfitCandidate] = []
    var onePieces: [OutfitCandidate] = []
    var layers: [OutfitCandidate] = []
    var outerwear: [OutfitCandidate] = []
    var shoes: [OutfitCandidate] = []
    var accessories: [OutfitCandidate] = []
    var colognes: [OutfitCandidate] = []
    var incomplete: [UUID] = []
    var anchor: OutfitCandidate?
    var anchorProblem = false

    init(generator: OutfitGenerator, items: [OutfitCandidate], request: OutfitRequest) {
        self.generator = generator
        self.request = request
        harmony = ColorHarmony(dictionary: generator.dictionary, policy: generator.policy)
        rng = SeededGenerator(seed: request.seed)
        sort(items)
    }

    private mutating func sort(_ items: [OutfitCandidate]) {
        if let anchorID = request.anchorItemID {
            let found = items.first { $0.id == anchorID }
            if let found, !request.excludedItemIDs.contains(anchorID), isComplete(found) {
                anchor = found
            } else {
                anchorProblem = true
            }
        }

        for item in items where !request.excludedItemIDs.contains(item.id) {
            let isAnchor = item.id == anchor?.id
            guard isAnchor || fitsRequest(item) else { continue }
            guard isComplete(item) else {
                incomplete.append(item.id)
                continue
            }
            switch item.category {
            case .clothing:
                switch item.clothingType {
                case .top: tops.append(item)
                case .bottom: bottoms.append(item)
                case .onePiece: onePieces.append(item)
                case .layer: layers.append(item)
                case .outerwear: outerwear.append(item)
                case nil: break
                }
            case .shoes: shoes.append(item)
            case .cologne: colognes.append(item)
            default: accessories.append(item)
            }
        }

        if let anchor {
            // Restrict the anchor's own slot to the anchor so every outfit includes it.
            switch (anchor.category, anchor.clothingType) {
            case (.clothing, .top): tops = [anchor]; onePieces = []
            case (.clothing, .bottom): bottoms = [anchor]; onePieces = []
            case (.clothing, .onePiece): onePieces = [anchor]; tops = []; bottoms = []
            case (.clothing, .layer): layers = [anchor]
            case (.clothing, .outerwear): outerwear = [anchor]
            case (.shoes, _): shoes = [anchor]
            case (.cologne, _): colognes = [anchor]
            default: break
            }
        }
    }

    private func isComplete(_ item: OutfitCandidate) -> Bool {
        if item.category == .clothing && item.clothingType == nil { return false }
        if item.colors.isEmpty && !OutfitGenerator.colorNeutralCategories.contains(item.category) { return false }
        return true
    }

    private func fitsRequest(_ item: OutfitCandidate) -> Bool {
        if let season = request.season {
            let seasons = item.seasons.isEmpty ? OutfitGenerator.defaultSeasons(for: item.category) : item.seasons
            guard seasons.allows(season) else { return false }
        }
        if let target = request.formality, let formality = item.formality {
            guard formality.isCompatible(with: target) else { return false }
        }
        return true
    }

    private func harmonyColors(_ item: OutfitCandidate) -> [RGBColor] {
        OutfitGenerator.colorNeutralCategories.contains(item.category) ? [] : item.colors
    }

    private func evaluate(_ items: [OutfitCandidate]) -> HarmonyResult? {
        harmony.evaluate(items.flatMap(harmonyColors))
    }

    mutating func execute() -> OutfitGenerationResult {
        if anchorProblem {
            return OutfitGenerationResult(outfits: [], incompleteItemIDs: incomplete, shortfall: .anchorUnavailable)
        }
        guard request.count > 0 else {
            return OutfitGenerationResult(outfits: [], incompleteItemIDs: incomplete, shortfall: nil)
        }

        let bases = rankedBases()
        guard !bases.isEmpty || !(onePieces.isEmpty && (tops.isEmpty || bottoms.isEmpty)) else {
            return OutfitGenerationResult(outfits: [], incompleteItemIDs: incomplete, shortfall: .noBase)
        }

        var assembled: [GeneratedOutfit] = []
        let perBase = max(1, min(3, generator.candidateBudget / max(1, bases.count)))
        for base in bases {
            for core in completions(of: base).prefix(perBase) {
                assembled.append(finish(core))
            }
            if assembled.count >= generator.candidateBudget { break }
        }

        let outfits = select(from: assembled)
        let shortfall: OutfitGenerationResult.Shortfall? = outfits.isEmpty ? .noHarmoniousCombination : nil
        return OutfitGenerationResult(outfits: outfits, incompleteItemIDs: incomplete, shortfall: shortfall)
    }

    /// Every harmonious one-piece and top-with-bottom, best first, with a little seeded jitter
    /// so repeated runs explore different bases.
    private mutating func rankedBases() -> [[OutfitCandidate]] {
        var scored: [Scored<[OutfitCandidate]>] = []
        for piece in onePieces {
            if let result = evaluate([piece]) { scored.append(Scored(value: [piece], score: result.score)) }
        }
        for top in tops {
            for bottom in bottoms {
                if let result = evaluate([top, bottom]) { scored.append(Scored(value: [top, bottom], score: result.score)) }
            }
        }
        return jittered(scored)
    }

    /// Harmonious ways to complete a base with shoes, an optional layer and optional outerwear,
    /// best first.
    private mutating func completions(of base: [OutfitCandidate]) -> [[OutfitCandidate]] {
        let shoeOptions: [OutfitCandidate?] = shoes.isEmpty ? [nil] : shoes.map(Optional.some)
        var withShoes: [Scored<[OutfitCandidate]>] = []
        for shoe in shoeOptions {
            let items = base + (shoe.map { [$0] } ?? [])
            if let result = evaluate(items) { withShoes.append(Scored(value: items, score: result.score)) }
        }

        var completed: [Scored<[OutfitCandidate]>] = []
        for items in jittered(withShoes).prefix(3) {
            for layer in optionalPieces(layers, required: false) {
                let layered = items + (layer.map { [$0] } ?? [])
                guard evaluate(layered) != nil else { continue }
                for coat in optionalPieces(outerwear, required: request.season == .winter) {
                    let full = layered + (coat.map { [$0] } ?? [])
                    if let result = evaluate(full) { completed.append(Scored(value: full, score: result.score)) }
                }
            }
        }
        return jittered(completed)
    }

    /// The choices for an optional slot: nothing, or one of a few seeded picks. Summer skips
    /// layers and outerwear entirely; `required` drops the "nothing" option when pieces exist.
    private mutating func optionalPieces(_ pool: [OutfitCandidate], required: Bool) -> [OutfitCandidate?] {
        let anchored = pool.count == 1 && pool[0].id == anchor?.id
        if request.season == .summer && !anchored { return [nil] }
        guard !pool.isEmpty else { return [nil] }
        let picks = pool.shuffled(using: &rng).prefix(3).map(Optional.some)
        return (required || anchored) ? picks : [nil] + picks
    }

    /// Adds accessories greedily within category limits, then cologne.
    private mutating func finish(_ core: [OutfitCandidate]) -> GeneratedOutfit {
        var items = core
        var counts: [ItemCategory: Int] = [:]
        var added = 0

        var pool = accessories.shuffled(using: &rng)
        if let anchor, OutfitGenerator.accessoryLimits[anchor.category] != nil {
            pool.removeAll { $0.id == anchor.id }
            pool.insert(anchor, at: 0)
        }
        for accessory in pool where added < request.maxAccessories {
            let isAnchor = accessory.id == anchor?.id
            let limit = OutfitGenerator.accessoryLimits[accessory.category] ?? 1
            guard counts[accessory.category, default: 0] < limit else { continue }
            guard isAnchor || Bool.random(using: &rng) else { continue }
            guard evaluate(items + [accessory]) != nil else { continue }
            items.append(accessory)
            counts[accessory.category, default: 0] += 1
            added += 1
        }

        if request.includeCologne || anchor?.category == .cologne, let cologne = colognes.randomElement(using: &rng) {
            items.append(cologne)
        }

        // `core` already passed, and accessories were only added while harmony held.
        let result = evaluate(items) ?? HarmonyResult(score: 0, accentColors: [], matchedColors: [], paletteCombinationID: nil)
        let averageUsage = Double(items.map(\.usageCount).reduce(0, +)) / Double(items.count)
        let variety = 1 / (1 + averageUsage)
        return GeneratedOutfit(itemIDs: items.map(\.id), score: 0.85 * result.score + 0.15 * variety, harmony: result)
    }

    /// Highest scores first, avoiding outfits that repeat the same core pieces when possible.
    private func select(from assembled: [GeneratedOutfit]) -> [GeneratedOutfit] {
        let ranked = assembled.sorted { $0.score > $1.score }
        let coreIDs = Set((tops + bottoms + onePieces + layers + outerwear + shoes).map(\.id))
        var chosen: [GeneratedOutfit] = []
        var chosenKeys = Set<[UUID]>()

        func core(_ outfit: GeneratedOutfit) -> Set<UUID> {
            Set(outfit.itemIDs.filter(coreIDs.contains))
        }

        // Pass 1: at most one shared core piece with any chosen outfit (the anchor excepted).
        // Pass 2: fill up with anything not already chosen.
        for maxShared in [1, Int.max] {
            for outfit in ranked where chosen.count < request.count {
                let key = outfit.itemIDs.sorted { $0.uuidString < $1.uuidString }
                guard !chosenKeys.contains(key) else { continue }
                var pieces = core(outfit)
                if let anchorID = anchor?.id { pieces.remove(anchorID) }
                let tooSimilar = chosen.contains { other in
                    var otherPieces = core(other)
                    if let anchorID = anchor?.id { otherPieces.remove(anchorID) }
                    return pieces.intersection(otherPieces).count > maxShared
                }
                guard !tooSimilar else { continue }
                chosen.append(outfit)
                chosenKeys.insert(key)
            }
        }
        return chosen
    }

    /// Values ordered by score with up to 0.05 of seeded jitter, so near-ties vary by seed.
    private mutating func jittered<T>(_ scored: [Scored<T>]) -> [T] {
        var keyed: [(value: T, key: Double)] = []
        keyed.reserveCapacity(scored.count)
        for entry in scored {
            keyed.append((entry.value, entry.score + Double.random(in: 0..<0.05, using: &rng)))
        }
        return keyed.sorted { $0.key > $1.key }.map(\.value)
    }
}

private struct Scored<T> {
    let value: T
    let score: Double
}
