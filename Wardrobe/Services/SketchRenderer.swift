import UIKit
import WardrobeCore

/// Draws the low-fidelity "sketch preview" of an outfit (Chapter 5.4): a flat-lay lookbook of the
/// item photos arranged by `SketchLayout`. Works on every device with no image generation.
///
/// Pure drawing with no main-actor state, so call it off the main actor.
enum SketchRenderer {
    static func render(pieces: [(SketchLayout.Piece, Data?)], size: CGSize) -> UIImage {
        render(pieces: pieces, fillColors: [:], size: size)
    }

    /// `fillColors` (usually each item's primary color) fills the placeholder of items without a
    /// photo; items missing from it use the raised surface color.
    static func render(pieces: [(SketchLayout.Piece, Data?)], fillColors: [UUID: RGBColor], size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let piecesByID = Dictionary(pieces.map { ($0.0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let slots = SketchLayout.layout(pieces.map { $0.0 })
        // Tokens are in screen points; scale them so the image matches the app at phone width.
        let unit = max(size.width, 1) / 390

        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(Theme.Palette.background).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            for slot in slots {
                guard let entry = piecesByID[slot.itemID] else { continue }
                let (piece, data) = entry
                let frame = CGRect(
                    x: slot.frame.x * size.width,
                    y: slot.frame.y * size.height,
                    width: slot.frame.width * size.width,
                    height: slot.frame.height * size.height
                )
                if let data, let photo = UIImage(data: data), photo.size.width > 0, photo.size.height > 0 {
                    drawPhoto(photo, in: frame, cornerRadius: Theme.Radius.m * unit, context: cg)
                } else {
                    drawPlaceholder(for: piece, fill: fillColors[piece.id], in: frame, unit: unit, context: cg)
                }
            }
        }
    }

    // MARK: - Drawing

    private static func drawPhoto(_ photo: UIImage, in frame: CGRect, cornerRadius: CGFloat, context: CGContext) {
        let rect = aspectFit(photo.size, in: frame)
        context.saveGState()
        context.addPath(roundedPath(rect, cornerRadius: cornerRadius))
        context.clip()
        photo.draw(in: rect)
        context.restoreGState()
    }

    private static func drawPlaceholder(for piece: SketchLayout.Piece, fill: RGBColor?, in frame: CGRect, unit: CGFloat, context: CGContext) {
        let rect = frame.insetBy(dx: Theme.Spacing.xs * unit, dy: Theme.Spacing.xs * unit)
        guard rect.width > 0, rect.height > 0 else { return }
        let path = roundedPath(rect, cornerRadius: Theme.Radius.m * unit)

        context.setFillColor((fill.map(uiColor) ?? UIColor(Theme.Palette.surfaceRaised)).cgColor)
        context.addPath(path)
        context.fillPath()

        // Hairline border so dark fills stay visible on the dark background (as in ColorSwatchView).
        context.setStrokeColor(UIColor(Theme.Palette.textPrimary).withAlphaComponent(0.25).cgColor)
        context.setLineWidth(unit)
        context.addPath(path)
        context.strokePath()

        let symbolColor: UIColor
        if let fill {
            symbolColor = isLight(fill) ? UIColor(Theme.Palette.background) : UIColor(Theme.Palette.textPrimary)
        } else {
            symbolColor = UIColor(Theme.Palette.textSecondary)
        }
        let pointSize = min(rect.width, rect.height) * 0.4
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let symbol = UIImage(systemName: piece.category.systemImage, withConfiguration: configuration)?
            .withTintColor(symbolColor, renderingMode: .alwaysOriginal),
            symbol.size.width > 0, symbol.size.height > 0
        else { return }
        let box = CGRect(x: rect.midX - pointSize / 2, y: rect.midY - pointSize / 2, width: pointSize, height: pointSize)
        symbol.draw(in: aspectFit(symbol.size, in: box))
    }

    // MARK: - Geometry and color

    /// The largest rect with `size`'s aspect ratio that fits in `frame`, centered.
    private static func aspectFit(_ size: CGSize, in frame: CGRect) -> CGRect {
        let scale = min(frame.width / size.width, frame.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: frame.midX - fitted.width / 2, y: frame.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    }

    /// `CGPath(roundedRect:)` traps when the radius exceeds half the rect, so clamp it.
    private static func roundedPath(_ rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let radius = max(0, min(cornerRadius, rect.width / 2, rect.height / 2))
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    private static func uiColor(_ color: RGBColor) -> UIColor {
        UIColor(red: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255, blue: CGFloat(color.blue) / 255, alpha: 1)
    }

    private static func isLight(_ color: RGBColor) -> Bool {
        let luma = 0.299 * Double(color.red) + 0.587 * Double(color.green) + 0.114 * Double(color.blue)
        return luma > 150
    }
}
