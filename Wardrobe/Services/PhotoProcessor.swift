import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers
import WardrobeCore

/// A photo ready to store: a downscaled full image and a grid thumbnail, both JPEG with all
/// metadata (EXIF, GPS, camera details) stripped.
struct ProcessedPhoto: Sendable {
    let fullData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

/// Pixels sampled from an image for color analysis, in sRGB, row-major.
struct PixelSample: Sendable {
    let pixels: [RGBColor]
    let width: Int
    let height: Int
    /// `true` for opaque pixels. `nil` when the image has no transparency.
    let alphaMask: [Bool]?
}

enum PhotoProcessingError: Error, LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "This photo couldn't be read. Try a different one."
        case .encodingFailed: "This photo couldn't be saved. Try again."
        }
    }
}

/// Image work for item photos, built on ImageIO so a 48 MP photo is never fully decoded in
/// memory. Everything here is synchronous and CPU-heavy: call it off the main actor.
enum PhotoProcessor {
    /// Longest edge of the stored photo.
    static let maxDimension = 2048
    /// Longest edge of the thumbnail: a third of an iPhone Pro Max width at @3x, plus margin.
    static let thumbnailDimension = 480
    static let jpegQuality = 0.82

    static func process(_ data: Data) throws -> ProcessedPhoto {
        let source = try imageSource(data)
        let full = try downsample(source, maxPixelSize: maxDimension)
        let thumbnail = try downsample(source, maxPixelSize: thumbnailDimension)
        return ProcessedPhoto(
            fullData: try encodeJPEG(full),
            thumbnailData: try encodeJPEG(thumbnail),
            pixelWidth: full.width,
            pixelHeight: full.height
        )
    }

    /// For camera captures. The intermediate JPEG keeps the orientation tag, which `process`
    /// then bakes into the pixels.
    static func process(_ image: UIImage) throws -> ProcessedPhoto {
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            throw PhotoProcessingError.encodingFailed
        }
        return try process(data)
    }

    /// Decodes `data` with orientation applied, no larger than `maxPixelSize` on its long edge.
    static func cgImage(from data: Data, maxPixelSize: Int) throws -> CGImage {
        try downsample(imageSource(data), maxPixelSize: maxPixelSize)
    }

    /// Draws `image` into a small sRGB bitmap (aspect ratio kept) and reads its pixels.
    static func samplePixels(of image: CGImage, maxDimension: Int = 64) -> PixelSample? {
        guard image.width > 0, image.height > 0, maxDimension > 0 else { return nil }
        let scale = min(1, Double(maxDimension) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let buffer = context.data else { return nil }

        let bytes = buffer.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var pixels: [RGBColor] = []
        var mask: [Bool] = []
        pixels.reserveCapacity(width * height)
        mask.reserveCapacity(width * height)
        var hasTransparency = false

        for index in 0..<(width * height) {
            let offset = index * 4
            let alpha = bytes[offset + 3]
            if alpha < 255 { hasTransparency = true }
            // Undo premultiplication so partly transparent edge pixels keep their real color.
            func channel(_ value: UInt8) -> UInt8 {
                guard alpha > 0, alpha < 255 else { return value }
                return UInt8(min(255, (Int(value) * 255 + Int(alpha) / 2) / Int(alpha)))
            }
            pixels.append(RGBColor(red: channel(bytes[offset]), green: channel(bytes[offset + 1]), blue: channel(bytes[offset + 2])))
            mask.append(alpha >= 128)
        }
        return PixelSample(pixels: pixels, width: width, height: height, alphaMask: hasTransparency ? mask : nil)
    }

    // MARK: - ImageIO

    private static func imageSource(_ data: Data) throws -> CGImageSource {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              CGImageSourceGetCount(source) > 0
        else { throw PhotoProcessingError.unreadableImage }
        return source
    }

    private static func downsample(_ source: CGImageSource, maxPixelSize: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Applies the EXIF orientation so the pixels are upright.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoProcessingError.unreadableImage
        }
        return image
    }

    /// Encodes without copying any source properties, which drops EXIF and GPS metadata.
    private static func encodeJPEG(_ image: CGImage) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoProcessingError.encodingFailed
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw PhotoProcessingError.encodingFailed
        }
        return output as Data
    }
}
