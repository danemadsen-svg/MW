/// Whether a color has to be sanctioned by the dictionary (`accent`) or goes with anything (`neutral`).
public enum ColorRole: Hashable, Sendable {
    case neutral
    case accent
}

/// Tunable rules for mapping real garment colors onto the dictionary and judging outfits.
public struct HarmonyPolicy: Hashable, Sendable {
    /// Colors with chroma (C*ab) below this are greys, black, white or off-whites: neutral.
    public var neutralChroma: Double = 12
    /// Also treat navy, denim and earth tones (camel, khaki, tan, brown, olive) as neutral.
    /// The book has no notion of fashion neutrals; without this almost no everyday outfit passes.
    public var fashionNeutrals: Bool = true
    /// Maximum CIEDE2000 distance for an item color to stand in for a dictionary color.
    public var mappingThreshold: Double = 10
    /// How many nearby dictionary colors each item color may map to.
    public var candidatesPerColor: Int = 3
    /// Accent colors closer than this are treated as one color (tonal dressing).
    public var tonalThreshold: Double = 8
    /// The book's palettes have at most four colors.
    public var maxAccentColors: Int = 4

    public static let standard = HarmonyPolicy()

    public init() {}

    public func role(of lab: LabColor) -> ColorRole {
        let chroma = lab.chroma
        if chroma < neutralChroma { return .neutral }
        guard fashionNeutrals else { return .accent }
        let hue = lab.hueDegrees
        let isNavy = lab.l < 35 && (220..<300).contains(hue) && chroma < 45
        let isDenim = (25..<65).contains(lab.l) && (220..<290).contains(hue) && chroma < 35
        let isEarth = (40..<120).contains(hue) && chroma < 35
        return isNavy || isDenim || isEarth ? .neutral : .accent
    }
}

/// How well two accent colors pair according to the dictionary.
public struct PairSanction: Hashable, Sendable {
    /// 0...1: 1 when both colors sit exactly on dictionary colors that the book pairs.
    public let quality: Double
    public let first: ColorMatch
    public let second: ColorMatch
    public let combinationIDs: [Int]
}

/// The verdict on a set of colors worn together.
public struct HarmonyResult: Hashable, Sendable {
    /// 0...1, higher is better. Neutral-only outfits score 0.70, a single accent 0.80, and
    /// sanctioned multi-accent outfits 0.75...1.0 depending on how closely they match the book.
    public let score: Double
    /// One representative per distinct accent color (tonal shades collapsed).
    public let accentColors: [RGBColor]
    /// For each accent, the dictionary color it was matched to (same order as `accentColors`).
    public let matchedColors: [DictionaryColor]
    /// A single book combination containing every accent, when one exists.
    public let paletteCombinationID: Int?
}

/// Judges color sets against the dictionary. Caches per-color work, so reuse one instance across
/// many evaluations (e.g. one per outfit-generation run). Not thread-safe.
public final class ColorHarmony {
    public let dictionary: ColorDictionary
    public let policy: HarmonyPolicy

    private var labCache: [Int: LabColor] = [:]
    private var candidateCache: [Int: [ColorMatch]] = [:]
    /// Keyed by both packed colors in argument order (24 bits each).
    private var pairCache: [Int: PairSanction?] = [:]

    public static let neutralOnlyScore = 0.70
    public static let singleAccentScore = 0.80

    public init(dictionary: ColorDictionary = .standard, policy: HarmonyPolicy = .standard) {
        self.dictionary = dictionary
        self.policy = policy
    }

    public func lab(_ color: RGBColor) -> LabColor {
        if let cached = labCache[color.packed] { return cached }
        let lab = LabColor(color)
        labCache[color.packed] = lab
        return lab
    }

    public func role(of color: RGBColor) -> ColorRole {
        policy.role(of: lab(color))
    }

    /// Dictionary colors `color` can stand in for, nearest first.
    public func candidates(for color: RGBColor) -> [ColorMatch] {
        if let cached = candidateCache[color.packed] { return cached }
        let matches = dictionary.nearest(to: lab(color), limit: policy.candidatesPerColor, within: policy.mappingThreshold)
        candidateCache[color.packed] = matches
        return matches
    }

    /// Whether the book pairs these two accent colors, and how closely. `nil` when it doesn't.
    public func sanction(_ first: RGBColor, _ second: RGBColor) -> PairSanction? {
        let key = first.packed << 24 | second.packed
        if let cached = pairCache[key] { return cached }

        var best: PairSanction?
        for a in candidates(for: first) {
            for b in candidates(for: second) {
                let combinations = dictionary.combinationIDs(pairing: a.color.id, with: b.color.id)
                guard !combinations.isEmpty else { continue }
                let quality = max(0, 1 - (a.deltaE + b.deltaE) / (2 * policy.mappingThreshold))
                if quality > (best?.quality ?? -1) {
                    best = PairSanction(quality: quality, first: a, second: b, combinationIDs: combinations)
                }
            }
        }
        pairCache[key] = .some(best)
        return best
    }

    /// Evaluates every color worn together (each item's primary and secondary colors).
    /// Returns `nil` when some pair of accent colors isn't sanctioned by the dictionary, or when
    /// there are more distinct accents than the book's largest palette.
    public func evaluate(_ colors: [RGBColor]) -> HarmonyResult? {
        let accents = accentClusters(colors)
        guard accents.count <= policy.maxAccentColors else { return nil }

        switch accents.count {
        case 0:
            return HarmonyResult(score: Self.neutralOnlyScore, accentColors: [], matchedColors: [], paletteCombinationID: nil)
        case 1:
            let match = candidates(for: accents[0]).first?.color
            return HarmonyResult(
                score: Self.singleAccentScore,
                accentColors: accents,
                matchedColors: match.map { [$0] } ?? [],
                paletteCombinationID: nil
            )
        default:
            break
        }

        var pairScores: [Double] = []
        for i in accents.indices {
            for j in accents.indices where j > i {
                guard let sanction = sanction(accents[i], accents[j]) else { return nil }
                pairScores.append(0.75 + 0.25 * sanction.quality)
            }
        }
        var score = pairScores.reduce(0, +) / Double(pairScores.count)

        let palette = commonPalette(for: accents)
        if palette != nil && accents.count >= 3 {
            score = min(1, score + 0.05)
        }
        let matched = palette?.matches ?? accents.compactMap { candidates(for: $0).first?.color }
        return HarmonyResult(score: score, accentColors: accents, matchedColors: matched, paletteCombinationID: palette?.combinationID)
    }

    /// Accent colors with tonal near-duplicates collapsed, in first-seen order.
    public func accentClusters(_ colors: [RGBColor]) -> [RGBColor] {
        var representatives: [RGBColor] = []
        for color in colors where role(of: color) == .accent {
            let colorLab = lab(color)
            let isTonalDuplicate = representatives.contains { lab($0).deltaE2000(colorLab) <= policy.tonalThreshold }
            if !isTonalDuplicate {
                representatives.append(color)
            }
        }
        return representatives
    }

    /// A single book combination that has a distinct candidate color for every accent.
    private func commonPalette(for accents: [RGBColor]) -> (combinationID: Int, matches: [DictionaryColor])? {
        let candidateSets = accents.map(candidates(for:))
        guard let firstCandidates = candidateSets.first else { return nil }

        var seen = Set<Int>()
        for start in firstCandidates {
            for combinationID in dictionary.combinationIDs(containing: start.color.id) where seen.insert(combinationID).inserted {
                guard let combination = dictionary.combination(id: combinationID) else { continue }
                if let assignment = assign(candidateSets, into: Set(combination.colorIDs), used: []) {
                    return (combinationID, assignment)
                }
            }
        }
        return nil
    }

    /// Picks one distinct color per accent from `available`, preferring the nearest candidates.
    private func assign(_ candidateSets: [[ColorMatch]], into available: Set<Int>, used: Set<Int>) -> [DictionaryColor]? {
        guard let head = candidateSets.first else { return [] }
        for match in head where available.contains(match.color.id) && !used.contains(match.color.id) {
            if let rest = assign(Array(candidateSets.dropFirst()), into: available, used: used.union([match.color.id])) {
                return [match.color] + rest
            }
        }
        return nil
    }
}
