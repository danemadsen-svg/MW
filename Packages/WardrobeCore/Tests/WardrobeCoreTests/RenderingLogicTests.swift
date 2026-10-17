import Foundation
import WardrobeCore
import XCTest

final class ImageModelCatalogTests: XCTestCase {
    func testDefaultModelIsPinnedAndComplete() {
        let model = ImageModelCatalog.default
        XCTAssertTrue(model.downloadURL.absoluteString.contains("/resolve/04a6a0bdd66fb8da470c14e56d762343ef579d88/"), "pinned to a revision")
        XCTAssertEqual(model.downloadURL.scheme, "https")
        XCTAssertEqual(model.sha256.count, 64)
        XCTAssertTrue(model.sha256.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        XCTAssertTrue(model.requiredResources.contains("VAEEncoder.mlmodelc"), "image-to-image needs the encoder")
        XCTAssertTrue(model.requiredResources.contains("SafetyChecker.mlmodelc"), "the OpenRAIL-M checklist keeps the safety checker")
        XCTAssertGreaterThan(model.requiredFreeBytes, model.downloadByteCount * 2)
        XCTAssertEqual(model.resolution, 512)
    }

    func testMissingResources() {
        let model = ImageModelCatalog.default
        XCTAssertTrue(model.missingResources(in: Set(model.requiredResources + ["extra.txt"])).isEmpty)
        XCTAssertEqual(model.missingResources(in: ["Unet.mlmodelc"]).count, model.requiredResources.count - 1)
    }
}

final class BodyLayoutTests: XCTestCase {
    private func piece(_ category: ItemCategory, _ type: ClothingType? = nil) -> SketchLayout.Piece {
        SketchLayout.Piece(id: UUID(), category: category, clothingType: type)
    }

    private let standing = BodyKeypoints(
        nose: UnitPoint2D(x: 0.5, y: 0.10),
        neck: UnitPoint2D(x: 0.5, y: 0.19),
        leftShoulder: UnitPoint2D(x: 0.60, y: 0.20), rightShoulder: UnitPoint2D(x: 0.40, y: 0.20),
        leftHip: UnitPoint2D(x: 0.56, y: 0.50), rightHip: UnitPoint2D(x: 0.44, y: 0.50),
        leftKnee: UnitPoint2D(x: 0.55, y: 0.70), rightKnee: UnitPoint2D(x: 0.45, y: 0.70),
        leftAnkle: UnitPoint2D(x: 0.55, y: 0.92), rightAnkle: UnitPoint2D(x: 0.45, y: 0.92)
    )

    private func assertInUnitSquare(_ rect: UnitRect, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(rect.x, 0, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(rect.y, 0, label, file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxX, 1.000001, label, file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxY, 1.000001, label, file: file, line: line)
        XCTAssertGreaterThan(rect.width, 0, label, file: file, line: line)
        XCTAssertGreaterThan(rect.height, 0, label, file: file, line: line)
    }

    func testRegionsFollowTheBodyTopToBottom() {
        let regions = BodyLayout.regions(for: standing)
        XCTAssertLessThan(regions.head.y, regions.torso.y)
        XCTAssertLessThan(regions.torso.y, regions.legs.y)
        XCTAssertLessThan(regions.legs.y, regions.feet.y)
        XCTAssertEqual(regions.torso.x + regions.torso.width / 2, 0.5, accuracy: 0.01, "centered on the body")
        // The torso spans shoulders to hips.
        XCTAssertLessThanOrEqual(regions.torso.y, 0.20)
        XCTAssertGreaterThanOrEqual(regions.torso.maxY, 0.50)
        XCTAssertGreaterThanOrEqual(regions.feet.maxY, 0.92)
        for (label, rect) in [("head", regions.head), ("torso", regions.torso), ("legs", regions.legs), ("feet", regions.feet), ("full", regions.fullBody), ("hand", regions.rightHand)] {
            assertInUnitSquare(rect, label)
        }
    }

    func testFallsBackToProportionsWithoutJoints() {
        let regions = BodyLayout.regions(for: BodyKeypoints())
        XCTAssertLessThan(regions.torso.y, regions.legs.y)
        XCTAssertLessThan(regions.legs.y, regions.feet.y)
        assertInUnitSquare(regions.legs, "legs")
        assertInUnitSquare(regions.head, "head")
    }

    func testExtremeJointsStayOnCanvas() {
        let edge = BodyKeypoints(
            nose: UnitPoint2D(x: 0.99, y: 0.0),
            leftShoulder: UnitPoint2D(x: 1.0, y: 0.02), rightShoulder: UnitPoint2D(x: 0.0, y: 0.02),
            leftAnkle: UnitPoint2D(x: 1, y: 1), rightAnkle: UnitPoint2D(x: 0.9, y: 1)
        )
        let regions = BodyLayout.regions(for: edge)
        for rect in [regions.head, regions.neck, regions.torso, regions.legs, regions.feet, regions.waist, regions.leftHand, regions.rightHand, regions.leftWrist, regions.fullBody] {
            assertInUnitSquare(rect, "edge")
        }
    }

    func testPlacementsLayerOuterwearOverTopAndSkipCologne() throws {
        let top = piece(.clothing, .top), bottom = piece(.clothing, .bottom), coat = piece(.clothing, .outerwear)
        let shoes = piece(.shoes), cologne = piece(.cologne), hat = piece(.hats), secondHat = piece(.hats)
        let placements = BodyLayout.placements(for: [coat, top, bottom, shoes, cologne, hat, secondHat], regions: BodyLayout.regions(for: standing))
        let ids = placements.map(\.itemID)
        XCTAssertFalse(ids.contains(cologne.id))
        XCTAssertFalse(ids.contains(secondHat.id), "one piece per region")
        let z = Dictionary(uniqueKeysWithValues: placements.map { ($0.itemID, $0.zIndex) })
        XCTAssertGreaterThan(try XCTUnwrap(z[coat.id]), try XCTUnwrap(z[top.id]))
        XCTAssertGreaterThan(try XCTUnwrap(z[top.id]), try XCTUnwrap(z[bottom.id]))
        XCTAssertEqual(placements.map(\.zIndex), placements.map(\.zIndex).sorted())
    }

    func testOnePieceClaimsTorsoAndLegs() {
        let dress = piece(.clothing, .onePiece), top = piece(.clothing, .top), bottom = piece(.clothing, .bottom)
        let placements = BodyLayout.placements(for: [dress, top, bottom], regions: BodyLayout.regions(for: standing))
        XCTAssertEqual(placements.map(\.itemID), [dress.id])
    }
}

final class RenderPromptTests: XCTestCase {
    func testTryOnPromptDescribesVisiblePieces() {
        let prompt = RenderPrompt.tryOn(pieces: [
            .init(category: .clothing, clothingType: .top, colorName: "Navy"),
            .init(category: .clothing, clothingType: .bottom, colorName: "Camel"),
            .init(category: .shoes, clothingType: nil, colorName: "Black"),
            .init(category: .cologne, clothingType: nil, colorName: nil),
            .init(category: .clothing, clothingType: .outerwear, colorName: "Olive"),
        ], appearanceNotes: "")
        XCTAssertTrue(prompt.contains("wearing a navy top, camel trousers, black shoes and an olive jacket"), prompt)
        XCTAssertFalse(prompt.contains("cologne"))
        XCTAssertTrue(prompt.contains("photorealistic"))
    }

    func testArticles() {
        XCTAssertEqual(RenderPrompt.tryOn(pieces: [.init(category: .watches, clothingType: nil, colorName: nil)], appearanceNotes: "").contains("wearing a watch"), true)
        XCTAssertTrue(RenderPrompt.tryOn(pieces: [.init(category: .other, clothingType: nil, colorName: nil)], appearanceNotes: "").contains("wearing an accessory"))
        XCTAssertTrue(RenderPrompt.tryOn(pieces: [.init(category: .hats, clothingType: nil, colorName: "Orange")], appearanceNotes: "").contains("wearing an orange hat"))
    }

    func testAppearanceNotesAreSanitized() {
        let prompt = RenderPrompt.avatar(appearanceNotes: "  short dark hair,   (glasses:1.4) [beard]\n<lora:x>  ")
        XCTAssertTrue(prompt.contains("short dark hair, glasses1.4 beard lorax"), prompt)
        XCTAssertFalse(prompt.contains("("))
        XCTAssertFalse(prompt.contains("<"))
        let long = RenderPrompt.avatar(appearanceNotes: String(repeating: "a", count: 500))
        XCTAssertLessThan(long.count, 300)
        XCTAssertEqual(RenderPrompt.avatar(appearanceNotes: "   "), RenderPrompt.avatar(appearanceNotes: ""))
    }

    func testNegativePromptGuardsAgainstUnsafeOutput() {
        XCTAssertTrue(RenderPrompt.negative.contains("nsfw"))
        XCTAssertTrue(RenderPrompt.negative.contains("nude"))
    }
}
