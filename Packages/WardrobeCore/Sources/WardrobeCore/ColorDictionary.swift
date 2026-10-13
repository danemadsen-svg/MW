import Foundation

/// One of the 159 colors in *A Dictionary of Color Combinations*.
public struct DictionaryColor: Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let rgb: RGBColor
    /// The book's swatch chapter, 1...6.
    public let swatch: Int
    public let lab: LabColor
}

/// One of the book's 348 numbered palettes of two to four colors.
public struct ColorCombination: Hashable, Sendable, Identifiable {
    public let id: Int
    public let colorIDs: [Int]
}

/// A dictionary color close to some real-world color, with its perceptual distance.
public struct ColorMatch: Hashable, Sendable {
    public let color: DictionaryColor
    public let deltaE: Double
}

/// The digitized color dictionary: colors, combinations, and lookups between them.
public struct ColorDictionary: Sendable {
    public enum LoadError: Error, Equatable {
        case missingResource
        case invalidColor(id: Int, hex: String)
        case duplicateColorID(Int)
        case unknownColor(combination: Int, color: Int)
        case invalidCombination(Int)
    }

    public let colors: [DictionaryColor]
    public let combinations: [ColorCombination]

    private let colorPositions: [Int: Int]
    private let combinationPositions: [Int: Int]
    /// Combination ids keyed by an unordered pair of color ids.
    private let combinationsByPair: [ColorPair: [Int]]
    private let combinationsByColor: [Int: [Int]]

    /// The bundled dictionary. Loading the bundled resource can only fail if the package is
    /// built without its resources, which is a programmer error.
    public static let standard: ColorDictionary = {
        do {
            return try ColorDictionary.bundled()
        } catch {
            fatalError("Bundled color dictionary failed to load: \(error)")
        }
    }()

    public static func bundled() throws -> ColorDictionary {
        guard let url = Bundle.module.url(forResource: "color-dictionary", withExtension: "json") else {
            throw LoadError.missingResource
        }
        return try ColorDictionary(jsonData: Data(contentsOf: url))
    }

    public init(jsonData: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: jsonData)
        try self.init(
            colors: file.colors.map { ($0.id, $0.name, $0.hex, $0.swatch) },
            combinations: file.combinations.map { ($0.id, $0.colors) }
        )
    }

    public init(colors rawColors: [(id: Int, name: String, hex: String, swatch: Int)], combinations rawCombinations: [(id: Int, colors: [Int])]) throws {
        var colors: [DictionaryColor] = []
        var colorPositions: [Int: Int] = [:]
        for raw in rawColors {
            guard let rgb = RGBColor(hex: raw.hex) else {
                throw LoadError.invalidColor(id: raw.id, hex: raw.hex)
            }
            guard colorPositions[raw.id] == nil else { throw LoadError.duplicateColorID(raw.id) }
            colorPositions[raw.id] = colors.count
            colors.append(DictionaryColor(id: raw.id, name: raw.name, rgb: rgb, swatch: raw.swatch, lab: LabColor(rgb)))
        }

        var combinations: [ColorCombination] = []
        var combinationPositions: [Int: Int] = [:]
        var byPair: [ColorPair: [Int]] = [:]
        var byColor: [Int: [Int]] = [:]
        for raw in rawCombinations {
            guard raw.colors.count >= 2, Set(raw.colors).count == raw.colors.count, combinationPositions[raw.id] == nil else {
                throw LoadError.invalidCombination(raw.id)
            }
            for color in raw.colors where colorPositions[color] == nil {
                throw LoadError.unknownColor(combination: raw.id, color: color)
            }
            combinationPositions[raw.id] = combinations.count
            combinations.append(ColorCombination(id: raw.id, colorIDs: raw.colors))
            for color in raw.colors {
                byColor[color, default: []].append(raw.id)
            }
            for i in raw.colors.indices {
                for j in raw.colors.indices where j > i {
                    byPair[ColorPair(raw.colors[i], raw.colors[j]), default: []].append(raw.id)
                }
            }
        }

        self.colors = colors
        self.combinations = combinations
        self.colorPositions = colorPositions
        self.combinationPositions = combinationPositions
        self.combinationsByPair = byPair
        self.combinationsByColor = byColor
    }

    public func color(id: Int) -> DictionaryColor? {
        colorPositions[id].map { colors[$0] }
    }

    public func combination(id: Int) -> ColorCombination? {
        combinationPositions[id].map { combinations[$0] }
    }

    /// The closest dictionary colors to `lab`, nearest first, at most `limit`, within `maxDeltaE`.
    public func nearest(to lab: LabColor, limit: Int = 1, within maxDeltaE: Double = .infinity) -> [ColorMatch] {
        guard limit > 0 else { return [] }
        var matches: [ColorMatch] = []
        for color in colors {
            let deltaE = color.lab.deltaE2000(lab)
            if deltaE <= maxDeltaE {
                matches.append(ColorMatch(color: color, deltaE: deltaE))
            }
        }
        matches.sort { first, second in
            if first.deltaE != second.deltaE { return first.deltaE < second.deltaE }
            return first.color.id < second.color.id
        }
        return Array(matches.prefix(limit))
    }

    public func nearest(to rgb: RGBColor, limit: Int = 1, within maxDeltaE: Double = .infinity) -> [ColorMatch] {
        nearest(to: LabColor(rgb), limit: limit, within: maxDeltaE)
    }

    /// Ids of combinations containing both colors. Empty when the book never pairs them.
    public func combinationIDs(pairing first: Int, with second: Int) -> [Int] {
        guard first != second else { return [] }
        return combinationsByPair[ColorPair(first, second)] ?? []
    }

    /// Ids of combinations containing the color.
    public func combinationIDs(containing color: Int) -> [Int] {
        combinationsByColor[color] ?? []
    }

    /// Ids of the combinations that contain every color in `colorIDs`.
    public func combinationIDs(containingAll colorIDs: Set<Int>) -> [Int] {
        guard let first = colorIDs.first else { return [] }
        return combinationIDs(containing: first).filter { id in
            guard let combination = combination(id: id) else { return false }
            return colorIDs.isSubset(of: combination.colorIDs)
        }
    }
}

/// An unordered pair of color ids.
struct ColorPair: Hashable, Sendable {
    let low: Int
    let high: Int

    init(_ a: Int, _ b: Int) {
        low = min(a, b)
        high = max(a, b)
    }
}

private struct File: Decodable {
    struct Color: Decodable {
        let id: Int
        let name: String
        let hex: String
        let swatch: Int
    }

    struct Combination: Decodable {
        let id: Int
        let colors: [Int]
    }

    let colors: [Color]
    let combinations: [Combination]
}
