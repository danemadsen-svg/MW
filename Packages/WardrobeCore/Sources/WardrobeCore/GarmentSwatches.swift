/// A named color offered when tagging an item by hand.
public struct GarmentSwatch: Hashable, Sendable, Identifiable {
    public let name: String
    public let color: RGBColor

    public var id: String { name }

    public init(_ name: String, _ hex: String) {
        guard let color = RGBColor(hex: hex) else {
            preconditionFailure("Invalid swatch hex \(hex)")
        }
        self.name = name
        self.color = color
    }
}

public enum GarmentSwatches {
    /// Common garment colors, grouped neutrals first, then by hue. Users can also pick any color.
    public static let all: [GarmentSwatch] = [
        GarmentSwatch("Black", "#141414"),
        GarmentSwatch("Charcoal", "#36454F"),
        GarmentSwatch("Grey", "#8E8E8E"),
        GarmentSwatch("Light grey", "#C8C8C8"),
        GarmentSwatch("White", "#F7F7F5"),
        GarmentSwatch("Cream", "#F2EAD8"),
        GarmentSwatch("Beige", "#D9C7A7"),
        GarmentSwatch("Camel", "#C19A6B"),
        GarmentSwatch("Tan", "#A9825A"),
        GarmentSwatch("Brown", "#5C4033"),
        GarmentSwatch("Navy", "#1F2A44"),
        GarmentSwatch("Denim", "#5B7FA6"),
        GarmentSwatch("Olive", "#556B2F"),
        GarmentSwatch("Khaki", "#BDB07A"),
        GarmentSwatch("Burgundy", "#7A1E2C"),
        GarmentSwatch("Red", "#C0262D"),
        GarmentSwatch("Rust", "#B5532A"),
        GarmentSwatch("Pink", "#E8A5B5"),
        GarmentSwatch("Orange", "#E3742B"),
        GarmentSwatch("Mustard", "#D4A017"),
        GarmentSwatch("Yellow", "#F2D24B"),
        GarmentSwatch("Green", "#2E7D4F"),
        GarmentSwatch("Sage", "#9CAF88"),
        GarmentSwatch("Teal", "#1F7A7A"),
        GarmentSwatch("Sky blue", "#8EC3E6"),
        GarmentSwatch("Cobalt", "#1F4FB5"),
        GarmentSwatch("Purple", "#5E3A87"),
        GarmentSwatch("Lavender", "#B9A6D9"),
        GarmentSwatch("Silver", "#C0C0C6"),
        GarmentSwatch("Gold", "#C9A447"),
    ]

    /// The swatch closest to `color` (CIEDE2000), for naming a picked or detected color.
    public static func nearest(to color: RGBColor) -> GarmentSwatch {
        let target = LabColor(color)
        var best = all[0]
        var bestDistance = Double.infinity
        for swatch in all {
            let distance = LabColor(swatch.color).deltaE2000(target)
            if distance < bestDistance {
                bestDistance = distance
                best = swatch
            }
        }
        return best
    }
}
