import CoreImage
import CoreVideo
import ImageIO
import Vision
import WardrobeCore

/// Suggests an item's category and colors from its photo, entirely on device (Chapter 3).
///
/// Classifier choice (Chapter 3.1): Vision's built-in `VNClassifyImageRequest` rather than a
/// bundled model. It ships with iOS (no download, no app-size cost, no third-party license), runs
/// on the Neural Engine, and its taxonomy covers clothing, footwear, bags, hats, watches, jewelry
/// and fragrance. `CategoryClassifier` maps its labels onto wardrobe categories; if accuracy ever
/// needs to improve, a Create ML model can replace this class behind the same `AutoTagging` protocol.
///
/// Colors come from the item alone: Vision's foreground-instance mask (iOS 17) cuts the item out
/// of its background before `DominantColorExtractor` runs. Where the mask isn't available (some
/// simulators, very busy photos) the extractor estimates the background from the image border.
final class VisionAutoTagger: AutoTagging {
    /// Labels passed to the category mapper, strongest first.
    private static let labelLimit = 25
    /// Longest edge of the image analyzed. Vision downsamples internally; this bounds memory.
    private static let analysisSize = 1024

    init() {}

    func suggest(forPhoto data: Data) async -> TagSuggestion? {
        await Task.detached(priority: .utility) {
            Self.analyze(data)
        }.value
    }

    private static func analyze(_ data: Data) -> TagSuggestion? {
        guard let image = try? PhotoProcessor.cgImage(from: data, maxPixelSize: analysisSize) else { return nil }
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])

        let category = categorySuggestion(handler: handler)
        let colors = dominantColors(of: image, handler: handler)

        let suggestion = TagSuggestion(
            category: category?.category,
            clothingType: category?.clothingType,
            categoryConfidence: category?.confidence ?? 0,
            primaryColor: colors?.primary,
            secondaryColor: colors?.secondary
        )
        return suggestion.isEmpty ? nil : suggestion
    }

    // MARK: - Category

    private static func categorySuggestion(handler: VNImageRequestHandler) -> CategorySuggestion? {
        let request = VNClassifyImageRequest()
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let labels = (request.results ?? [])
            .sorted { $0.confidence > $1.confidence }
            .prefix(labelLimit)
            .map { (identifier: $0.identifier, confidence: Double($0.confidence)) }
        return CategoryClassifier().suggestions(for: Array(labels)).first
    }

    // MARK: - Colors

    private static func dominantColors(of image: CGImage, handler: VNImageRequestHandler) -> DominantColors? {
        let extractor = DominantColorExtractor()
        if let foreground = foregroundImage(handler: handler),
           let sample = PhotoProcessor.samplePixels(of: foreground),
           let mask = sample.alphaMask,
           let colors = extractor.extract(pixels: sample.pixels, width: sample.width, height: sample.height, mask: mask) {
            return colors
        }
        guard let sample = PhotoProcessor.samplePixels(of: image) else { return nil }
        return extractor.extract(pixels: sample.pixels, width: sample.width, height: sample.height, mask: sample.alphaMask)
    }

    /// The photo with everything but its foreground made transparent, cropped to the foreground.
    private static func foregroundImage(handler: VNImageRequestHandler) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            return cgImage(from: buffer)
        } catch {
            return nil
        }
    }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    private static func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
        let image = CIImage(cvPixelBuffer: buffer)
        return ciContext.createCGImage(image, from: image.extent)
    }
}
