/// What kind of garment a `.clothing` item is. Drives outfit structure (a top needs a bottom, etc.).
///
/// Raw values are persisted on disk. Never rename or reuse one; add new cases instead.
public enum ClothingType: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Shirts, tees, blouses, polos.
    case top
    /// Trousers, jeans, shorts, skirts.
    case bottom
    /// Dresses, jumpsuits: replaces a top and bottom.
    case onePiece
    /// Sweaters, cardigans, waistcoats, worn over a top.
    case layer
    /// Coats, jackets, blazers.
    case outerwear

    public var id: String { rawValue }
}

/// Seasons an item suits. An empty set means "any season".
public struct SeasonSet: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let spring = SeasonSet(rawValue: 1 << 0)
    public static let summer = SeasonSet(rawValue: 1 << 1)
    public static let autumn = SeasonSet(rawValue: 1 << 2)
    public static let winter = SeasonSet(rawValue: 1 << 3)
    public static let all: SeasonSet = [.spring, .summer, .autumn, .winter]

    public init(_ season: Season) {
        switch season {
        case .spring: self = .spring
        case .summer: self = .summer
        case .autumn: self = .autumn
        case .winter: self = .winter
        }
    }

    /// Whether an item with this set can be worn in `season`. Empty means any season.
    public func allows(_ season: Season) -> Bool {
        isEmpty || contains(SeasonSet(season))
    }

    /// The individual seasons in the set, in calendar order.
    public var seasons: [Season] {
        Season.allCases.filter { contains(SeasonSet($0)) }
    }
}

public enum Season: String, CaseIterable, Codable, Sendable, Identifiable {
    case spring
    case summer
    case autumn
    case winter

    public var id: String { rawValue }
}

/// How dressed-up an item or outfit is. Ordered from least to most formal.
///
/// Raw values are persisted on disk. Never renumber.
public enum Formality: Int, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case casual = 0
    case smartCasual = 1
    case business = 2
    case formal = 3

    public var id: Int { rawValue }

    public static func < (lhs: Formality, rhs: Formality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Items one step away still work (a smart-casual knit in a business outfit), two steps don't.
    public func isCompatible(with target: Formality) -> Bool {
        abs(rawValue - target.rawValue) <= 1
    }
}
