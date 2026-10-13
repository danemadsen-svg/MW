import WardrobeCore
import XCTest

final class CategoryClassifierTests: XCTestCase {
    private let classifier = CategoryClassifier()

    private func best(_ labels: [(String, Double)]) -> CategorySuggestion? {
        classifier.suggestions(for: labels.map { (identifier: $0.0, confidence: $0.1) }).first
    }

    func testSingleLabelMapping() {
        let cases: [(String, ItemCategory, ClothingType?)] = [
            ("jeans", .clothing, .bottom), ("t-shirt", .clothing, .top), ("T_Shirt", .clothing, .top),
            ("dress_shirt", .clothing, .top), ("dress", .clothing, .onePiece), ("cardigan", .clothing, .layer),
            ("trench coat", .clothing, .outerwear), ("blazer", .clothing, .outerwear), ("denim jacket", .clothing, .outerwear),
            ("running_shoe", .shoes, nil), ("sneaker", .shoes, nil), ("boots", .shoes, nil),
            ("baseball_cap", .hats, nil), ("beanie", .hats, nil), ("scarf", .scarves, nil),
            ("mitten", .gloves, nil), ("belt", .belts, nil), ("handbag", .bags, nil), ("backpack", .bags, nil),
            ("wristwatch", .watches, nil), ("watch", .watches, nil), ("ring", .rings, nil),
            ("perfume", .cologne, nil), ("eau de toilette", .cologne, nil), ("necktie", .other, nil),
            ("bow_tie", .other, nil), ("sunglasses", .other, nil), ("bootcut jeans", .clothing, .bottom),
        ]
        for (label, category, type) in cases {
            let suggestion = best([(label, 0.9)])
            XCTAssertEqual(suggestion?.category, category, label)
            XCTAssertEqual(suggestion?.clothingType, type, label)
        }
    }

    func testWholeWordMatchingOnly() {
        XCTAssertEqual(CategoryClassifier.rule(for: "earring")?.category, .other)
        XCTAssertNil(CategoryClassifier.rule(for: "laptop"))
        XCTAssertNil(CategoryClassifier.rule(for: "capsule"))
        XCTAssertNil(CategoryClassifier.rule(for: "sofa"))
        XCTAssertNil(CategoryClassifier.rule(for: ""))
    }

    func testConfidenceAccumulatesAcrossSupportingLabels() throws {
        let suggestions = classifier.suggestions(for: [
            (identifier: "sneaker", confidence: 0.4),
            (identifier: "shoes", confidence: 0.3),
            (identifier: "jeans", confidence: 0.5),
            (identifier: "furniture", confidence: 0.9),
        ])
        let top = try XCTUnwrap(suggestions.first)
        XCTAssertEqual(top.category, .shoes)
        XCTAssertEqual(top.confidence, 0.7, accuracy: 1e-9)
        XCTAssertEqual(top.evidence, ["sneaker", "shoes"])
        XCTAssertEqual(suggestions.count, 2)
        XCTAssertEqual(suggestions[1].clothingType, .bottom)
    }

    func testConfidenceIsCappedAndWeakLabelsIgnored() {
        let capped = best([("shoe", 0.8), ("sneaker", 0.7)])
        XCTAssertEqual(capped?.confidence, 1)
        XCTAssertNil(best([("hat", 0.01)]))
        XCTAssertTrue(classifier.suggestions(for: []).isEmpty)
    }
}
