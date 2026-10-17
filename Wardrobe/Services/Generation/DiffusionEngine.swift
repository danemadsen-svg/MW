import CoreGraphics
import CoreML
import Foundation
import StableDiffusion

/// Runs Stable Diffusion on device through Apple's Core ML pipeline (Chapter 4.3).
///
/// Generation is synchronous and takes tens of seconds, so it runs on a dedicated serial queue
/// rather than the Swift concurrency pool. One pipeline is kept loaded between requests and
/// unloaded on memory pressure or when the settings change.
final class DiffusionEngine: @unchecked Sendable {
    static let shared = DiffusionEngine()

    struct Request: Sendable {
        var prompt: String
        var negativePrompt: String
        /// Image-to-image source at the model's resolution. `nil` for text-to-image.
        var startingImage: CGImage?
        /// 0...1: how far the result may move from `startingImage`.
        var strength: Float
        var stepCount: Int
        var seed: UInt32
        var guidanceScale: Float = 7.0
    }

    enum EngineError: Error, LocalizedError {
        case modelMissing
        /// The model's safety checker withheld the image.
        case filtered
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .modelMissing: "The image model isn't installed yet."
            case .filtered: "The result was withheld by the safety filter. Try different photos or regenerate."
            case .cancelled: "Cancelled."
            case .failed(let reason): "Rendering failed: \(reason)"
            }
        }
    }

    private let queue = DispatchQueue(label: "com.danemadsen.wardrobe.diffusion", qos: .userInitiated)
    private let lock = NSLock()
    private var isCancelled = false

    // Touched only on `queue`.
    private var pipeline: StableDiffusionPipeline?
    private var loadedKey: String?

    private init() {}

    /// Generates one image. `progress` receives (step, total) from the generation queue.
    func generate(
        _ request: Request,
        resourcesURL: URL,
        reduceMemory: Bool,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> CGImage {
        setCancelled(false)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        let image = try self.run(request, resourcesURL: resourcesURL, reduceMemory: reduceMemory, progress: progress)
                        continuation.resume(returning: image)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            self.cancel()
        }
    }

    /// Stops the current generation at its next step.
    func cancel() {
        setCancelled(true)
    }

    /// Frees the model's memory. Safe to call any time.
    func unload() {
        queue.async {
            self.pipeline?.unloadResources()
            self.pipeline = nil
            self.loadedKey = nil
        }
    }

    // MARK: - Queue work

    private func run(_ request: Request, resourcesURL: URL, reduceMemory: Bool, progress: @escaping @Sendable (Int, Int) -> Void) throws -> CGImage {
        let pipeline = try loadPipeline(resourcesURL: resourcesURL, reduceMemory: reduceMemory)

        var configuration = StableDiffusionPipeline.Configuration(prompt: request.prompt)
        configuration.negativePrompt = request.negativePrompt
        configuration.startingImage = request.startingImage
        configuration.strength = request.startingImage == nil ? 1 : request.strength
        configuration.stepCount = request.stepCount
        configuration.seed = request.seed
        configuration.guidanceScale = request.guidanceScale
        configuration.imageCount = 1
        configuration.schedulerType = .dpmSolverMultistepScheduler
        configuration.disableSafety = false

        let images: [CGImage?]
        do {
            images = try pipeline.generateImages(configuration: configuration) { step in
                progress(step.step, step.stepCount)
                return !self.cancelledFlag()
            }
        } catch {
            throw EngineError.failed(error.localizedDescription)
        }
        if cancelledFlag() { throw EngineError.cancelled }
        guard let first = images.first else { throw EngineError.failed("No image was produced.") }
        guard let image = first else { throw EngineError.filtered }
        if reduceMemory {
            pipeline.unloadResources()
            self.pipeline = nil
            loadedKey = nil
        }
        return image
    }

    private func loadPipeline(resourcesURL: URL, reduceMemory: Bool) throws -> StableDiffusionPipeline {
        let key = "\(resourcesURL.path)|\(reduceMemory)"
        if let pipeline, loadedKey == key { return pipeline }
        pipeline?.unloadResources()
        pipeline = nil

        guard FileManager.default.fileExists(atPath: resourcesURL.path) else { throw EngineError.modelMissing }
        let configuration = MLModelConfiguration()
        // Split-einsum models are built for the Neural Engine.
        configuration.computeUnits = .cpuAndNeuralEngine
        do {
            let loaded = try StableDiffusionPipeline(
                resourcesAt: resourcesURL,
                controlNet: [],
                configuration: configuration,
                disableSafety: false,
                reduceMemory: reduceMemory
            )
            try loaded.loadResources()
            pipeline = loaded
            loadedKey = key
            return loaded
        } catch {
            throw EngineError.failed(error.localizedDescription)
        }
    }

    private func setCancelled(_ value: Bool) {
        lock.lock()
        isCancelled = value
        lock.unlock()
    }

    private func cancelledFlag() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelled
    }
}
