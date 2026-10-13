import Foundation
import WardrobeCore
import XCTest

final class ColorDictionaryTests: XCTestCase {
    private let dictionary = ColorDictionary.standard

    func testBundledDatasetShape() throws {
        let fresh = try ColorDictionary.bundled()
        XCTAssertEqual(fresh.colors.count, 159)
        XCTAssertEqual(fresh.combinations.count, 348)
        XCTAssertEqual(fresh.combinations.map(\.id), Array(1...348))
        XCTAssertEqual(Set(fresh.colors.map(\.id)), Set(1...159))
        for combination in fresh.combinations {
            XCTAssertTrue((2...4).contains(combination.colorIDs.count), "combination \(combination.id)")
        }
        XCTAssertEqual(Set(fresh.colors.map(\.swatch)), Set(1...6))
    }

    func testKnownColorsSurviveConversion() throws {
        let first = try XCTUnwrap(dictionary.color(id: 1))
        XCTAssertEqual(first.name, "Hermosa Pink")
        XCTAssertEqual(first.rgb.hex, "#F9C1CE")
        let black = try XCTUnwrap(dictionary.colors.first { $0.name == "Black" })
        XCTAssertEqual(black.rgb.hex, "#111314")
        XCTAssertEqual(Set(dictionary.combinationIDs(containing: black.id)), [46, 52, 62, 69, 112, 117, 144, 190, 207, 216, 221, 242, 255, 256, 269, 276, 288, 298, 313, 323, 337, 340, 344])
    }

    func testNearestToAnExactDictionaryColorIsItself() {
        for color in dictionary.colors {
            let match = dictionary.nearest(to: color.rgb).first
            XCTAssertEqual(match?.deltaE ?? .infinity, 0, accuracy: 1e-9)
            // Two dictionary colors may share an RGB value; the lower id wins ties.
            XCTAssertLessThanOrEqual(match?.color.id ?? .max, color.id)
        }
    }

    func testNearestRespectsLimitAndThreshold() {
        let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)
        let matches = dictionary.nearest(to: navy, limit: 5, within: 15)
        XCTAssertLessThanOrEqual(matches.count, 5)
        XCTAssertEqual(matches.map(\.deltaE), matches.map(\.deltaE).sorted())
        XCTAssertTrue(matches.allSatisfy { $0.deltaE <= 15 })
        XCTAssertTrue(dictionary.nearest(to: navy, limit: 0).isEmpty)
        XCTAssertTrue(dictionary.nearest(to: navy, limit: 3, within: -1).isEmpty)
    }

    /// The pair index must agree with a brute-force scan of every combination.
    func testPairIndexMatchesBruteForce() {
        var expected: [String: Set<Int>] = [:]
        for combination in dictionary.combinations {
            for a in combination.colorIDs {
                for b in combination.colorIDs where a != b {
                    expected["\(a)-\(b)", default: []].insert(combination.id)
                }
            }
        }
        for a in dictionary.colors {
            for b in dictionary.colors where a.id != b.id {
                let actual = Set(dictionary.combinationIDs(pairing: a.id, with: b.id))
                XCTAssertEqual(actual, expected["\(a.id)-\(b.id)"] ?? [], "\(a.id)-\(b.id)")
            }
        }
        XCTAssertTrue(dictionary.combinationIDs(pairing: 5, with: 5).isEmpty)
    }

    func testCombinationsContainingAll() throws {
        let combination = try XCTUnwrap(dictionary.combinations.first { $0.colorIDs.count == 4 })
        let ids = Set(combination.colorIDs)
        XCTAssertTrue(dictionary.combinationIDs(containingAll: ids).contains(combination.id))
        XCTAssertTrue(dictionary.combinationIDs(containingAll: []).isEmpty)
    }

    func testLoadValidation() {
        XCTAssertThrowsError(try ColorDictionary(colors: [(1, "A", "#nothex", 1)], combinations: [])) { error in
            XCTAssertEqual(error as? ColorDictionary.LoadError, .invalidColor(id: 1, hex: "#nothex"))
        }
        XCTAssertThrowsError(try ColorDictionary(colors: [(1, "A", "#000000", 1), (1, "B", "#FFFFFF", 1)], combinations: [])) { error in
            XCTAssertEqual(error as? ColorDictionary.LoadError, .duplicateColorID(1))
        }
        XCTAssertThrowsError(try ColorDictionary(colors: [(1, "A", "#000000", 1)], combinations: [(1, [1, 2])])) { error in
            XCTAssertEqual(error as? ColorDictionary.LoadError, .unknownColor(combination: 1, color: 2))
        }
        XCTAssertThrowsError(try ColorDictionary(colors: [(1, "A", "#000000", 1)], combinations: [(1, [1])])) { error in
            XCTAssertEqual(error as? ColorDictionary.LoadError, .invalidCombination(1))
        }
        XCTAssertThrowsError(try ColorDictionary(colors: [(1, "A", "#000000", 1), (2, "B", "#FFFFFF", 1)], combinations: [(1, [1, 1])]))
        XCTAssertThrowsError(try ColorDictionary(jsonData: Data("{}".utf8)))
    }
}
