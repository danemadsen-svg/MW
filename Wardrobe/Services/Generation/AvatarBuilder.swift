import CoreGraphics
import Foundation
import WardrobeCore

/// Diffusion settings for a render: the installed model and the device's tier settings.
struct DiffusionSetup: Sendable {
    let resourcesURL: URL
    let settings: RenderSettings
}

/// Builds the user's avatar from their own full-body photo (Chapter 4.4).
///
/// Likeness comes from the photo itself, not from per-user training or a face-identity model
/// (every face-ID adapter depends on non-commercial InsightFace weights). The person is cut out
/// with Vision, placed on a studio backdrop, lightly re-rendered with image-to-image to even out
/// light and background, and the original face is blended back so it stays exactly the user's.
/// Without diffusion (sketch-tier devices, or before the model is installed) the clean studio
/// cut-out is the avatar.
enum AvatarBuilder {
    /// How far image-to-image may move from the photo: enough to clean up, not to change the person.
    static let strength: Float = 0.32

    struct Output: Sendable {
        let imageData: Data
        let usedDiffusion: Bool
    }

    enum BuildError: LocalizedError {
        case unreadablePhoto
        case noPersonFound

        var errorDescription: String? {
            switch self {
            case .unreadablePhoto: "That photo couldn't be read. Try another one."
            case .noPersonFound: "No person was found in the full-body photo. Stand back so your whole body is in frame, in good light."
            }
        }
    }

    static func build(
        referencePhoto: Data,
        appearanceNotes: String,
        seed: UInt32,
        diffusion: DiffusionSetup?,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> Output {
        let size = ImageModelCatalog.default.resolution
        let canvas = try await Task.detached(priority: .userInitiated) { () throws -> CGImage in
            guard let photo = try? PhotoProcessor.cgImage(from: referencePhoto, maxPixelSize: 1536) else {
                throw BuildError.unreadablePhoto
            }
            guard let cutout = ImageCompositing.personCutout(from: photo) else { throw BuildError.noPersonFound }
            guard let canvas = ImageCompositing.studioCanvas(person: cutout, size: size) else { throw BuildError.unreadablePhoto }
            return canvas.image
        }.value

        guard let diffusion, diffusion.settings.tier != .sketchOnly else {
            return Output(imageData: try encode(canvas), usedDiffusion: false)
        }

        let request = DiffusionEngine.Request(
            prompt: RenderPrompt.avatar(appearanceNotes: appearanceNotes),
            negativePrompt: RenderPrompt.negative,
            startingImage: canvas,
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
            guard let face = ImageCompositing.faceRect(in: canvas),
                  let merged = ImageCompositing.pasteBack(face, from: canvas, onto: generated)
            else { return generated }
            return merged
        }.value
        return Output(imageData: try encode(merged), usedDiffusion: true)
    }

    static func encode(_ image: CGImage) throws -> Data {
        guard let data = ImageCompositing.jpegData(image) else { throw BuildError.unreadablePhoto }
        return data
    }
}
