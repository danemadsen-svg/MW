import SwiftData
import WardrobeCore
import XCTest
@testable import Wardrobe

@MainActor
final class OutfitSavingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try Persistence.makeContainer(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    func testSavedOutfitKeepsGeneratedOrderScoreAndPalette() throws {
        let (first, second) = try XCTUnwrap(Self.pairedAccents(), "The dictionary should pair two accent colors")
        // Created in the reverse of generated order, so falling back to creation order would show.
        let shoes = Item(name: "Loafers", category: .shoes, primaryColor: Self.charcoal, createdAt: Date(timeIntervalSince1970: 1_000))
        let bottom = Item(name: "Trousers", category: .clothing, clothingType: .bottom, primaryColor: second, createdAt: Date(timeIntervalSince1970: 2_000))
        let top = Item(name: "Shirt", category: .clothing, clothingType: .top, primaryColor: first, createdAt: Date(timeIntervalSince1970: 3_000))
        let items = [shoes, bottom, top]
        for item in items { context.insert(item) }
        try context.save()

        let request = OutfitRequest(season: .autumn, formality: .smartCasual, count: 1, maxAccessories: 0, includeCologne: false, seed: 7)
        let generated = try XCTUnwrap(OutfitGenerator().generate(from: items.map(\.outfitCandidate), request: request).outfits.first)
        XCTAssertEqual(generated.itemIDs, [top.id, bottom.id, shoes.id])
        let paletteID = try XCTUnwrap(generated.harmony.paletteCombinationID)

        let outfit = try context.saveGeneratedOutfit(generated, itemsByID: Self.lookup(items), request: request)

        XCTAssertEqual(outfit.orderedItems.map(\.id), generated.itemIDs)
        XCTAssertEqual(outfit.score, generated.score)
        XCTAssertEqual(outfit.paletteCombinationID, paletteID)
        XCTAssertEqual(outfit.season, .autumn)
        XCTAssertEqual(outfit.formality, .smartCasual)
        XCTAssertEqual(top.outfits.map(\.id), [outfit.id])

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(fresh.fetch(FetchDescriptor<Outfit>()).first)
        XCTAssertEqual(fetched.orderedItems.map(\.id), generated.itemIDs)
        XCTAssertEqual(fetched.score, generated.score)
        XCTAssertEqual(fetched.paletteCombinationID, paletteID)
        XCTAssertEqual(fetched.season, .autumn)
        XCTAssertEqual(fetched.formality, .smartCasual)
    }

    func testNeutralOutfitSavesWithoutPalette() throws {
        let top = Item(category: .clothing, clothingType: .top, primaryColor: RGBColor(red: 0xF2, green: 0xF2, blue: 0xF2))
        let bottom = Item(category: .clothing, clothingType: .bottom, primaryColor: Self.charcoal)
        for item in [top, bottom] { context.insert(item) }
        try context.save()

        let request = OutfitRequest(count: 1, maxAccessories: 0, includeCologne: false, seed: 3)
        let generated = try XCTUnwrap(OutfitGenerator().generate(from: [top, bottom].map(\.outfitCandidate), request: request).outfits.first)
        let outfit = try context.saveGeneratedOutfit(generated, itemsByID: Self.lookup([top, bottom]), request: request)

        XCTAssertEqual(outfit.orderedItems.map(\.id), [top.id, bottom.id])
        XCTAssertEqual(outfit.score, generated.score)
        XCTAssertNil(outfit.paletteCombinationID)
        XCTAssertNil(outfit.season)
        XCTAssertNil(outfit.formality)
    }

    func testItemsDeletedSinceGeneratingAreSkipped() throws {
        let top = Item(category: .clothing, clothingType: .top, primaryColor: RGBColor(red: 0xF2, green: 0xF2, blue: 0xF2))
        let bottom = Item(category: .clothing, clothingType: .bottom, primaryColor: Self.charcoal)
        let shoes = Item(category: .shoes, primaryColor: Self.charcoal)
        for item in [top, bottom, shoes] { context.insert(item) }
        try context.save()

        let request = OutfitRequest(count: 1, maxAccessories: 0, includeCologne: false, seed: 5)
        let generated = try XCTUnwrap(OutfitGenerator().generate(from: [top, bottom, shoes].map(\.outfitCandidate), request: request).outfits.first)
        XCTAssertEqual(generated.itemIDs, [top.id, bottom.id, shoes.id])

        let outfit = try context.saveGeneratedOutfit(generated, itemsByID: Self.lookup([top, shoes]), request: request)
        XCTAssertEqual(outfit.orderedItems.map(\.id), [top.id, shoes.id])
        XCTAssertEqual(outfit.itemOrder, [top.id, shoes.id])
    }

    // MARK: - Helpers

    private static let charcoal = RGBColor(red: 0x30, green: 0x30, blue: 0x30)

    private static func lookup(_ items: [Item]) -> [UUID: Item] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    /// Two distinct accent colors from one book combination, so a top and bottom in them get a palette.
    private static func pairedAccents() -> (RGBColor, RGBColor)? {
        let dictionary = ColorDictionary.standard
        let harmony = ColorHarmony()
        for combination in dictionary.combinations {
            let accents = combination.colorIDs
                .compactMap { dictionary.color(id: $0)?.rgb }
                .filter { harmony.role(of: $0) == .accent }
            for i in accents.indices {
                for j in accents.indices where j > i {
                    let pair = [accents[i], accents[j]]
                    if harmony.accentClusters(pair).count == 2, harmony.evaluate(pair)?.paletteCombinationID != nil {
                        return (accents[i], accents[j])
                    }
                }
            }
        }
        return nil
    }
}
