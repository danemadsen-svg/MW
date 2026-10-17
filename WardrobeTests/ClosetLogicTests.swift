import SwiftData
import WardrobeCore
import XCTest
@testable import Wardrobe

final class ClosetLogicTests: XCTestCase {
    private let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)
    private let red = RGBColor(red: 0xC0, green: 0x26, blue: 0x2D)

    // MARK: ClosetFilter

    func testEmptyFilterMatchesEverything() {
        let filter = ClosetFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertTrue(filter.matches(name: "", notes: "", category: .rings, colors: [], isIncomplete: true))
    }

    func testSearchRequiresEveryTermAndIgnoresCaseAndDiacritics() {
        var filter = ClosetFilter()
        filter.searchText = "  oxford   BLUE "
        XCTAssertEqual(filter.searchTerms, ["oxford", "BLUE"])
        XCTAssertTrue(filter.matches(name: "Oxford shirt", notes: "light blue", category: .clothing, colors: [], isIncomplete: false))
        XCTAssertFalse(filter.matches(name: "Oxford shirt", notes: "white", category: .clothing, colors: [], isIncomplete: false))
        filter.searchText = "cafe"
        XCTAssertTrue(filter.matches(name: "Café jacket", notes: "", category: .clothing, colors: [], isIncomplete: false))
    }

    func testScopes() {
        var filter = ClosetFilter()
        filter.scope = .category(.watches)
        XCTAssertTrue(filter.matches(name: "", notes: "", category: .watches, colors: [], isIncomplete: false))
        XCTAssertFalse(filter.matches(name: "", notes: "", category: .rings, colors: [], isIncomplete: false))
        filter.scope = .needsDetails
        XCTAssertTrue(filter.matches(name: "", notes: "", category: .rings, colors: [], isIncomplete: true))
        XCTAssertFalse(filter.matches(name: "", notes: "", category: .rings, colors: [], isIncomplete: false))
    }

    func testColorFilterMatchesPrimaryOrSecondaryNearTheSwatch() throws {
        var filter = ClosetFilter()
        filter.swatch = try XCTUnwrap(GarmentSwatches.all.first { $0.name == "Navy" })
        let nearNavy = RGBColor(red: 0x22, green: 0x2D, blue: 0x48)
        XCTAssertTrue(filter.matches(name: "", notes: "", category: .clothing, colors: [nearNavy], isIncomplete: false))
        XCTAssertTrue(filter.matches(name: "", notes: "", category: .clothing, colors: [red, navy], isIncomplete: false))
        XCTAssertFalse(filter.matches(name: "", notes: "", category: .clothing, colors: [red], isIncomplete: false))
        XCTAssertFalse(filter.matches(name: "", notes: "", category: .clothing, colors: [], isIncomplete: false))
    }

    func testCategoriesPresentKeepCanonicalOrder() {
        XCTAssertEqual(ClosetFilter.categoriesPresent(in: [.rings, .clothing, .rings, .shoes]), [.clothing, .shoes, .rings])
    }

    // MARK: ItemColorSelection

    func testSecondaryWithoutPrimaryBecomesPrimary() {
        var selection = ItemColorSelection()
        selection.select(red, for: .secondary)
        XCTAssertEqual(selection.primary, red)
        XCTAssertNil(selection.secondary)
    }

    func testSecondaryCannotDuplicatePrimaryAndClearingPromotes() {
        var selection = ItemColorSelection(primary: navy, secondary: nil)
        selection.select(navy, for: .secondary)
        XCTAssertNil(selection.secondary)
        selection.select(red, for: .secondary)
        XCTAssertEqual(selection.secondary, red)
        selection.select(red, for: .primary)
        XCTAssertEqual(selection.primary, red)
        XCTAssertNil(selection.secondary, "a primary equal to the secondary clears the secondary")

        selection = ItemColorSelection(primary: navy, secondary: red)
        selection.clear(.primary)
        XCTAssertEqual(selection.primary, red)
        XCTAssertNil(selection.secondary)
    }

    // MARK: ItemDraft

    func testPrefillOnlyFillsEmptyFields() {
        var draft = ItemDraft()
        draft.primaryColor = red
        let suggestion = TagSuggestion(category: .clothing, clothingType: .bottom, categoryConfidence: 0.9, primaryColor: navy, secondaryColor: nil)
        draft.prefillEmptyFields(from: suggestion)
        XCTAssertEqual(draft.category, .clothing)
        XCTAssertEqual(draft.clothingType, .bottom)
        XCTAssertEqual(draft.primaryColor, red, "user's color is kept")
    }

    func testApplyReplacesAndReflects() {
        var draft = ItemDraft()
        draft.category = .bags
        let suggestion = TagSuggestion(category: .clothing, clothingType: .top, categoryConfidence: 0.4, primaryColor: navy, secondaryColor: navy)
        XCTAssertFalse(draft.reflects(suggestion))
        draft.apply(suggestion)
        XCTAssertEqual(draft.category, .clothing)
        XCTAssertEqual(draft.clothingType, .top)
        XCTAssertEqual(draft.primaryColor, navy)
        XCTAssertNil(draft.secondaryColor, "a secondary equal to the primary is dropped")
        XCTAssertTrue(draft.reflects(suggestion))
    }

    @MainActor
    func testWriteNormalizesFields() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let item = Item(category: .clothing, clothingType: .top)
        container.mainContext.insert(item)

        var draft = ItemDraft(item: item)
        draft.name = "  Linen shirt \n"
        draft.category = .bags
        draft.clothingType = .top
        draft.primaryColor = nil
        draft.secondaryColor = red
        draft.notes = " washed "
        draft.write(to: item)

        XCTAssertEqual(item.name, "Linen shirt")
        XCTAssertEqual(item.category, .bags)
        XCTAssertNil(item.clothingType, "clothing type only applies to clothing")
        XCTAssertEqual(item.primaryColor, red, "a lone secondary color becomes the primary")
        XCTAssertNil(item.secondaryColor)
        XCTAssertEqual(item.notes, "washed")
    }

    func testSuggestionSummary() {
        let jeans = TagSuggestion(category: .clothing, clothingType: .bottom, categoryConfidence: 0.8, primaryColor: navy, secondaryColor: nil)
        XCTAssertEqual(ItemDraft.summary(of: jeans), "Bottom · Navy")
        let watch = TagSuggestion(category: .watches, clothingType: nil, categoryConfidence: 0.8, primaryColor: nil, secondaryColor: nil)
        XCTAssertEqual(ItemDraft.summary(of: watch), "Watch")
        let nothing = TagSuggestion(category: nil, clothingType: nil, categoryConfidence: 0, primaryColor: nil, secondaryColor: nil)
        XCTAssertNil(ItemDraft.summary(of: nothing))
    }
}
