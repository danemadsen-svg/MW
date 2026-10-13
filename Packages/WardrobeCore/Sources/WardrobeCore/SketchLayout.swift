import Foundation

/// A rectangle in normalized canvas coordinates: (0, 0) is the top-left, (1, 1) the bottom-right.
public struct UnitRect: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }

    public func intersects(_ other: UnitRect) -> Bool {
        x < other.maxX && other.x < maxX && y < other.maxY && other.y < maxY
    }
}

/// Where one item sits in a sketch preview.
public struct SketchSlot: Hashable, Sendable {
    public let itemID: UUID
    public let frame: UnitRect
    /// Draw lower values first.
    public let zIndex: Int
}

/// Lays out an outfit as a flat-lay lookbook for the low-fidelity "sketch preview": the outfit
/// reads top to bottom down the center (hat, top or one-piece, bottom, shoes), layers and
/// outerwear sit to the left, and accessories stack on the right. Works on any device, with no
/// image generation. Design for a 3:4 portrait canvas.
public enum SketchLayout {
    public struct Piece: Hashable, Sendable {
        public let id: UUID
        public let category: ItemCategory
        public let clothingType: ClothingType?

        public init(id: UUID, category: ItemCategory, clothingType: ClothingType? = nil) {
            self.id = id
            self.category = category
            self.clothingType = clothingType
        }
    }

    static let center = (x: 0.30, width: 0.40)
    static let left = (x: 0.02, width: 0.26)
    static let right = (x: 0.72, width: 0.26)

    public static func layout(_ pieces: [Piece]) -> [SketchSlot] {
        var slots: [SketchSlot] = []
        var sidePieces: [Piece] = []
        var leftUsed = 0
        var takenCenter = Set<String>()

        func place(_ piece: Piece, _ frame: UnitRect, z: Int) {
            slots.append(SketchSlot(itemID: piece.id, frame: frame, zIndex: z))
        }

        for piece in pieces {
            switch (piece.category, piece.clothingType) {
            case (.hats, _) where !takenCenter.contains("hat"):
                takenCenter.insert("hat")
                place(piece, UnitRect(x: 0.38, y: 0.02, width: 0.24, height: 0.11), z: 3)
            case (.clothing, .onePiece) where !takenCenter.contains("torso") && !takenCenter.contains("legs"):
                takenCenter.formUnion(["torso", "legs"])
                place(piece, UnitRect(x: center.x, y: 0.15, width: center.width, height: 0.61), z: 1)
            case (.clothing, .top) where !takenCenter.contains("torso"):
                takenCenter.insert("torso")
                place(piece, UnitRect(x: center.x, y: 0.15, width: center.width, height: 0.30), z: 2)
            case (.clothing, .bottom) where !takenCenter.contains("legs"):
                takenCenter.insert("legs")
                place(piece, UnitRect(x: center.x, y: 0.46, width: center.width, height: 0.30), z: 1)
            case (.shoes, _) where !takenCenter.contains("feet"):
                takenCenter.insert("feet")
                place(piece, UnitRect(x: center.x + 0.04, y: 0.79, width: center.width - 0.08, height: 0.18), z: 1)
            case (.clothing, .outerwear), (.clothing, .layer):
                if leftUsed < 2 {
                    let y = leftUsed == 0 ? 0.15 : 0.50
                    place(piece, UnitRect(x: left.x, y: y, width: left.width, height: 0.33), z: 1)
                    leftUsed += 1
                } else {
                    sidePieces.append(piece)
                }
            default:
                sidePieces.append(piece)
            }
        }

        // Accessories (and any overflow) stack down the right column, cologne last.
        let ordered = sidePieces.filter { $0.category != .cologne } + sidePieces.filter { $0.category == .cologne }
        if !ordered.isEmpty {
            let gap = 0.02
            let available = 0.93
            let height = min(0.18, (available - gap * Double(ordered.count - 1)) / Double(ordered.count))
            for (index, piece) in ordered.enumerated() {
                let y = 0.04 + Double(index) * (height + gap)
                place(piece, UnitRect(x: right.x, y: y, width: right.width, height: height), z: 1)
            }
        }
        return slots.sorted { $0.zIndex < $1.zIndex }
    }
}
