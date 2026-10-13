import WardrobeCore
import XCTest

final class DominantColorExtractorTests: XCTestCase {
    private let extractor = DominantColorExtractor()
    private let white = RGBColor(red: 245, green: 245, blue: 245)
    private let navy = RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)
    private let red = RGBColor(red: 200, green: 30, blue: 40)

    /// A `size`×`size` image with a background and a centered rectangle filled by `fill(x, y)`.
    private func image(size: Int = 32, background: RGBColor, inset: Int = 6, fill: (Int, Int) -> RGBColor) -> [RGBColor] {
        var pixels: [RGBColor] = []
        for y in 0..<size {
            for x in 0..<size {
                let inside = x >= inset && x < size - inset && y >= inset && y < size - inset
                pixels.append(inside ? fill(x, y) : background)
            }
        }
        return pixels
    }

    func testSolidItemOnPlainBackground() throws {
        let pixels = image(background: white) { _, _ in self.navy }
        let colors = try XCTUnwrap(extractor.extract(pixels: pixels, width: 32, height: 32))
        XCTAssertEqual(colors.primary, navy)
        XCTAssertNil(colors.secondary)
        XCTAssertFalse(colors.isPatterned)
        XCTAssertEqual(colors.primaryCoverage, 1, accuracy: 1e-9)
    }

    func testStripedItemReportsSecondaryColor() throws {
        let pixels = image(background: white) { _, y in y % 4 < 2 ? self.navy : self.red }
        let colors = try XCTUnwrap(extractor.extract(pixels: pixels, width: 32, height: 32))
        XCTAssertTrue(colors.isPatterned)
        XCTAssertEqual(Set([colors.primary, colors.secondary]), Set([navy, red]))
        XCTAssertEqual(colors.primaryCoverage + colors.secondaryCoverage, 1, accuracy: 1e-9)
    }

    func testSmallDetailsDoNotCountAsPattern() throws {
        // A navy item with a tiny red logo (well under 20% coverage).
        let pixels = image(background: white) { x, y in (x == 15 && y == 15) || (x == 16 && y == 15) ? self.red : self.navy }
        let colors = try XCTUnwrap(extractor.extract(pixels: pixels, width: 32, height: 32))
        XCTAssertEqual(colors.primary, navy)
        XCTAssertNil(colors.secondary)
    }

    func testNoisyPixelsStillResolveToTheItemColor() throws {
        var rng = SeededGenerator(seed: 1)
        let pixels = image(background: white) { _, _ in
            RGBColor(
                red: UInt8(Int(self.red.red) + Int.random(in: -6...6, using: &rng)),
                green: UInt8(Int(self.red.green) + Int.random(in: -6...6, using: &rng)),
                blue: UInt8(Int(self.red.blue) + Int.random(in: -6...6, using: &rng))
            )
        }
        let colors = try XCTUnwrap(extractor.extract(pixels: pixels, width: 32, height: 32))
        XCTAssertLessThan(LabColor(colors.primary).deltaE2000(LabColor(red)), 3)
        XCTAssertNil(colors.secondary, "noise must not read as a pattern")
    }

    func testMaskOverridesBorderHeuristic() throws {
        // Without a mask a navy-bordered photo would treat navy as background; the mask says the
        // whole frame is the item.
        let pixels = image(background: navy) { _, _ in self.red }
        let mask = [Bool](repeating: true, count: pixels.count)
        let colors = try XCTUnwrap(extractor.extract(pixels: pixels, width: 32, height: 32, mask: mask))
        XCTAssertEqual(colors.primary, navy, "navy covers more of the frame than red")
        XCTAssertEqual(colors.secondary, red)
    }

    func testFullFrameCloseUpKeepsAllPixels() throws {
        let pixels = [RGBColor](repeating: red, count: 16 * 16)
        let colors = try XCTUnwrap(extractor.extract(pixels: pixels, width: 16, height: 16))
        XCTAssertEqual(colors.primary, red)
    }

    func testBusyBackgroundIsNotRemoved() throws {
        // Non-uniform border: the heuristic must keep everything rather than guess.
        var pixels = image(background: white) { _, _ in self.navy }
        for x in 0..<32 where x % 2 == 0 { pixels[x] = red }
        for y in 0..<32 where y % 2 == 0 { pixels[y * 32] = red; pixels[y * 32 + 31] = red }
        for x in 0..<32 where x % 2 == 0 { pixels[31 * 32 + x] = red }
        XCTAssertNotNil(extractor.extract(pixels: pixels, width: 32, height: 32))
    }

    func testInvalidInput() {
        XCTAssertNil(extractor.extract(pixels: [], width: 0, height: 0))
        XCTAssertNil(extractor.extract(pixels: [red], width: 2, height: 2))
        XCTAssertNil(extractor.extract(pixels: [red, red, red, red], width: 2, height: 2, mask: [true]))
        XCTAssertNil(extractor.extract(pixels: [red, red, red, red], width: 2, height: 2, mask: [false, false, false, false]))
    }

    func testDeterministic() {
        let pixels = image(background: white) { x, _ in x % 3 == 0 ? self.red : self.navy }
        let first = extractor.extract(pixels: pixels, width: 32, height: 32)
        let second = extractor.extract(pixels: pixels, width: 32, height: 32)
        XCTAssertEqual(first, second)
    }
}
