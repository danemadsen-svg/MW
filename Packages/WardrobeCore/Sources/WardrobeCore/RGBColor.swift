/// An 8-bit-per-channel sRGB color, the unit for item color tags and the color dictionary.
///
/// Persisted as a packed `0xRRGGBB` integer and encoded in JSON as a `"#RRGGBB"` string.
public struct RGBColor: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Creates a color from a packed `0xRRGGBB` value. Returns `nil` outside `0...0xFFFFFF`.
    public init?(packed: Int) {
        guard (0...0xFFFFFF).contains(packed) else { return nil }
        self.init(
            red: UInt8((packed >> 16) & 0xFF),
            green: UInt8((packed >> 8) & 0xFF),
            blue: UInt8(packed & 0xFF)
        )
    }

    /// Parses `#RRGGBB`, `RRGGBB`, `#RGB` or `RGB` (case-insensitive, surrounding whitespace ignored).
    public init?(hex: String) {
        var digits = Substring(hex.trimmingWhitespace())
        if digits.hasPrefix("#") { digits = digits.dropFirst() }
        guard digits.allSatisfy(\.isHexDigit) else { return nil }

        switch digits.count {
        case 6:
            guard let value = Int(digits, radix: 16) else { return nil }
            self.init(packed: value)
        case 3:
            let expanded = digits.flatMap { [$0, $0] }
            guard let value = Int(String(expanded), radix: 16) else { return nil }
            self.init(packed: value)
        default:
            return nil
        }
    }

    public var packed: Int {
        Int(red) << 16 | Int(green) << 8 | Int(blue)
    }

    /// Uppercase `#RRGGBB`.
    public var hex: String {
        let digits = String(packed, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: 6 - digits.count) + digits
    }
}

extension RGBColor: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let color = RGBColor(hex: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hex color: \(string)"
            )
        }
        self = color
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

extension RGBColor: CustomStringConvertible {
    public var description: String { hex }
}

private extension String {
    func trimmingWhitespace() -> Substring {
        let start = firstIndex { !$0.isWhitespace } ?? endIndex
        let end = lastIndex { !$0.isWhitespace }.map(index(after:)) ?? start
        return self[start..<end]
    }
}
