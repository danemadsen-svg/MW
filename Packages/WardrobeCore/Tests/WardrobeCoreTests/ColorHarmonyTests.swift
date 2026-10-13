import WardrobeCore
import XCTest

final class ColorHarmonyTests: XCTestCase {
    private let dictionary = ColorDictionary.standard

    func testNeutralRoles() {
        let harmony = ColorHarmony()
        let neutrals: [RGBColor] = [
            RGBColor(red: 0, green: 0, blue: 0),
            RGBColor(red: 255, green: 255, blue: 255),
            RGBColor(red: 128, green: 128, blue: 128),
            RGBColor(red: 0xF2, green: 0xEA, blue: 0xD8), // cream
            RGBColor(red: 0x1F, green: 0x2A, blue: 0x44), // navy
            RGBColor(red: 0x5B, green: 0x7F, blue: 0xA6), // denim
            RGBColor(red: 0xC1, green: 0x9A, blue: 0x6B), // camel
            RGBColor(red: 0x5C, green: 0x40, blue: 0x33), // brown
        ]
        for color in neutrals {
            XCTAssertEqual(harmony.role(of: color), .neutral, "\(color)")
        }
        let accents: [RGBColor] = [
            RGBColor(red: 255, green: 0, blue: 0),
            RGBColor(red: 0x2E, green: 0x8B, blue: 0x57), // sea green
            RGBColor(red: 0xE1, green: 0xAD, blue: 0x01), // mustard
            RGBColor(red: 0x80, green: 0x00, blue: 0x20), // burgundy
        ]
        for color in accents {
            XCTAssertEqual(harmony.role(of: color), .accent, "\(color)")
        }
    }

    func testFashionNeutralsCanBeDisabled() {
        var policy = HarmonyPolicy()
        policy.fashionNeutrals = false
        let harmony = ColorHarmony(policy: policy)
        XCTAssertEqual(harmony.role(of: RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)), .accent)
        XCTAssertEqual(harmony.role(of: RGBColor(red: 128, green: 128, blue: 128)), .neutral)
    }

    func testNeutralOnlyAndSingleAccentScores() throws {
        let harmony = ColorHarmony()
        let white = RGBColor(red: 255, green: 255, blue: 255)
        let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)
        let red = RGBColor(red: 220, green: 20, blue: 30)

        let neutral = try XCTUnwrap(harmony.evaluate([white, navy]))
        XCTAssertEqual(neutral.score, ColorHarmony.neutralOnlyScore)
        XCTAssertTrue(neutral.accentColors.isEmpty)

        let single = try XCTUnwrap(harmony.evaluate([white, navy, red]))
        XCTAssertEqual(single.score, ColorHarmony.singleAccentScore)
        XCTAssertEqual(single.accentColors, [red])

        XCTAssertEqual(harmony.evaluate([])?.score, ColorHarmony.neutralOnlyScore)
    }

    func testBookPairOnExactColorsScoresPerfectly() throws {
        let harmony = ColorHarmony()
        let (a, b, combinationID) = try XCTUnwrap(accentPairFromSameCombination(harmony))
        let result = try XCTUnwrap(harmony.evaluate([a.rgb, b.rgb]))
        XCTAssertEqual(result.score, 1, accuracy: 1e-9)
        XCTAssertEqual(result.accentColors.count, 2)
        XCTAssertNotNil(result.paletteCombinationID)
        let sanction = try XCTUnwrap(harmony.sanction(a.rgb, b.rgb))
        XCTAssertTrue(sanction.combinationIDs.contains(combinationID))
        XCTAssertEqual(sanction.quality, 1, accuracy: 1e-9)
        XCTAssertEqual(sanction.first.color.rgb, a.rgb)
        XCTAssertEqual(sanction.second.color.rgb, b.rgb)

        // Order must not change the verdict, and cached reverse lookups keep argument order.
        let reversed = try XCTUnwrap(harmony.sanction(b.rgb, a.rgb))
        XCTAssertEqual(reversed.first.color.rgb, b.rgb)
        XCTAssertEqual(reversed.quality, sanction.quality, accuracy: 1e-12)
    }

    func testFullFourColorPaletteGetsBonusAndPaletteID() throws {
        let harmony = ColorHarmony()
        let fourColor = try XCTUnwrap(dictionary.combinations.first { combination in
            let colors = combination.colorIDs.compactMap(dictionary.color(id:))
            let allAccents = colors.allSatisfy { harmony.role(of: $0.rgb) == .accent }
            let distinct = harmony.accentClusters(colors.map(\.rgb)).count == colors.count
            return combination.colorIDs.count == 4 && allAccents && distinct
        })
        let colors = fourColor.colorIDs.compactMap(dictionary.color(id:)).map(\.rgb)
        let result = try XCTUnwrap(harmony.evaluate(colors))
        XCTAssertNotNil(result.paletteCombinationID)
        XCTAssertEqual(result.matchedColors.count, 4)
        XCTAssertGreaterThan(result.score, 0.95)
        XCTAssertLessThanOrEqual(result.score, 1)
    }

    func testUnsanctionedAccentPairIsRejected() throws {
        let harmony = ColorHarmony()
        let policy = harmony.policy
        let accents = dictionary.colors.filter { harmony.role(of: $0.rgb) == .accent }

        // Independently find two accents whose nearby dictionary colors are never paired by the book.
        var found: (DictionaryColor, DictionaryColor)?
        search: for a in accents {
            let nearA = dictionary.nearest(to: a.rgb, limit: policy.candidatesPerColor, within: policy.mappingThreshold)
            for b in accents where b.id > a.id && a.lab.deltaE2000(b.lab) > policy.tonalThreshold {
                let nearB = dictionary.nearest(to: b.rgb, limit: policy.candidatesPerColor, within: policy.mappingThreshold)
                let paired = nearA.contains { x in
                    nearB.contains { y in
                        dictionary.combinations.contains { $0.colorIDs.contains(x.color.id) && $0.colorIDs.contains(y.color.id) && x.color.id != y.color.id }
                    }
                }
                if !paired {
                    found = (a, b)
                    break search
                }
            }
        }
        let (a, b) = try XCTUnwrap(found)
        XCTAssertNil(harmony.sanction(a.rgb, b.rgb))
        XCTAssertNil(harmony.evaluate([a.rgb, b.rgb]))
        // Neutrals never rescue an unsanctioned pair.
        XCTAssertNil(harmony.evaluate([a.rgb, RGBColor(red: 0, green: 0, blue: 0), b.rgb]))
    }

    func testTonalShadesCollapseIntoOneAccent() throws {
        let harmony = ColorHarmony()
        let red = RGBColor(red: 200, green: 30, blue: 40)
        let nearlyRed = RGBColor(red: 205, green: 35, blue: 42)
        XCTAssertEqual(harmony.accentClusters([red, nearlyRed]), [red])
        XCTAssertEqual(try XCTUnwrap(harmony.evaluate([red, nearlyRed])).score, ColorHarmony.singleAccentScore)
    }

    func testTooManyAccentsIsRejected() {
        let harmony = ColorHarmony()
        // Five clearly distinct saturated hues.
        let hues: [RGBColor] = [
            RGBColor(red: 230, green: 30, blue: 30),
            RGBColor(red: 30, green: 180, blue: 60),
            RGBColor(red: 40, green: 60, blue: 230),
            RGBColor(red: 240, green: 220, blue: 20),
            RGBColor(red: 200, green: 40, blue: 200),
        ]
        XCTAssertEqual(harmony.accentClusters(hues).count, 5)
        XCTAssertNil(harmony.evaluate(hues))
    }

    func testColorsFarFromTheDictionaryCannotBeSanctioned() {
        var policy = HarmonyPolicy()
        policy.mappingThreshold = 0.0001
        let harmony = ColorHarmony(policy: policy)
        let a = RGBColor(red: 231, green: 31, blue: 29)
        let b = RGBColor(red: 29, green: 181, blue: 61)
        XCTAssertTrue(harmony.candidates(for: a).isEmpty)
        XCTAssertNil(harmony.evaluate([a, b]))
    }

    private func accentPairFromSameCombination(_ harmony: ColorHarmony) -> (DictionaryColor, DictionaryColor, Int)? {
        for combination in dictionary.combinations {
            let colors = combination.colorIDs.compactMap(dictionary.color(id:))
            for a in colors {
                for b in colors where b.id != a.id {
                    if harmony.role(of: a.rgb) == .accent && harmony.role(of: b.rgb) == .accent
                        && a.lab.deltaE2000(b.lab) > harmony.policy.tonalThreshold {
                        return (a, b, combination.id)
                    }
                }
            }
        }
        return nil
    }
}
