import WardrobeCore
import XCTest

final class ItemCategoryTests: XCTestCase {
    /// Raw values are persisted; this pins them so a rename shows up as a test failure.
    func testRawValuesAreStable() {
        XCTAssertEqual(ItemCategory.allCases.map(\.rawValue), [
            "clothing", "shoes", "hats", "scarves", "gloves", "belts",
            "bags", "watches", "rings", "cologne", "other",
        ])
    }

    func testStoredValueFallsBackToOther() {
        XCTAssertEqual(ItemCategory(storedValue: "watches"), .watches)
        XCTAssertEqual(ItemCategory(storedValue: "sunglasses"), .other)
        XCTAssertEqual(ItemCategory(storedValue: ""), .other)
    }
}
