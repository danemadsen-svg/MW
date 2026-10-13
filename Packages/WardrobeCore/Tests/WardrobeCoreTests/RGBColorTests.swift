import Foundation
import WardrobeCore
import XCTest

final class RGBColorTests: XCTestCase {
    func testPackedRoundTrip() {
        let color = RGBColor(red: 0xC9, green: 0xA6, blue: 0x6B)
        XCTAssertEqual(color.packed, 0xC9A66B)
        XCTAssertEqual(RGBColor(packed: 0xC9A66B), color)
    }

    func testPackedRejectsOutOfRange() {
        XCTAssertNil(RGBColor(packed: -1))
        XCTAssertNil(RGBColor(packed: 0x1000000))
        XCTAssertEqual(RGBColor(packed: 0), RGBColor(red: 0, green: 0, blue: 0))
        XCTAssertEqual(RGBColor(packed: 0xFFFFFF), RGBColor(red: 255, green: 255, blue: 255))
    }

    func testHexFormattingIsUppercaseAndZeroPadded() {
        XCTAssertEqual(RGBColor(red: 0, green: 0, blue: 0).hex, "#000000")
        XCTAssertEqual(RGBColor(red: 0, green: 0x0A, blue: 0xFF).hex, "#000AFF")
        XCTAssertEqual(RGBColor(red: 0xC9, green: 0xA6, blue: 0x6B).hex, "#C9A66B")
    }

    func testHexParsingAcceptsCommonForms() {
        let expected = RGBColor(red: 0xC9, green: 0xA6, blue: 0x6B)
        XCTAssertEqual(RGBColor(hex: "#C9A66B"), expected)
        XCTAssertEqual(RGBColor(hex: "c9a66b"), expected)
        XCTAssertEqual(RGBColor(hex: "  #c9A66b\n"), expected)
        XCTAssertEqual(RGBColor(hex: "#f0a"), RGBColor(red: 0xFF, green: 0x00, blue: 0xAA))
    }

    func testHexParsingRejectsMalformedInput() {
        for input in ["", "#", "#12345", "#1234567", "#GGGGGG", "12 345", "+12345", "#-12345", "０１２３４５"] {
            XCTAssertNil(RGBColor(hex: input), "expected nil for \(input.debugDescription)")
        }
    }

    func testHexRoundTripForEveryChannelValue() {
        for value in 0...255 {
            let byte = UInt8(value)
            let color = RGBColor(red: byte, green: 255 - byte, blue: byte / 2)
            XCTAssertEqual(RGBColor(hex: color.hex), color)
        }
    }

    func testCodableUsesHexString() throws {
        let color = RGBColor(red: 0x1A, green: 0x2B, blue: 0x3C)
        let data = try JSONEncoder().encode([color])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), ##"["#1A2B3C"]"##)
        XCTAssertEqual(try JSONDecoder().decode([RGBColor].self, from: data), [color])
    }

    func testDecodingInvalidHexThrows() {
        let data = Data(#"["not a color"]"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode([RGBColor].self, from: data))
    }
}
