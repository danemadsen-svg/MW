import Foundation

/// A point in normalized image coordinates: (0, 0) top-left, (1, 1) bottom-right.
public struct UnitPoint2D: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    static func midpoint(_ a: UnitPoint2D, _ b: UnitPoint2D) -> UnitPoint2D {
        UnitPoint2D(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

/// Body joints detected in a full-body photo (from Vision's human body pose request, converted
/// to top-left origin). Any joint may be missing.
public struct BodyKeypoints: Hashable, Sendable {
    public var nose: UnitPoint2D?
    public var neck: UnitPoint2D?
    public var leftShoulder: UnitPoint2D?
    public var rightShoulder: UnitPoint2D?
    public var leftHip: UnitPoint2D?
    public var rightHip: UnitPoint2D?
    public var leftKnee: UnitPoint2D?
    public var rightKnee: UnitPoint2D?
    public var leftAnkle: UnitPoint2D?
    public var rightAnkle: UnitPoint2D?

    public init(
        nose: UnitPoint2D? = nil, neck: UnitPoint2D? = nil,
        leftShoulder: UnitPoint2D? = nil, rightShoulder: UnitPoint2D? = nil,
        leftHip: UnitPoint2D? = nil, rightHip: UnitPoint2D? = nil,
        leftKnee: UnitPoint2D? = nil, rightKnee: UnitPoint2D? = nil,
        leftAnkle: UnitPoint2D? = nil, rightAnkle: UnitPoint2D? = nil
    ) {
        self.nose = nose
        self.neck = neck
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.leftHip = leftHip
        self.rightHip = rightHip
        self.leftKnee = leftKnee
        self.rightKnee = rightKnee
        self.leftAnkle = leftAnkle
        self.rightAnkle = rightAnkle
    }
}

/// Where each garment goes when composing a try-on image over the avatar.
public struct GarmentPlacement: Hashable, Sendable {
    public let itemID: UUID
    public let frame: UnitRect
    /// Draw lower values first (outerwear over the top, accessories last).
    public let zIndex: Int
}

/// Maps outfit pieces onto body regions of the avatar. Uses detected joints when available and
/// standard figure proportions within the person's bounding box otherwise, so a placement always
/// exists. Pure geometry, so it's tested without Vision.
public enum BodyLayout {
    /// Body regions in normalized coordinates.
    public struct Regions: Hashable, Sendable {
        public let head: UnitRect
        public let neck: UnitRect
        public let torso: UnitRect
        public let legs: UnitRect
        public let fullBody: UnitRect
        public let feet: UnitRect
        public let waist: UnitRect
        public let leftHand: UnitRect
        public let rightHand: UnitRect
        public let leftWrist: UnitRect
    }

    /// Regions from joints, falling back to proportions of `personBounds` (the person's box in
    /// the image; defaults to a centered full-height figure).
    public static func regions(for keypoints: BodyKeypoints, personBounds: UnitRect = UnitRect(x: 0.25, y: 0.03, width: 0.5, height: 0.94)) -> Regions {
        let b = personBounds
        func proportional(_ fy: Double) -> Double { b.y + b.height * fy }

        let shoulderY = average(keypoints.leftShoulder?.y, keypoints.rightShoulder?.y) ?? proportional(0.19)
        let hipY = average(keypoints.leftHip?.y, keypoints.rightHip?.y) ?? proportional(0.50)
        let ankleY = average(keypoints.leftAnkle?.y, keypoints.rightAnkle?.y) ?? proportional(0.94)
        let headTop = max(0, (keypoints.nose?.y).map { $0 - (shoulderY - $0) * 1.1 } ?? b.y)
        let centerX = average(keypoints.neck?.x, average(keypoints.leftHip?.x, keypoints.rightHip?.x)) ?? (b.x + b.width / 2)

        let shoulderWidth: Double = {
            if let l = keypoints.leftShoulder, let r = keypoints.rightShoulder { return abs(l.x - r.x) }
            return b.width * 0.42
        }()
        let torsoWidth = clamp(shoulderWidth * 1.45, 0.08, 0.9)
        let legWidth = clamp(shoulderWidth * 1.15, 0.06, 0.8)

        let headHeight = max(0.04, shoulderY - headTop)
        let head = rect(centerX: centerX, top: headTop - headHeight * 0.15, width: headHeight * 1.05, height: headHeight * 0.75)
        let neck = rect(centerX: centerX, top: shoulderY - headHeight * 0.25, width: shoulderWidth * 0.9, height: headHeight * 0.45)
        let torsoTop = shoulderY - headHeight * 0.08
        let torso = rect(centerX: centerX, top: torsoTop, width: torsoWidth, height: (hipY - torsoTop) * 1.12)
        let legsTop = hipY - (hipY - shoulderY) * 0.06
        let legs = rect(centerX: centerX, top: legsTop, width: legWidth, height: max(0.05, ankleY - legsTop))
        let fullBody = rect(centerX: centerX, top: torsoTop, width: torsoWidth, height: max(0.1, ankleY - torsoTop) * 0.92)
        let feetHeight = max(0.03, (ankleY - hipY) * 0.16)
        let feet = rect(centerX: centerX, top: ankleY - feetHeight * 0.35, width: legWidth * 1.1, height: feetHeight)
        let waist = rect(centerX: centerX, top: hipY - (hipY - shoulderY) * 0.08, width: torsoWidth * 0.85, height: (hipY - shoulderY) * 0.12)
        let handSize = shoulderWidth * 0.55
        let handY = hipY - handSize * 0.2
        let leftHand = rect(centerX: centerX + torsoWidth * 0.62, top: handY, width: handSize, height: handSize * 1.1)
        let rightHand = rect(centerX: centerX - torsoWidth * 0.62, top: handY, width: handSize, height: handSize * 1.1)
        let leftWrist = rect(centerX: centerX + torsoWidth * 0.55, top: handY - handSize * 0.3, width: handSize * 0.45, height: handSize * 0.35)

        return Regions(
            head: head, neck: neck, torso: torso, legs: legs, fullBody: fullBody, feet: feet,
            waist: waist, leftHand: leftHand, rightHand: rightHand, leftWrist: leftWrist
        )
    }

    /// Placements for the pieces that are drawn onto the body. Cologne and pieces beyond one per
    /// region are left out (they don't show on a person).
    public static func placements(for pieces: [SketchLayout.Piece], regions: Regions) -> [GarmentPlacement] {
        var result: [GarmentPlacement] = []
        var used = Set<String>()

        func place(_ piece: SketchLayout.Piece, _ region: String, _ frame: UnitRect, _ z: Int) {
            guard used.insert(region).inserted else { return }
            result.append(GarmentPlacement(itemID: piece.id, frame: frame, zIndex: z))
        }

        for piece in pieces {
            switch (piece.category, piece.clothingType) {
            case (.clothing, .onePiece):
                if !used.contains("torso") && !used.contains("legs") {
                    used.formUnion(["torso", "legs"])
                    result.append(GarmentPlacement(itemID: piece.id, frame: regions.fullBody, zIndex: 2))
                }
            case (.clothing, .top): place(piece, "torso", regions.torso, 3)
            case (.clothing, .bottom): place(piece, "legs", regions.legs, 1)
            case (.clothing, .layer): place(piece, "layer", inset(regions.torso, by: -0.04), 4)
            case (.clothing, .outerwear): place(piece, "outerwear", inset(regions.torso, by: -0.08, extendBottom: 0.15), 5)
            case (.shoes, _): place(piece, "feet", regions.feet, 2)
            case (.hats, _): place(piece, "head", regions.head, 7)
            case (.scarves, _): place(piece, "neck", regions.neck, 6)
            case (.belts, _): place(piece, "waist", regions.waist, 6)
            case (.bags, _): place(piece, "hand", regions.rightHand, 8)
            case (.gloves, _): place(piece, "gloves", regions.leftHand, 8)
            case (.watches, _): place(piece, "wrist", regions.leftWrist, 9)
            default: continue
            }
        }
        return result.sorted { $0.zIndex < $1.zIndex }
    }

    // MARK: - Geometry

    private static func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (a?, b?): (a + b) / 2
        case let (a?, nil): a
        case let (nil, b?): b
        default: nil
        }
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    /// A rect centered horizontally on `centerX`, clamped into the unit square.
    private static func rect(centerX: Double, top: Double, width: Double, height: Double) -> UnitRect {
        let w = clamp(width, 0.01, 1)
        let h = clamp(height, 0.01, 1)
        let x = clamp(centerX - w / 2, 0, 1 - w)
        let y = clamp(top, 0, 1 - h)
        return UnitRect(x: x, y: y, width: w, height: h)
    }

    private static func inset(_ r: UnitRect, by amount: Double, extendBottom: Double = 0) -> UnitRect {
        rect(centerX: r.x + r.width / 2, top: r.y + amount / 2, width: r.width - amount * 2, height: r.height - amount + extendBottom)
    }
}
