import SwiftData
import WardrobeCore
import XCTest
@testable import Wardrobe

@MainActor
final class AutoTagReviewTests: XCTestCase {
    private let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)
    private let cream = RGBColor(red: 0xF2, green: 0xEA, blue: 0xD8)
    private var container: ModelContainer!

    override func setUp() async throws {
        container = try Persistence.makeContainer(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func insert(_ item: Item) -> Item {
        container.mainContext.insert(item)
        return item
    }

    func testRecordNeverTouchesUserFieldsAndFlagsDifferences() {
        let item = insert(Item(category: .bags, primaryColor: navy))
        let suggestion = TagSuggestion(category: .clothing, clothingType: .bottom, categoryConfidence: 0.7, primaryColor: cream, secondaryColor: nil)
        BackgroundRetagger.record(suggestion, on: item, version: 3)

        XCTAssertEqual(item.category, .bags)
        XCTAssertEqual(item.primaryColor, navy)
        XCTAssertEqual(item.suggestedCategory, .clothing)
        XCTAssertEqual(item.suggestedClothingType, .bottom)
        XCTAssertEqual(item.suggestedPrimaryColor, cream)
        XCTAssertEqual(item.suggestionConfidence, 0.7)
        XCTAssertEqual(item.autoTagVersion, 3)
        XCTAssertTrue(item.needsReview)
    }

    func testMatchingSuggestionDoesNotNeedReview() {
        let item = insert(Item(category: .clothing, clothingType: .bottom, primaryColor: navy))
        let same = TagSuggestion(category: .clothing, clothingType: .bottom, categoryConfidence: 0.9, primaryColor: navy, secondaryColor: nil)
        BackgroundRetagger.record(same, on: item, version: 1)
        XCTAssertFalse(item.needsReview)

        BackgroundRetagger.record(nil, on: item, version: 1)
        XCTAssertFalse(item.needsReview, "no suggestion, nothing to review")
        XCTAssertNil(item.suggestedCategory)
    }

    func testAcceptCopiesSuggestionsAndClearsFlag() {
        let item = insert(Item(category: .bags))
        BackgroundRetagger.record(
            TagSuggestion(category: .clothing, clothingType: .top, categoryConfidence: 0.8, primaryColor: navy, secondaryColor: cream),
            on: item,
            version: 1
        )
        let before = item.updatedAt
        item.acceptSuggestions()

        XCTAssertEqual(item.category, .clothing)
        XCTAssertEqual(item.clothingType, .top)
        XCTAssertEqual(item.primaryColor, navy)
        XCTAssertEqual(item.secondaryColor, cream)
        XCTAssertFalse(item.needsReview)
        XCTAssertGreaterThanOrEqual(item.updatedAt, before)
    }

    func testAcceptingANonClothingCategoryDropsClothingType() {
        let item = insert(Item(category: .clothing, clothingType: .top, primaryColor: navy))
        BackgroundRetagger.record(
            TagSuggestion(category: .shoes, clothingType: nil, categoryConfidence: 0.9, primaryColor: nil, secondaryColor: nil),
            on: item,
            version: 1
        )
        item.acceptSuggestions()
        XCTAssertEqual(item.category, .shoes)
        XCTAssertNil(item.clothingType)
        XCTAssertEqual(item.primaryColor, navy, "no color suggestion keeps the user's color")
    }

    func testRetaggerSkipsCurrentItemsAndTagsOthers() async throws {
        let context = container.mainContext
        let fresh = Item(category: .bags, photoData: Data([1]))
        let current = Item(category: .bags, photoData: Data([2]))
        current.autoTagVersion = AutoTaggerInfo.currentVersion
        let noPhoto = Item(category: .rings)
        for item in [fresh, current, noPhoto] { context.insert(item) }
        try context.save()

        let tagger = StubTagger(suggestion: TagSuggestion(category: .clothing, clothingType: .top, categoryConfidence: 0.9, primaryColor: navy, secondaryColor: nil))
        await BackgroundRetagger(modelContainer: container).run(tagger: tagger)

        let check = ModelContext(container)
        let items = try check.fetch(FetchDescriptor<Item>())
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        XCTAssertEqual(byID[fresh.id]?.suggestedCategory, .clothing)
        XCTAssertEqual(byID[fresh.id]?.needsReview, true)
        XCTAssertNil(byID[current.id]?.suggestedCategory)
        XCTAssertEqual(byID[noPhoto.id]?.autoTagVersion, AutoTaggerInfo.currentVersion)
        XCTAssertEqual(byID[noPhoto.id]?.needsReview, false)
        XCTAssertEqual(tagger.callCount, 1)
    }
}

private final class StubTagger: AutoTagging, @unchecked Sendable {
    private let suggestion: TagSuggestion?
    private let lock = NSLock()
    private var calls = 0

    init(suggestion: TagSuggestion?) {
        self.suggestion = suggestion
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func suggest(forPhoto data: Data) async -> TagSuggestion? {
        lock.lock()
        calls += 1
        lock.unlock()
        return suggestion
    }
}
