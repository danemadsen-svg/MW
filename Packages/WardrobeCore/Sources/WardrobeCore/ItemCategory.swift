/// Top-level kind of a cataloged item.
///
/// Raw values are persisted on disk. Never rename or reuse one; add new cases instead.
public enum ItemCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case clothing
    case shoes
    case hats
    case scarves
    case gloves
    case belts
    case bags
    case watches
    case rings
    case cologne
    /// Catch-all for accessories without their own category (ties, sunglasses, necklaces).
    /// Also the fallback when a stored raw value isn't recognized.
    case other

    public var id: String { rawValue }

    /// Decodes a persisted raw value, falling back to `.other` for unknown values
    /// (e.g. a store written by a newer app version).
    public init(storedValue: String) {
        self = ItemCategory(rawValue: storedValue) ?? .other
    }
}
