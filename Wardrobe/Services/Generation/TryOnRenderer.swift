import CoreGraphics
import Foundation
import WardrobeCore

/// Renders an outfit on the user's avatar (Chapter 5), entirely on device.
///
/// 1. Compose: find the avatar's body joints with Vision, cut each garment out of its catalog
///    photo, and place it on the matching body region (`BodyLayout`). This "quick preview" works
///    on every device.
/// 2. Blend (diffusion tiers): image-to-image over the composite with a prompt describing the
///    outfit, so the pieces sit naturally on the body, then the avatar's face is blended back.
///
/// No commercially licensed virtual try-on model has a Core ML port yet (the academic ones are
/// non-commercial); FASHN VTON v1.5 (Apache-2.0) is the planned upgrade behind this same entry
/// point once converted. See docs/LICENSING.md.
enum TryOnRenderer {
    static let strength: Float = 0.5

    struct Garment: Sendable {
        let piece: SketchLayout.Piece
        let photoData: Data?
        let color: RGBColor?
    }

    struct Output: Sendable {
        let imageData: Data
        let kind: RenderKind
    }

    enum RenderError: LocalizedError {
        case unreadableAvatar
        case nothingToWear

        var errorDescription: String? {
            switch self {
            case .unreadableAvatar: "Your avatar couldn't be read. Try rebuilding it."
            case .nothingToWear: "This outfit has no pieces that show on a person."
            }
        }
    }

    static func render(
        avatar avatarData: Data,
        garments: [Garment],
        appearanceNotes: String,
        seed: UInt32,
        diffusion: DiffusionSetup?,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> Output {
        let size = ImageModelCatalog.default.resolution
        let (avatar, composite) = try await Task.detached(priority: .userInitiated) { () throws -> (CGImage, CGImage) in
            guard let decoded = try? PhotoProcessor.cgImage(from: avatarData, maxPixelSize: size),
                  let avatar = ImageCompositing.resized(decoded, to: size)
            else { throw RenderError.unreadableAvatar }
            guard let composite = compose(avatar: avatar, garments: garments, size: size) else { throw RenderError.nothingToWear }
            return (avatar, composite)
        }.value

        guard let diffusion, diffusion.settings.tier != .sketchOnly else {
            return Output(imageData: try encode(composite), kind: .composite)
        }

        let prompt = RenderPrompt.tryOn(
            pieces: garments.map { garment in
                RenderPrompt.Piece(
                    category: garment.piece.category,
                    clothingType: garment.piece.clothingType,
                    colorName: garment.color.map { GarmentSwatches.nearest(to: $0).name }
                )
            },
            appearanceNotes: appearanceNotes
        )
        let request = DiffusionEngine.Request(
            prompt: prompt,
            negativePrompt: RenderPrompt.negative,
            startingImage: composite,
            strength: strength,
            stepCount: diffusion.settings.stepCount,
            seed: seed
        )
        let generated = try await DiffusionEngine.shared.generate(
            request,
            resourcesURL: diffusion.resourcesURL,
            reduceMemory: diffusion.settings.reduceMemory,
            progress: progress
        )
        let merged = await Task.detached(priority: .userInitiated) { () -> CGImage in
            guard let face = ImageCompositing.faceRect(in: avatar),
                  let merged = ImageCompositing.pasteBack(face, from: avatar, onto: generated)
            else { return generated }
            return merged
        }.value
        return Output(imageData: try encode(merged), kind: .diffusion)
    }

    /// Draws the garments onto the avatar. `nil` when nothing in the outfit shows on a person.
    static func compose(avatar: CGImage, garments: [Garment], size: Int) -> CGImage? {
        let keypoints = ImageCompositing.bodyKeypoints(in: avatar) ?? BodyKeypoints()
        let personBounds = ImageCompositing.personCutout(from: avatar).flatMap(ImageCompositing.opaqueBounds(of:))
        let regions = personBounds.map { BodyLayout.regions(for: keypoints, personBounds: $0) } ?? BodyLayout.regions(for: keypoints)
        let placements = BodyLayout.placements(for: garments.map(\.piece), regions: regions)
        guard !placements.isEmpty, let context = ImageCompositing.makeContext(width: size, height: size) else { return nil }

        let canvas = CGFloat(size)
        context.interpolationQuality = .high
        context.draw(avatar, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))

        let garmentsByID = Dictionary(garments.map { ($0.piece.id, $0) }, uniquingKeysWith: { first, _ in first })
        for placement in placements {
            guard let garment = garmentsByID[placement.itemID] else { continue }
            // Normalized top-left frame to Core Graphics' bottom-left coordinates.
            let frame = CGRect(
                x: placement.frame.x * canvas,
                y: (1 - placement.frame.maxY) * canvas,
                width: placement.frame.width * canvas,
                height: placement.frame.height * canvas
            )
            if let data = garment.photoData, let cutout = ImageCompositing.garmentCutout(from: data) {
                context.draw(cutout, in: aspectFit(CGSize(width: cutout.width, height: cutout.height), in: frame))
            } else if let color = garment.color {
                context.setFillColor(CGColor(srgbRed: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255, blue: CGFloat(color.blue) / 255, alpha: 0.9))
                let radius = min(frame.width, frame.height) * 0.18
                context.addPath(CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil))
                context.fillPath()
            }
        }
        return context.makeImage()
    }

    private static func aspectFit(_ size: CGSize, in frame: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return frame }
        let scale = min(frame.width / size.width, frame.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: frame.midX - fitted.width / 2, y: frame.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    }

    private static func encode(_ image: CGImage) throws -> Data {
        guard let data = ImageCompositing.jpegData(image) else { throw RenderError.unreadableAvatar }
        return data
    }
}
