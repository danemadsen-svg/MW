/// Text prompts for on-device rendering. Kept in Core so the wording is tested and consistent.
public enum RenderPrompt {
    /// One piece as the prompt sees it.
    public struct Piece: Hashable, Sendable {
        public let category: ItemCategory
        public let clothingType: ClothingType?
        /// Color name (from `GarmentSwatches`), if the item is tagged.
        public let colorName: String?

        public init(category: ItemCategory, clothingType: ClothingType?, colorName: String?) {
            self.category = category
            self.clothingType = clothingType
            self.colorName = colorName
        }
    }

    public static let negative = "deformed, distorted, disfigured, extra limbs, extra fingers, bad anatomy, blurry, low quality, watermark, text, logo, cropped, nsfw, nude"

    /// Avatar clean-up: keep the person, normalize light and background.
    public static func avatar(appearanceNotes: String) -> String {
        var parts = ["full body studio fashion photograph of a person standing", "neutral light grey background", "soft even lighting", "sharp focus", "photorealistic"]
        let notes = sanitized(appearanceNotes)
        if !notes.isEmpty { parts.insert(notes, at: 1) }
        return parts.joined(separator: ", ")
    }

    /// Try-on blend: describe what the person is wearing so the model reconciles the composite.
    public static func tryOn(pieces: [Piece], appearanceNotes: String) -> String {
        let worn = pieces.compactMap(describe)
        var parts = ["full body studio fashion photograph of a person standing"]
        let notes = sanitized(appearanceNotes)
        if !notes.isEmpty { parts.append(notes) }
        if !worn.isEmpty { parts.append("wearing " + list(worn)) }
        parts += ["neutral light grey background", "soft even lighting", "detailed fabric", "photorealistic"]
        return parts.joined(separator: ", ")
    }

    /// "a navy top", "black shoes"; `nil` for things not visible on a person (cologne).
    static func describe(_ piece: Piece) -> String? {
        let noun: String
        var plural = false
        switch (piece.category, piece.clothingType) {
        case (.clothing, .top?): noun = "top"
        case (.clothing, .bottom?): noun = "trousers"; plural = true
        case (.clothing, .onePiece?): noun = "dress"
        case (.clothing, .layer?): noun = "sweater"
        case (.clothing, .outerwear?): noun = "jacket"
        case (.clothing, nil): noun = "garment"
        case (.shoes, _): noun = "shoes"; plural = true
        case (.hats, _): noun = "hat"
        case (.scarves, _): noun = "scarf"
        case (.gloves, _): noun = "gloves"; plural = true
        case (.belts, _): noun = "belt"
        case (.bags, _): noun = "bag"
        case (.watches, _): noun = "watch"
        case (.rings, _): noun = "ring"
        case (.other, _): noun = "accessory"
        case (.cologne, _): return nil
        }
        let color = piece.colorName.map { $0.lowercased() + " " } ?? ""
        if plural { return color + noun }
        let phrase = color + noun
        return (startsWithVowelSound(phrase) ? "an " : "a ") + phrase
    }

    /// Keeps user notes short and free of prompt syntax.
    static func sanitized(_ notes: String) -> String {
        let allowed = notes.unicodeScalars.filter { scalar in
            CharacterSetLike.isAllowed(scalar)
        }
        let collapsed = String(String.UnicodeScalarView(allowed))
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
        return String(collapsed.prefix(120))
    }

    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }

    private static func startsWithVowelSound(_ phrase: String) -> Bool {
        guard let first = phrase.lowercased().first else { return false }
        return "aeio".contains(first)
    }
}

/// Letters, digits, spaces and basic punctuation; drops brackets, weights and other prompt syntax.
private enum CharacterSetLike {
    static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) { return true }
        return " ,.'-\n\t".unicodeScalars.contains(scalar)
    }
}
