import WardrobeCore
import XCTest

final class GarmentSwatchesTests: XCTestCase {
    func testSwatchesAreUniqueAndDistinguishable() {
        let swatches = GarmentSwatches.all
        XCTAssertEqual(Set(swatches.map(\.name)).count, swatches.count)
        XCTAssertEqual(Set(swatches.map(\.color)).count, swatches.count)
        for a in swatches {
            for b in swatches where a.name < b.name {
                let distance = LabColor(a.color).deltaE2000(LabColor(b.color))
                XCTAssertGreaterThan(distance, 3, "\(a.name) and \(b.name) look the same")
            }
        }
    }

    func testNearestSwatch() {
        for swatch in GarmentSwatches.all {
            XCTAssertEqual(GarmentSwatches.nearest(to: swatch.color).name, swatch.name)
        }
        XCTAssertEqual(GarmentSwatches.nearest(to: RGBColor(red: 0, green: 0, blue: 0)).name, "Black")
        XCTAssertEqual(GarmentSwatches.nearest(to: RGBColor(red: 255, green: 255, blue: 255)).name, "White")
        XCTAssertEqual(GarmentSwatches.nearest(to: RGBColor(red: 0x20, green: 0x2B, blue: 0x46)).name, "Navy")
    }

    /// The everyday neutrals must be neutral to the color engine, or basics would fail to pair.
    func testEverydayNeutralsAreNeutral() {
        let harmony = ColorHarmony()
        let neutrals = ["Black", "Charcoal", "Grey", "Light grey", "White", "Cream", "Beige", "Camel", "Tan", "Brown", "Navy", "Denim", "Olive", "Khaki", "Silver"]
        for name in neutrals {
            let swatch = GarmentSwatches.all.first { $0.name == name }
            XCTAssertNotNil(swatch, name)
            if let swatch {
                XCTAssertEqual(harmony.role(of: swatch.color), .neutral, name)
            }
        }
        for name in ["Red", "Burgundy", "Mustard", "Green", "Teal", "Cobalt", "Purple", "Pink"] {
            let swatch = GarmentSwatches.all.first { $0.name == name }
            XCTAssertEqual(swatch.map { harmony.role(of: $0.color) }, .accent, name)
        }
    }
}
