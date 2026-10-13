import WardrobeCore
import XCTest

final class LabColorTests: XCTestCase {
    func testSRGBToLabReferenceValues() {
        assertLab(RGBColor(red: 255, green: 255, blue: 255), l: 100, a: 0, b: 0)
        assertLab(RGBColor(red: 0, green: 0, blue: 0), l: 0, a: 0, b: 0)
        assertLab(RGBColor(red: 128, green: 128, blue: 128), l: 53.585, a: 0, b: 0)
        assertLab(RGBColor(red: 255, green: 0, blue: 0), l: 53.241, a: 80.092, b: 67.203)
        assertLab(RGBColor(red: 0, green: 0, blue: 255), l: 32.297, a: 79.188, b: -107.860)
    }

    func testChromaAndHue() {
        let grey = LabColor(RGBColor(red: 90, green: 90, blue: 90))
        XCTAssertLessThan(grey.chroma, 0.01)
        let red = LabColor(RGBColor(red: 255, green: 0, blue: 0))
        XCTAssertEqual(red.hueDegrees, 39.999, accuracy: 0.01)
        XCTAssertEqual(LabColor(l: 50, a: 0, b: -10).hueDegrees, 270, accuracy: 1e-9)
    }

    /// Reference pairs from Sharma, Wu & Dalal, "The CIEDE2000 Color-Difference Formula:
    /// Implementation Notes, Supplementary Test Data, and Mathematical Observations" (2005).
    func testCIEDE2000AgainstSharmaTestData() {
        let pairs: [(LabColor, LabColor, Double)] = [
            (.init(l: 50, a: 2.6772, b: -79.7751), .init(l: 50, a: 0, b: -82.7485), 2.0425),
            (.init(l: 50, a: 3.1571, b: -77.2803), .init(l: 50, a: 0, b: -82.7485), 2.8615),
            (.init(l: 50, a: 2.8361, b: -74.0200), .init(l: 50, a: 0, b: -82.7485), 3.4412),
            (.init(l: 50, a: 0, b: 0), .init(l: 50, a: -1, b: 2), 2.3669),
            (.init(l: 50, a: 2.49, b: -0.001), .init(l: 50, a: -2.49, b: 0.0009), 7.1792),
            (.init(l: 50, a: 2.49, b: -0.001), .init(l: 50, a: -2.49, b: 0.001), 7.1792),
            (.init(l: 50, a: 2.49, b: -0.001), .init(l: 50, a: -2.49, b: 0.0011), 7.2195),
            (.init(l: 50, a: 2.49, b: -0.001), .init(l: 50, a: -2.49, b: 0.0012), 7.2195),
            (.init(l: 50, a: 2.5, b: 0), .init(l: 73, a: 25, b: -18), 27.1492),
            (.init(l: 50, a: 2.5, b: 0), .init(l: 61, a: -5, b: 29), 22.8977),
            (.init(l: 50, a: 2.5, b: 0), .init(l: 56, a: -27, b: -3), 31.9030),
            (.init(l: 50, a: 2.5, b: 0), .init(l: 58, a: 24, b: 15), 19.4535),
            (.init(l: 60.2574, a: -34.0099, b: 36.2677), .init(l: 60.4626, a: -34.1751, b: 39.4387), 1.2644),
            (.init(l: 22.7233, a: 20.0904, b: -46.6940), .init(l: 23.0331, a: 14.9730, b: -42.5619), 2.0373),
        ]
        for (index, (first, second, expected)) in pairs.enumerated() {
            XCTAssertEqual(first.deltaE2000(second), expected, accuracy: 1e-4, "pair \(index)")
            XCTAssertEqual(second.deltaE2000(first), expected, accuracy: 1e-4, "pair \(index) reversed")
        }
    }

    func testDeltaEOfIdenticalColorsIsZero() {
        let color = LabColor(RGBColor(red: 31, green: 42, blue: 68))
        XCTAssertEqual(color.deltaE2000(color), 0, accuracy: 1e-12)
    }

    private func assertLab(_ rgb: RGBColor, l: Double, a: Double, b: Double, file: StaticString = #filePath, line: UInt = #line) {
        let lab = LabColor(rgb)
        XCTAssertEqual(lab.l, l, accuracy: 0.01, "L for \(rgb)", file: file, line: line)
        XCTAssertEqual(lab.a, a, accuracy: 0.01, "a for \(rgb)", file: file, line: line)
        XCTAssertEqual(lab.b, b, accuracy: 0.01, "b for \(rgb)", file: file, line: line)
    }
}
