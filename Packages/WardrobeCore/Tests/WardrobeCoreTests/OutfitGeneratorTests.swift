import Foundation
import WardrobeCore
import XCTest

final class OutfitGeneratorTests: XCTestCase {
    private let generator = OutfitGenerator()

    // Neutral colors, so every combination passes the color rules unless a test says otherwise.
    private let white = RGBColor(red: 250, green: 250, blue: 250)
    private let black = RGBColor(red: 20, green: 20, blue: 20)
    private let grey = RGBColor(red: 128, green: 128, blue: 128)
    private let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)
    private let camel = RGBColor(red: 0xC1, green: 0x9A, blue: 0x6B)
    private let gold = RGBColor(red: 0xD4, green: 0xAF, blue: 0x37)

    private func item(
        _ category: ItemCategory,
        _ type: ClothingType? = nil,
        _ colors: [RGBColor]? = nil,
        seasons: SeasonSet = [],
        formality: Formality? = nil,
        usage: Int = 0
    ) -> OutfitCandidate {
        OutfitCandidate(
            id: UUID(),
            category: category,
            clothingType: type,
            colors: colors ?? [white],
            seasons: seasons,
            formality: formality,
            usageCount: usage
        )
    }

    private func basicWardrobe() -> [OutfitCandidate] {
        [
            item(.clothing, .top, [white]), item(.clothing, .top, [grey]), item(.clothing, .top, [navy]),
            item(.clothing, .bottom, [navy]), item(.clothing, .bottom, [black]), item(.clothing, .bottom, [camel]),
            item(.shoes, nil, [black]), item(.shoes, nil, [white]),
        ]
    }

    private func roles(_ outfit: GeneratedOutfit, in wardrobe: [OutfitCandidate]) -> [OutfitCandidate] {
        let byID = Dictionary(uniqueKeysWithValues: wardrobe.map { ($0.id, $0) })
        return outfit.itemIDs.compactMap { byID[$0] }
    }

    func testEveryOutfitHasABaseAndShoes() {
        let wardrobe = basicWardrobe()
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 5, seed: 1))
        XCTAssertEqual(result.outfits.count, 5)
        XCTAssertNil(result.shortfall)
        for outfit in result.outfits {
            let items = roles(outfit, in: wardrobe)
            XCTAssertEqual(items.filter { $0.clothingType == .top }.count, 1)
            XCTAssertEqual(items.filter { $0.clothingType == .bottom }.count, 1)
            XCTAssertEqual(items.filter { $0.category == .shoes }.count, 1)
            XCTAssertEqual(Set(outfit.itemIDs).count, outfit.itemIDs.count, "no duplicate items")
            XCTAssertTrue((0...1).contains(outfit.score))
        }
    }

    func testOutfitsAreDistinct() {
        let wardrobe = basicWardrobe()
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 20, seed: 3))
        let keys = result.outfits.map { Set($0.itemIDs) }
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(result.outfits.map(\.score), result.outfits.map(\.score).sorted(by: >) , "best first")
    }

    func testOnePieceReplacesTopAndBottom() {
        let dress = item(.clothing, .onePiece, [black])
        let wardrobe = [dress, item(.shoes, nil, [black])]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 3, seed: 1))
        XCTAssertEqual(result.outfits.count, 1)
        XCTAssertEqual(result.outfits.first?.itemIDs, [dress.id, wardrobe[1].id])
    }

    func testOneHatMaxAndAccessoryLimits() {
        var wardrobe = basicWardrobe()
        wardrobe += (0..<4).map { _ in item(.hats, nil, [black]) }
        wardrobe += (0..<4).map { _ in item(.rings, nil, [gold]) }
        wardrobe += (0..<3).map { _ in item(.watches, nil, [gold]) }
        let request = OutfitRequest(count: 30, maxAccessories: 6, seed: 11)
        let result = generator.generate(from: wardrobe, request: request)
        XCTAssertFalse(result.outfits.isEmpty)
        for outfit in result.outfits {
            let items = roles(outfit, in: wardrobe)
            XCTAssertLessThanOrEqual(items.filter { $0.category == .hats }.count, 1)
            XCTAssertLessThanOrEqual(items.filter { $0.category == .rings }.count, 2)
            XCTAssertLessThanOrEqual(items.filter { $0.category == .watches }.count, 1)
        }
        let anyHat = result.outfits.contains { roles($0, in: wardrobe).contains { $0.category == .hats } }
        XCTAssertTrue(anyHat, "accessories should appear in some outfits")
    }

    func testMaxAccessoriesIsRespected() {
        var wardrobe = basicWardrobe()
        wardrobe += [item(.hats), item(.scarves), item(.belts), item(.bags), item(.watches, nil, [gold]), item(.gloves)]
        for maxAccessories in 0...2 {
            let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 10, maxAccessories: maxAccessories, seed: 5))
            for outfit in result.outfits {
                let accessories = roles(outfit, in: wardrobe).filter { OutfitGenerator.accessoryLimits[$0.category] != nil }
                XCTAssertLessThanOrEqual(accessories.count, maxAccessories)
            }
        }
    }

    func testSeasonFilterAndSummerSkipsOuterwear() {
        let winterTop = item(.clothing, .top, [grey], seasons: [.winter])
        let coat = item(.clothing, .outerwear, [camel])
        let gloves = item(.gloves, nil, [black])
        let wardrobe = basicWardrobe() + [winterTop, coat, gloves]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(season: .summer, count: 20, maxAccessories: 3, seed: 2))
        XCTAssertFalse(result.outfits.isEmpty)
        for outfit in result.outfits {
            XCTAssertFalse(outfit.itemIDs.contains(winterTop.id))
            XCTAssertFalse(outfit.itemIDs.contains(coat.id))
            XCTAssertFalse(outfit.itemIDs.contains(gloves.id), "gloves default to autumn and winter")
        }
    }

    func testWinterRequiresOuterwearWhenAvailable() {
        let coat = item(.clothing, .outerwear, [camel])
        let wardrobe = basicWardrobe() + [coat]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(season: .winter, count: 10, seed: 4))
        XCTAssertFalse(result.outfits.isEmpty)
        XCTAssertTrue(result.outfits.allSatisfy { $0.itemIDs.contains(coat.id) })
    }

    func testFormalityFilter() {
        let tee = item(.clothing, .top, [white], formality: .casual)
        let shirt = item(.clothing, .top, [white], formality: .business)
        let trousers = item(.clothing, .bottom, [navy], formality: .formal)
        let oxfords = item(.shoes, nil, [black], formality: .formal)
        let wardrobe = [tee, shirt, trousers, oxfords]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(formality: .formal, count: 10, seed: 1))
        XCTAssertEqual(result.outfits.count, 1)
        XCTAssertEqual(Set(result.outfits[0].itemIDs), [shirt.id, trousers.id, oxfords.id])
    }

    func testAnchorItemAppearsInEveryOutfit() {
        let wardrobe = basicWardrobe()
        let anchor = wardrobe[4] // black bottom
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 10, anchorItemID: anchor.id, seed: 9))
        XCTAssertFalse(result.outfits.isEmpty)
        XCTAssertTrue(result.outfits.allSatisfy { $0.itemIDs.contains(anchor.id) })
    }

    func testAnchorAccessoryIsAlwaysIncluded() {
        let hat = item(.hats, nil, [black])
        let wardrobe = basicWardrobe() + [hat]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 5, anchorItemID: hat.id, seed: 9))
        XCTAssertFalse(result.outfits.isEmpty)
        XCTAssertTrue(result.outfits.allSatisfy { $0.itemIDs.contains(hat.id) })
    }

    func testAnchorBypassesSeasonFilter() {
        let coat = item(.clothing, .outerwear, [camel], seasons: [.winter])
        let wardrobe = basicWardrobe() + [coat]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(season: .summer, count: 5, anchorItemID: coat.id, seed: 9))
        XCTAssertFalse(result.outfits.isEmpty)
        XCTAssertTrue(result.outfits.allSatisfy { $0.itemIDs.contains(coat.id) })
    }

    func testUnavailableAnchor() {
        let wardrobe = basicWardrobe()
        let missing = generator.generate(from: wardrobe, request: OutfitRequest(anchorItemID: UUID()))
        XCTAssertEqual(missing.shortfall, .anchorUnavailable)
        let excluded = generator.generate(from: wardrobe, request: OutfitRequest(anchorItemID: wardrobe[0].id, excludedItemIDs: [wardrobe[0].id]))
        XCTAssertEqual(excluded.shortfall, .anchorUnavailable)
        XCTAssertTrue(excluded.outfits.isEmpty)
    }

    func testExcludedItemsNeverAppear() {
        let wardrobe = basicWardrobe()
        let excluded: Set<UUID> = [wardrobe[0].id, wardrobe[6].id]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 20, excludedItemIDs: excluded, seed: 8))
        XCTAssertFalse(result.outfits.isEmpty)
        XCTAssertTrue(result.outfits.allSatisfy { excluded.isDisjoint(with: $0.itemIDs) })
    }

    func testIncompleteItemsAreReportedAndSkipped() {
        let untyped = OutfitCandidate(id: UUID(), category: .clothing, clothingType: nil, colors: [white])
        let untagged = OutfitCandidate(id: UUID(), category: .clothing, clothingType: .top, colors: [])
        let untaggedHat = OutfitCandidate(id: UUID(), category: .hats, colors: [])
        let ring = OutfitCandidate(id: UUID(), category: .rings, colors: []) // metals need no color
        let cologne = OutfitCandidate(id: UUID(), category: .cologne, colors: [])
        let wardrobe = basicWardrobe() + [untyped, untagged, untaggedHat, ring, cologne]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 10, seed: 1))
        XCTAssertEqual(Set(result.incompleteItemIDs), [untyped.id, untagged.id, untaggedHat.id])
        for outfit in result.outfits {
            XCTAssertTrue(Set(result.incompleteItemIDs).isDisjoint(with: outfit.itemIDs))
        }
    }

    func testCologneIsAddedWhenRequested() {
        let cologne = OutfitCandidate(id: UUID(), category: .cologne, colors: [])
        let wardrobe = basicWardrobe() + [cologne]
        let with = generator.generate(from: wardrobe, request: OutfitRequest(count: 5, includeCologne: true, seed: 1))
        XCTAssertTrue(with.outfits.allSatisfy { $0.itemIDs.last == cologne.id })
        let without = generator.generate(from: wardrobe, request: OutfitRequest(count: 5, includeCologne: false, seed: 1))
        XCTAssertTrue(without.outfits.allSatisfy { !$0.itemIDs.contains(cologne.id) })
    }

    func testShortfalls() {
        let onlyTops = [item(.clothing, .top), item(.clothing, .top), item(.shoes)]
        XCTAssertEqual(generator.generate(from: onlyTops, request: OutfitRequest()).shortfall, .noBase)
        XCTAssertEqual(generator.generate(from: [], request: OutfitRequest()).shortfall, .noBase)

        let harmony = ColorHarmony()
        let accents = ColorDictionary.standard.colors.filter { harmony.role(of: $0.rgb) == .accent }
        var clash: (RGBColor, RGBColor)?
        search: for a in accents {
            for b in accents where harmony.sanction(a.rgb, b.rgb) == nil && a.lab.deltaE2000(b.lab) > 8 {
                clash = (a.rgb, b.rgb)
                break search
            }
        }
        guard let (a, b) = clash else { return XCTFail("expected an unsanctioned pair") }
        let clashing = [item(.clothing, .top, [a]), item(.clothing, .bottom, [b]), item(.shoes, nil, [black])]
        let result = generator.generate(from: clashing, request: OutfitRequest())
        XCTAssertEqual(result.shortfall, .noHarmoniousCombination)
        XCTAssertTrue(result.outfits.isEmpty)
    }

    func testEveryOutfitPassesTheColorRules() {
        let dictionary = ColorDictionary.standard
        let palette = dictionary.colors.map(\.rgb)
        var wardrobe: [OutfitCandidate] = []
        for (index, color) in palette.enumerated() {
            let slot = index % 5
            switch slot {
            case 0: wardrobe.append(item(.clothing, .top, [color]))
            case 1: wardrobe.append(item(.clothing, .bottom, [color]))
            case 2: wardrobe.append(item(.shoes, nil, [color]))
            case 3: wardrobe.append(item(.scarves, nil, [color]))
            default: wardrobe.append(item(.clothing, .top, [color, palette[(index * 7) % palette.count]]))
            }
        }
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 25, seed: 42))
        XCTAssertFalse(result.outfits.isEmpty)
        let check = ColorHarmony()
        let byID = Dictionary(uniqueKeysWithValues: wardrobe.map { ($0.id, $0) })
        for outfit in result.outfits {
            let colors = outfit.itemIDs.compactMap { byID[$0] }
                .filter { !OutfitGenerator.colorNeutralCategories.contains($0.category) }
                .flatMap(\.colors)
            XCTAssertNotNil(check.evaluate(colors), "outfit \(outfit.itemIDs) breaks the color rules")
        }
    }

    func testSameSeedIsDeterministicAndSeedsVary() {
        var wardrobe = basicWardrobe()
        wardrobe += (0..<6).map { index in item(.clothing, .top, [[white, grey, navy, black, camel, white][index]]) }
        wardrobe += [item(.hats, nil, [black]), item(.belts, nil, [camel]), item(.bags, nil, [black])]
        let request = OutfitRequest(count: 6, seed: 77)
        let first = generator.generate(from: wardrobe, request: request)
        let second = generator.generate(from: wardrobe, request: request)
        XCTAssertEqual(first.outfits.map(\.itemIDs), second.outfits.map(\.itemIDs))

        let variants = Set((1...6).map { seed in
            generator.generate(from: wardrobe, request: OutfitRequest(count: 6, seed: UInt64(seed))).outfits.map(\.itemIDs)
        })
        XCTAssertGreaterThan(variants.count, 1, "different seeds should give different suggestions")
    }

    func testLessUsedItemsAreFavored() {
        let worn = item(.clothing, .top, [white], usage: 50)
        let fresh = item(.clothing, .top, [white], usage: 0)
        let wardrobe = [worn, fresh, item(.clothing, .bottom, [navy]), item(.shoes, nil, [black])]
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 1, seed: 1))
        XCTAssertEqual(result.outfits.first?.itemIDs.first, fresh.id)
    }

    func testLargeWardrobeIsFast() {
        let palette = ColorDictionary.standard.colors.map(\.rgb)
        var wardrobe: [OutfitCandidate] = []
        for index in 0..<300 {
            let color = palette[(index * 13) % palette.count]
            switch index % 6 {
            case 0, 1: wardrobe.append(item(.clothing, .top, [color]))
            case 2: wardrobe.append(item(.clothing, .bottom, [index % 4 == 0 ? navy : color]))
            case 3: wardrobe.append(item(.shoes, nil, [index % 2 == 0 ? black : color]))
            case 4: wardrobe.append(item(.clothing, [.layer, .outerwear][index % 2], [color]))
            default: wardrobe.append(item([.hats, .belts, .bags, .scarves, .watches][index % 5], nil, [color]))
            }
        }
        let start = Date()
        let result = generator.generate(from: wardrobe, request: OutfitRequest(count: 20, seed: 5))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(result.outfits.count, 20)
        XCTAssertLessThan(elapsed, 10, "generation took \(elapsed)s")
    }
}
