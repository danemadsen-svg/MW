import SwiftUI
import WardrobeCore

// User-facing names and SF Symbols for domain types. Keep all wording here so the rest of the
// UI never switches over enums just to label them.

extension ItemCategory {
    var displayName: String {
        switch self {
        case .clothing: "Clothing"
        case .shoes: "Shoes"
        case .hats: "Hats"
        case .scarves: "Scarves"
        case .gloves: "Gloves"
        case .belts: "Belts"
        case .bags: "Bags"
        case .watches: "Watches"
        case .rings: "Rings"
        case .cologne: "Cologne"
        case .other: "Other"
        }
    }

    /// Singular form for a single item ("Watch", "Ring").
    var singularName: String {
        switch self {
        case .clothing: "Clothing"
        case .shoes: "Shoes"
        case .hats: "Hat"
        case .scarves: "Scarf"
        case .gloves: "Gloves"
        case .belts: "Belt"
        case .bags: "Bag"
        case .watches: "Watch"
        case .rings: "Ring"
        case .cologne: "Cologne"
        case .other: "Accessory"
        }
    }

    var systemImage: String {
        switch self {
        case .clothing: "tshirt"
        case .shoes: "shoeprints.fill"
        case .hats: "graduationcap"
        case .scarves: "wind"
        case .gloves: "hand.raised"
        case .belts: "line.3.horizontal"
        case .bags: "bag"
        case .watches: "applewatch"
        case .rings: "circle.circle"
        case .cologne: "drop"
        case .other: "sparkle"
        }
    }

    /// Whether the color engine uses this category's color. Metals and fragrance don't.
    var usesColor: Bool {
        !OutfitGenerator.colorNeutralCategories.contains(self)
    }
}

extension ClothingType {
    var displayName: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .onePiece: "One-piece"
        case .layer: "Layer"
        case .outerwear: "Outerwear"
        }
    }

    var examples: String {
        switch self {
        case .top: "Shirts, tees, blouses"
        case .bottom: "Trousers, jeans, skirts"
        case .onePiece: "Dresses, jumpsuits"
        case .layer: "Sweaters, cardigans, vests"
        case .outerwear: "Coats, jackets, blazers"
        }
    }

    var systemImage: String {
        switch self {
        case .top: "tshirt"
        case .bottom: "figure.walk"
        case .onePiece: "figure.dress.line.vertical.figure"
        case .layer: "square.stack"
        case .outerwear: "cloud.rain"
        }
    }
}

extension Season {
    var displayName: String {
        switch self {
        case .spring: "Spring"
        case .summer: "Summer"
        case .autumn: "Autumn"
        case .winter: "Winter"
        }
    }

    var systemImage: String {
        switch self {
        case .spring: "leaf"
        case .summer: "sun.max"
        case .autumn: "wind"
        case .winter: "snowflake"
        }
    }

    /// The season for a date in the northern hemisphere by meteorological months.
    static func current(for date: Date = .now, calendar: Calendar = .current) -> Season {
        switch calendar.component(.month, from: date) {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
    }
}

extension Formality {
    var displayName: String {
        switch self {
        case .casual: "Casual"
        case .smartCasual: "Smart casual"
        case .business: "Business"
        case .formal: "Formal"
        }
    }
}

extension SeasonSet {
    /// "Any season", "Summer", or "Spring, Autumn".
    var summary: String {
        if isEmpty || self == .all { return "Any season" }
        return seasons.map(\.displayName).joined(separator: ", ")
    }
}

extension Color {
    init(_ rgb: RGBColor) {
        self.init(.sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255, opacity: 1)
    }
}
