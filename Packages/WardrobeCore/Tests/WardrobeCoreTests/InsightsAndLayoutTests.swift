import Foundation
import WardrobeCore
import XCTest

final class WardrobeInsightsTests: XCTestCase {
    private let analyzer = InsightsAnalyzer()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60
    private let white = RGBColor(red: 250, green: 250, blue: 250)
    private let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)

    private func item(_ category: ItemCategory, _ type: ClothingType? = nil, colors: [RGBColor]? = nil, age: Double = 30, outfits: Int = 0) -> InsightItem {
        InsightItem(id: UUID(), category: category, clothingType: type, colors: colors ?? [white], createdAt: now.addingTimeInterval(-age * day), outfitCount: outfits)
    }

    func testUnusedRespectsGracePeriodAndSortsOldestFirst() {
        let old = item(.clothing, .top, age: 90)
        let older = item(.shoes, age: 200)
        let fresh = item(.hats, age: 2)
        let used = item(.clothing, .bottom, age: 90, outfits: 1)
        let insights = analyzer.analyze([old, older, fresh, used], now: now)
        XCTAssertEqual(insights.unusedItemIDs, [older.id, old.id])
    }

    func testOverused() {
        let star = item(.clothing, .top, outfits: 12)
        let normal = (0..<6).map { _ in item(.clothing, .bottom, outfits: 2) }
        let insights = analyzer.analyze([star] + normal, now: now)
        XCTAssertEqual(insights.overusedItemIDs, [star.id])
        // Small absolute counts are never "over-used".
        let small = analyzer.analyze([item(.clothing, .top, outfits: 3), item(.shoes, outfits: 0)], now: now)
        XCTAssertTrue(small.overusedItemIDs.isEmpty)
    }

    func testGaps() {
        let tops = (0..<8).map { _ in item(.clothing, .top) }
        let insights = analyzer.analyze(tops + [item(.clothing, .bottom)], now: now)
        XCTAssertTrue(insights.gaps.contains(.noShoes))
        XCTAssertTrue(insights.gaps.contains(.noOuterwear))
        XCTAssertTrue(insights.gaps.contains(.unbalanced(tops: 8, bottoms: 1)))
        XCTAssertTrue(insights.gaps.contains(.onlyNeutrals))
        XCTAssertFalse(insights.gaps.contains(.noTops))

        let dressOnly = analyzer.analyze([item(.clothing, .onePiece), item(.shoes)], now: now)
        XCTAssertFalse(dressOnly.gaps.contains(.noTops))
        XCTAssertFalse(dressOnly.gaps.contains(.noBottoms))
        XCTAssertTrue(analyzer.analyze([], now: now).gaps.isEmpty)
    }

    func testIncomplete() {
        let untyped = item(.clothing, nil)
        let untagged = item(.shoes, colors: [])
        let ring = item(.rings, colors: [])
        let insights = analyzer.analyze([untyped, untagged, ring], now: now)
        XCTAssertEqual(Set(insights.incompleteItemIDs), [untyped.id, untagged.id])
    }

    func testAccentSuggestionsPairWithExistingAccents() throws {
        let harmony = ColorHarmony()
        let dictionary = ColorDictionary.standard
        let accent = try XCTUnwrap(dictionary.colors.first { harmony.role(of: $0.rgb) == .accent && dictionary.combinationIDs(containing: $0.id).count > 3 })
        let insights = analyzer.analyze([item(.clothing, .top, colors: [accent.rgb]), item(.clothing, .bottom, colors: [navy])], now: now)
        XCTAssertEqual(insights.accentSuggestions.count, 3)
        for suggestion in insights.accentSuggestions {
            XCTAssertNotNil(harmony.sanction(suggestion.rgb, accent.rgb), "\(suggestion.name) should pair with \(accent.name)")
            XCTAssertGreaterThan(suggestion.lab.deltaE2000(accent.lab), harmony.policy.tonalThreshold)
        }
        XCTAssertFalse(insights.gaps.contains(.onlyNeutrals))
    }

    func testNeutralWardrobeGetsVersatileSuggestions() {
        let insights = analyzer.analyze([item(.clothing, .top), item(.clothing, .bottom, colors: [navy])], now: now)
        XCTAssertEqual(insights.accentSuggestions.count, 3)
        let counts = insights.accentSuggestions.map { ColorDictionary.standard.combinationIDs(containing: $0.id).count }
        XCTAssertEqual(counts, counts.sorted(by: >))
    }
}

final class SketchLayoutTests: XCTestCase {
    private func piece(_ category: ItemCategory, _ type: ClothingType? = nil) -> SketchLayout.Piece {
        SketchLayout.Piece(id: UUID(), category: category, clothingType: type)
    }

    func testCoreOutfitStacksDownTheCenterWithoutOverlap() throws {
        let hat = piece(.hats), top = piece(.clothing, .top), bottom = piece(.clothing, .bottom), shoes = piece(.shoes)
        let slots = SketchLayout.layout([shoes, bottom, top, hat])
        let byID = Dictionary(uniqueKeysWithValues: slots.map { ($0.itemID, $0.frame) })
        let frames = try [hat, top, bottom, shoes].map { try XCTUnwrap(byID[$0.id]) }
        XCTAssertEqual(frames.map(\.y), frames.map(\.y).sorted(), "hat, top, bottom, shoes from top to bottom")
        for i in frames.indices {
            for j in frames.indices where j > i {
                XCTAssertFalse(frames[i].intersects(frames[j]), "\(i) overlaps \(j)")
            }
        }
    }

    func testEverythingFitsOnCanvasAndEveryPieceIsPlaced() {
        var pieces = [piece(.clothing, .onePiece), piece(.clothing, .outerwear), piece(.clothing, .layer), piece(.shoes), piece(.cologne)]
        pieces += [ItemCategory.hats, .scarves, .gloves, .belts, .bags, .watches, .rings, .rings, .other].map { piece($0) }
        pieces.append(piece(.clothing, .outerwear)) // overflow goes to the side column
        let slots = SketchLayout.layout(pieces)
        XCTAssertEqual(Set(slots.map(\.itemID)), Set(pieces.map(\.id)))
        for slot in slots {
            XCTAssertGreaterThanOrEqual(slot.frame.x, 0)
            XCTAssertGreaterThanOrEqual(slot.frame.y, 0)
            XCTAssertLessThanOrEqual(slot.frame.maxX, 1.0001)
            XCTAssertLessThanOrEqual(slot.frame.maxY, 1.0001)
            XCTAssertGreaterThan(slot.frame.height, 0)
        }
        XCTAssertEqual(slots.map(\.zIndex), slots.map(\.zIndex).sorted())
    }

    func testCologneGoesLastInSideColumn() throws {
        let cologne = piece(.cologne), bag = piece(.bags), watch = piece(.watches)
        let slots = SketchLayout.layout([cologne, bag, watch])
        let cologneY = try XCTUnwrap(slots.first { $0.itemID == cologne.id }).frame.y
        XCTAssertTrue(slots.filter { $0.itemID != cologne.id }.allSatisfy { $0.frame.y < cologneY })
    }
}

final class DeviceCapabilityTests: XCTestCase {
    private let gib: UInt64 = 1_024 * 1_024 * 1_024

    private func profile(_ memoryGiB: Double, ane: Bool = true, os: Int = 17, lowPower: Bool = false, thermal: ThermalLevel = .nominal) -> DeviceProfile {
        DeviceProfile(physicalMemoryBytes: UInt64(memoryGiB * Double(gib)), hasNeuralEngine: ane, osMajorVersion: os, isLowPowerModeEnabled: lowPower, thermalLevel: thermal)
    }

    func testHardwareTiers() {
        XCTAssertEqual(DeviceCapability.hardwareTier(for: profile(7.6)), .full)       // 8 GB phone reports ~7.5 GiB
        XCTAssertEqual(DeviceCapability.hardwareTier(for: profile(5.6)), .reduced)    // 6 GB phone
        XCTAssertEqual(DeviceCapability.hardwareTier(for: profile(3.7)), .sketchOnly) // 4 GB phone
        XCTAssertEqual(DeviceCapability.hardwareTier(for: profile(8, ane: false)), .sketchOnly)
        XCTAssertEqual(DeviceCapability.hardwareTier(for: profile(8, os: 16)), .sketchOnly)
    }

    func testTemporaryConditionsStepDown() {
        XCTAssertEqual(DeviceCapability.currentTier(for: profile(8, lowPower: true)), .reduced)
        XCTAssertEqual(DeviceCapability.currentTier(for: profile(8, thermal: .serious)), .reduced)
        XCTAssertEqual(DeviceCapability.currentTier(for: profile(6, thermal: .serious)), .sketchOnly)
        XCTAssertEqual(DeviceCapability.currentTier(for: profile(8, thermal: .critical)), .sketchOnly)
        XCTAssertEqual(DeviceCapability.currentTier(for: profile(8, thermal: .fair)), .full)
        XCTAssertEqual(DeviceCapability.currentTier(for: profile(3, lowPower: true)), .sketchOnly)
    }

    func testSettings() {
        XCTAssertFalse(DeviceCapability.settings(for: .full).reduceMemory)
        XCTAssertTrue(DeviceCapability.settings(for: .reduced).reduceMemory)
        XCTAssertLessThan(DeviceCapability.settings(for: .reduced).stepCount, DeviceCapability.settings(for: .full).stepCount)
        XCTAssertEqual(DeviceCapability.settings(for: .sketchOnly).stepCount, 0)
    }
}
