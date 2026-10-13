import Foundation

/// A CIE L*a*b* color (D65 white point), used for perceptual color distance.
public struct LabColor: Hashable, Sendable {
    public var l: Double
    public var a: Double
    public var b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    /// Chroma, C*ab. Near zero for greys, black and white.
    public var chroma: Double { (a * a + b * b).squareRoot() }

    /// Hue angle h_ab in degrees, `0..<360`. Meaningless when chroma is near zero.
    public var hueDegrees: Double {
        let degrees = atan2(b, a) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}

extension LabColor {
    /// Converts an 8-bit sRGB color to L*a*b* via linear RGB and CIE XYZ (D65).
    public init(_ rgb: RGBColor) {
        func linearize(_ channel: UInt8) -> Double {
            let c = Double(channel) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linearize(rgb.red)
        let g = linearize(rgb.green)
        let b = linearize(rgb.blue)

        // sRGB → XYZ (D65), IEC 61966-2-1.
        let x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b

        // D65 reference white.
        let xn = 0.95047, yn = 1.0, zn = 1.08883
        func f(_ t: Double) -> Double {
            let delta = 6.0 / 29.0
            return t > delta * delta * delta ? cbrt(t) : t / (3 * delta * delta) + 4.0 / 29.0
        }
        let fx = f(x / xn), fy = f(y / yn), fz = f(z / zn)
        self.init(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    /// CIEDE2000 color difference (kL = kC = kH = 1). About 1 is a just-noticeable difference;
    /// above about 10 colors read as clearly different.
    public func deltaE2000(_ other: LabColor) -> Double {
        let (l1, a1, b1) = (l, a, b)
        let (l2, a2, b2) = (other.l, other.a, other.b)

        let c1 = (a1 * a1 + b1 * b1).squareRoot()
        let c2 = (a2 * a2 + b2 * b2).squareRoot()
        let cBar = (c1 + c2) / 2
        let cBar7 = pow(cBar, 7)
        let g = 0.5 * (1 - (cBar7 / (cBar7 + pow(25, 7))).squareRoot())

        let a1p = (1 + g) * a1
        let a2p = (1 + g) * a2
        let c1p = (a1p * a1p + b1 * b1).squareRoot()
        let c2p = (a2p * a2p + b2 * b2).squareRoot()

        func hueAngle(_ b: Double, _ ap: Double) -> Double {
            if b == 0 && ap == 0 { return 0 }
            let h = atan2(b, ap) * 180 / .pi
            return h < 0 ? h + 360 : h
        }
        let h1p = hueAngle(b1, a1p)
        let h2p = hueAngle(b2, a2p)

        let deltaLp = l2 - l1
        let deltaCp = c2p - c1p

        var deltahp = 0.0
        if c1p * c2p != 0 {
            let diff = h2p - h1p
            if abs(diff) <= 180 {
                deltahp = diff
            } else if diff > 180 {
                deltahp = diff - 360
            } else {
                deltahp = diff + 360
            }
        }
        let deltaHp = 2 * (c1p * c2p).squareRoot() * sin(radians(deltahp / 2))

        let lBarp = (l1 + l2) / 2
        let cBarp = (c1p + c2p) / 2

        var hBarp = h1p + h2p
        if c1p * c2p != 0 {
            if abs(h1p - h2p) <= 180 {
                hBarp = (h1p + h2p) / 2
            } else if h1p + h2p < 360 {
                hBarp = (h1p + h2p + 360) / 2
            } else {
                hBarp = (h1p + h2p - 360) / 2
            }
        }

        let t = 1
            - 0.17 * cos(radians(hBarp - 30))
            + 0.24 * cos(radians(2 * hBarp))
            + 0.32 * cos(radians(3 * hBarp + 6))
            - 0.20 * cos(radians(4 * hBarp - 63))

        let deltaTheta = 30 * exp(-pow((hBarp - 275) / 25, 2))
        let cBarp7 = pow(cBarp, 7)
        let rc = 2 * (cBarp7 / (cBarp7 + pow(25, 7))).squareRoot()
        let lBarpMinus50Sq = pow(lBarp - 50, 2)
        let sl = 1 + (0.015 * lBarpMinus50Sq) / (20 + lBarpMinus50Sq).squareRoot()
        let sc = 1 + 0.045 * cBarp
        let sh = 1 + 0.015 * cBarp * t
        let rt = -sin(radians(2 * deltaTheta)) * rc

        let termL = deltaLp / sl
        let termC = deltaCp / sc
        let termH = deltaHp / sh
        return (termL * termL + termC * termC + termH * termH + rt * termC * termH).squareRoot()
    }
}

@inline(__always)
private func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
