import SwiftData
import WardrobeCore
import XCTest
@testable import Wardrobe

@MainActor
final class PersistenceTests: XCTestCase {
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

    func testItemRoundTripsThroughStore() throws {
        let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)
        let cream = RGBColor(red: 0xF2, green: 0xEA, blue: 0xD8)
        let item = Item(name: "Oxford shirt", category: .clothing, primaryColor: navy, secondaryColor: cream)
        context.insert(item)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(fresh.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(fetched.id, item.id)
        XCTAssertEqual(fetched.name, "Oxford shirt")
        XCTAssertEqual(fetched.category, .clothing)
        XCTAssertEqual(fetched.primaryColor, navy)
        XCTAssertEqual(fetched.secondaryColor, cream)
        XCTAssertEqual(fetched.createdAt, fetched.updatedAt)
    }

    func testUntaggedItemHasNoColors() throws {
        let item = Item(category: .cologne)
        context.insert(item)
        try context.save()

        XCTAssertNil(item.primaryColor)
        XCTAssertNil(item.secondaryColor)
        XCTAssertEqual(item.name, "")
    }

    func testUnknownStoredCategoryFallsBackToOther() {
        let item = Item(category: .hats)
        item.categoryRaw = "sunglasses"
        XCTAssertEqual(item.category, .other)
    }

    func testCategoryIsFilterableInPredicate() throws {
        for category in [ItemCategory.watches, .watches, .rings, .shoes] {
            context.insert(Item(category: category))
        }
        try context.save()

        let watches = ItemCategory.watches.rawValue
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.categoryRaw == watches })
        XCTAssertEqual(try context.fetchCount(descriptor), 2)
    }

    func testOutfitItemsHaveInverse() throws {
        let shirt = Item(category: .clothing)
        let watch = Item(category: .watches)
        let outfit = Outfit(name: "Friday")
        for item in [shirt, watch] { context.insert(item) }
        context.insert(outfit)
        outfit.items = [shirt, watch]
        try context.save()

        XCTAssertEqual(Set(outfit.items.map(\.id)), [shirt.id, watch.id])
        XCTAssertEqual(shirt.outfits.map(\.id), [outfit.id])
        XCTAssertEqual(watch.outfits.map(\.id), [outfit.id])
    }

    func testItemCanBelongToManyOutfits() throws {
        let shoes = Item(category: .shoes)
        let first = Outfit(name: "Work")
        let second = Outfit(name: "Weekend")
        context.insert(shoes)
        context.insert(first)
        context.insert(second)
        first.items = [shoes]
        second.items = [shoes]
        try context.save()

        XCTAssertEqual(Set(shoes.outfits.map(\.id)), [first.id, second.id])
    }

    func testDeletingItemRemovesItFromOutfitButKeepsOutfit() throws {
        let shirt = Item(category: .clothing)
        let belt = Item(category: .belts)
        let outfit = Outfit()
        for item in [shirt, belt] { context.insert(item) }
        context.insert(outfit)
        outfit.items = [shirt, belt]
        try context.save()

        context.delete(belt)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Outfit>()), 1)
        XCTAssertEqual(outfit.items.map(\.id), [shirt.id])
    }

    func testDeletingOutfitKeepsItems() throws {
        let scarf = Item(category: .scarves)
        let outfit = Outfit()
        context.insert(scarf)
        context.insert(outfit)
        outfit.items = [scarf]
        try context.save()

        context.delete(outfit)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Item>()), 1)
        XCTAssertTrue(scarf.outfits.isEmpty)
    }

    func testPhotoDataIsPersisted() throws {
        let bytes = Data((0..<512 * 1024).map { UInt8(truncatingIfNeeded: $0) })
        let item = Item(category: .bags, photoData: bytes, thumbnailData: Data([1, 2, 3]))
        context.insert(item)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(fresh.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(fetched.photoData, bytes)
        XCTAssertEqual(fetched.thumbnailData, Data([1, 2, 3]))
    }
}
