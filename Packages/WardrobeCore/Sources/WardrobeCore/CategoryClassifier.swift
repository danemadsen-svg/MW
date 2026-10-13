/// A guess at what an item is, from an image classifier's labels.
public struct CategorySuggestion: Hashable, Sendable {
    public let category: ItemCategory
    public let clothingType: ClothingType?
    /// 0...1. Summed classifier confidence of the labels that support this guess, capped at 1.
    public let confidence: Double
    /// The classifier labels that led here, strongest first.
    public let evidence: [String]
}

/// Maps free-form image-classifier labels (such as Vision's `VNClassifyImageRequest` identifiers,
/// e.g. "jeans", "sneaker", "wristwatch") onto wardrobe categories.
///
/// Matching is keyword-based on whole words, so it tolerates taxonomy changes between OS
/// releases: "running_shoe", "Running Shoe" and "shoe" all land on `.shoes`.
public struct CategoryClassifier: Sendable {
    public struct Rule: Hashable, Sendable {
        /// One or more whole words that must appear consecutively in the label.
        public let phrase: [String]
        public let category: ItemCategory
        public let clothingType: ClothingType?

        public init(_ phrase: String, _ category: ItemCategory, _ clothingType: ClothingType? = nil) {
            self.phrase = CategoryClassifier.words(phrase)
            self.category = category
            self.clothingType = clothingType
        }
    }

    /// Ordered most-specific first; the first matching rule wins for a label.
    public static let rules: [Rule] = [
        // Phrases that would otherwise hit a broader single word.
        Rule("dress shirt", .clothing, .top), Rule("t shirt", .clothing, .top), Rule("polo shirt", .clothing, .top),
        Rule("sport coat", .clothing, .outerwear), Rule("suit jacket", .clothing, .outerwear),
        Rule("rain coat", .clothing, .outerwear), Rule("trench coat", .clothing, .outerwear),
        Rule("dress shoe", .shoes), Rule("running shoe", .shoes), Rule("tennis shoe", .shoes),
        Rule("bow tie", .other), Rule("neck tie", .other), Rule("watch band", .watches),
        Rule("baseball cap", .hats), Rule("cowboy hat", .hats), Rule("wedding ring", .rings),
        Rule("engagement ring", .rings), Rule("eau de toilette", .cologne), Rule("eau de parfum", .cologne),
        Rule("sports bra", .clothing, .top), Rule("tank top", .clothing, .top),
        Rule("denim jacket", .clothing, .outerwear), Rule("jean jacket", .clothing, .outerwear),
        Rule("leather jacket", .clothing, .outerwear), Rule("denim shirt", .clothing, .top),
        Rule("swimsuit", .clothing, .onePiece), Rule("suit", .clothing, .outerwear),

        // Tops
        Rule("shirt", .clothing, .top), Rule("tshirt", .clothing, .top), Rule("blouse", .clothing, .top),
        Rule("polo", .clothing, .top), Rule("tee", .clothing, .top), Rule("jersey", .clothing, .top),
        Rule("top", .clothing, .top), Rule("tunic", .clothing, .top), Rule("camisole", .clothing, .top),
        // Bottoms
        Rule("jeans", .clothing, .bottom), Rule("denim", .clothing, .bottom), Rule("trousers", .clothing, .bottom),
        Rule("pants", .clothing, .bottom), Rule("shorts", .clothing, .bottom), Rule("skirt", .clothing, .bottom),
        Rule("chinos", .clothing, .bottom), Rule("leggings", .clothing, .bottom), Rule("slacks", .clothing, .bottom),
        // One-pieces
        Rule("dress", .clothing, .onePiece), Rule("gown", .clothing, .onePiece), Rule("jumpsuit", .clothing, .onePiece),
        Rule("romper", .clothing, .onePiece), Rule("overalls", .clothing, .onePiece),
        // Layers
        Rule("sweater", .clothing, .layer), Rule("cardigan", .clothing, .layer), Rule("hoodie", .clothing, .layer),
        Rule("sweatshirt", .clothing, .layer), Rule("vest", .clothing, .layer), Rule("waistcoat", .clothing, .layer),
        Rule("pullover", .clothing, .layer), Rule("jumper", .clothing, .layer), Rule("knitwear", .clothing, .layer),
        // Outerwear
        Rule("coat", .clothing, .outerwear), Rule("jacket", .clothing, .outerwear), Rule("blazer", .clothing, .outerwear),
        Rule("parka", .clothing, .outerwear), Rule("raincoat", .clothing, .outerwear), Rule("windbreaker", .clothing, .outerwear),
        Rule("overcoat", .clothing, .outerwear), Rule("poncho", .clothing, .outerwear), Rule("anorak", .clothing, .outerwear),

        // Shoes
        Rule("shoe", .shoes), Rule("shoes", .shoes), Rule("sneaker", .shoes), Rule("sneakers", .shoes),
        Rule("boot", .shoes), Rule("boots", .shoes), Rule("sandal", .shoes), Rule("sandals", .shoes),
        Rule("loafer", .shoes), Rule("loafers", .shoes), Rule("heels", .shoes), Rule("footwear", .shoes),
        Rule("slipper", .shoes), Rule("clog", .shoes), Rule("moccasin", .shoes), Rule("oxford", .shoes),
        // Hats
        Rule("hat", .hats), Rule("cap", .hats), Rule("beanie", .hats), Rule("fedora", .hats),
        Rule("headwear", .hats), Rule("beret", .hats), Rule("bonnet", .hats), Rule("sombrero", .hats),
        // Scarves
        Rule("scarf", .scarves), Rule("scarves", .scarves), Rule("shawl", .scarves), Rule("bandana", .scarves),
        Rule("stole", .scarves), Rule("muffler", .scarves),
        // Gloves
        Rule("glove", .gloves), Rule("gloves", .gloves), Rule("mitten", .gloves), Rule("mittens", .gloves),
        // Belts
        Rule("belt", .belts), Rule("buckle", .belts),
        // Bags
        Rule("bag", .bags), Rule("handbag", .bags), Rule("purse", .bags), Rule("backpack", .bags),
        Rule("tote", .bags), Rule("satchel", .bags), Rule("wallet", .bags), Rule("briefcase", .bags),
        Rule("clutch", .bags), Rule("luggage", .bags), Rule("suitcase", .bags),
        // Watches
        Rule("watch", .watches), Rule("wristwatch", .watches), Rule("timepiece", .watches),
        Rule("chronograph", .watches), Rule("smartwatch", .watches),
        // Rings
        Rule("ring", .rings), Rule("rings", .rings),
        // Cologne
        Rule("perfume", .cologne), Rule("cologne", .cologne), Rule("fragrance", .cologne), Rule("atomizer", .cologne),
        // Other accessories
        Rule("necktie", .other), Rule("tie", .other), Rule("necklace", .other), Rule("bracelet", .other),
        Rule("earring", .other), Rule("earrings", .other), Rule("sunglasses", .other), Rule("eyeglasses", .other),
        Rule("glasses", .other), Rule("jewelry", .other), Rule("jewellery", .other), Rule("brooch", .other),
        Rule("cufflink", .other), Rule("cufflinks", .other), Rule("pendant", .other), Rule("umbrella", .other),
    ]

    /// Labels below this confidence are ignored.
    public var minimumLabelConfidence = 0.05

    public init() {}

    /// Ranked suggestions, best first. Empty when no label looks like a wardrobe item.
    public func suggestions(for labels: [(identifier: String, confidence: Double)]) -> [CategorySuggestion] {
        struct Key: Hashable {
            let category: ItemCategory
            let clothingType: ClothingType?
        }
        var totals: [Key: Double] = [:]
        var evidence: [Key: [(String, Double)]] = [:]

        for label in labels where label.confidence >= minimumLabelConfidence {
            guard let rule = Self.rule(for: label.identifier) else { continue }
            let key = Key(category: rule.category, clothingType: rule.clothingType)
            totals[key, default: 0] += label.confidence
            evidence[key, default: []].append((label.identifier, label.confidence))
        }

        return totals
            .map { key, total in
                CategorySuggestion(
                    category: key.category,
                    clothingType: key.clothingType,
                    confidence: min(1, total),
                    evidence: (evidence[key] ?? []).sorted { $0.1 > $1.1 }.map(\.0)
                )
            }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
                return lhs.category.rawValue < rhs.category.rawValue
            }
    }

    /// The first rule whose phrase appears as consecutive whole words in the label.
    public static func rule(for label: String) -> Rule? {
        let labelWords = words(label)
        guard !labelWords.isEmpty else { return nil }
        return rules.first { rule in
            guard rule.phrase.count <= labelWords.count else { return false }
            for start in 0...(labelWords.count - rule.phrase.count)
            where Array(labelWords[start..<start + rule.phrase.count]) == rule.phrase {
                return true
            }
            return false
        }
    }

    /// Lowercased words, splitting on anything that isn't a letter or digit.
    static func words(_ text: String) -> [String] {
        text.lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
    }
}
