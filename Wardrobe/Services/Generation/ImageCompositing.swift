import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit
import UniformTypeIdentifiers
import Vision
import WardrobeCore

/// Vision and Core Image building blocks for the avatar and try-on renders (Chapters 4 and 5).
/// Everything is synchronous and CPU/GPU-heavy: call off the main actor.
enum ImageCompositing {
    /// Studio backdrop for avatars and renders: a light neutral grey.
    static let backdrop = CGColor(srgbRed: 0.80, green: 0.80, blue: 0.81, alpha: 1)

    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    // MARK: - People

    /// The person in `image` with the background made transparent, or `nil` when no person is found.
    static func personCutout(from image: CGImage) -> CGImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let mask = request.results?.first?.pixelBuffer else { return nil }

        let source = CIImage(cgImage: image)
        var maskImage = CIImage(cvPixelBuffer: mask)
        maskImage = maskImage.transformed(by: CGAffineTransform(
            scaleX: source.extent.width / maskImage.extent.width,
            y: source.extent.height / maskImage.extent.height
        ))

        let blend = CIFilter.blendWithMask()
        blend.inputImage = source
        blend.backgroundImage = CIImage(color: .clear).cropped(to: source.extent)
        blend.maskImage = maskImage
        guard let output = blend.outputImage,
              let cutout = context.createCGImage(output, from: source.extent, format: .RGBA8, colorSpace: sRGB)
        else { return nil }
        // An empty mask means Vision found nobody.
        return opaqueBounds(of: cutout) == nil ? nil : cutout
    }

    /// The bounding box of non-transparent pixels, normalized with a top-left origin.
    static func opaqueBounds(of image: CGImage) -> UnitRect? {
        guard let sample = PhotoProcessor.samplePixels(of: image, maxDimension: 128) else { return nil }
        // No transparency at all: the whole frame is opaque.
        guard let mask = sample.alphaMask else { return UnitRect(x: 0, y: 0, width: 1, height: 1) }
        var minX = sample.width, minY = sample.height, maxX = -1, maxY = -1
        for y in 0..<sample.height {
            for x in 0..<sample.width where mask[y * sample.width + x] {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let w = Double(sample.width), h = Double(sample.height)
        return UnitRect(x: Double(minX) / w, y: Double(minY) / h, width: Double(maxX - minX + 1) / w, height: Double(maxY - minY + 1) / h)
    }

    /// Places a person cutout on the studio backdrop, aspect-fit with a margin, in a square canvas.
    /// Returns the canvas and where the person ended up (normalized, top-left origin).
    static func studioCanvas(person cutout: CGImage, size: Int) -> (image: CGImage, personBounds: UnitRect)? {
        let crop = opaqueBounds(of: cutout) ?? UnitRect(x: 0, y: 0, width: 1, height: 1)
        let cropRect = CGRect(
            x: crop.x * Double(cutout.width),
            y: crop.y * Double(cutout.height),
            width: crop.width * Double(cutout.width),
            height: crop.height * Double(cutout.height)
        ).integral
        guard let person = cutout.cropping(to: cropRect) else { return nil }

        let canvas = CGFloat(size)
        let margin = canvas * 0.04
        let available = CGSize(width: canvas - margin * 2, height: canvas - margin * 2)
        let scale = min(available.width / CGFloat(person.width), available.height / CGFloat(person.height))
        let drawn = CGSize(width: CGFloat(person.width) * scale, height: CGFloat(person.height) * scale)
        // Bottom-aligned (feet near the floor), horizontally centered. CG's origin is bottom-left.
        let frame = CGRect(x: (canvas - drawn.width) / 2, y: margin, width: drawn.width, height: drawn.height)

        guard let cg = makeContext(width: size, height: size) else { return nil }
        cg.setFillColor(backdrop)
        cg.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
        cg.interpolationQuality = .high
        cg.draw(person, in: frame)
        guard let image = cg.makeImage() else { return nil }

        let bounds = UnitRect(
            x: frame.minX / canvas,
            y: 1 - frame.maxY / canvas,
            width: frame.width / canvas,
            height: frame.height / canvas
        )
        return (image, bounds)
    }

    /// The largest face, normalized with a top-left origin.
    static func faceRect(in image: CGImage) -> UnitRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let face = request.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
            return nil
        }
        let box = face.boundingBox
        return UnitRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
    }

    /// Body joints with reasonable confidence, converted to a top-left origin.
    static func bodyKeypoints(in image: CGImage) -> BodyKeypoints? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let points = try? observation.recognizedPoints(.all)
        else { return nil }

        func point(_ joint: VNHumanBodyPoseObservation.JointName) -> UnitPoint2D? {
            guard let recognized = points[joint], recognized.confidence > 0.3 else { return nil }
            return UnitPoint2D(x: recognized.location.x, y: 1 - recognized.location.y)
        }
        return BodyKeypoints(
            nose: point(.nose), neck: point(.neck),
            leftShoulder: point(.leftShoulder), rightShoulder: point(.rightShoulder),
            leftHip: point(.leftHip), rightHip: point(.rightHip),
            leftKnee: point(.leftKnee), rightKnee: point(.rightKnee),
            leftAnkle: point(.leftAnkle), rightAnkle: point(.rightAnkle)
        )
    }

    // MARK: - Garments

    /// The item in a product photo with its background removed, cropped to the item. Falls back to
    /// the whole photo when Vision can't separate a foreground.
    static func garmentCutout(from data: Data) -> CGImage? {
        guard let image = try? PhotoProcessor.cgImage(from: data, maxPixelSize: 768) else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return image }
            let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
            let masked = CIImage(cvPixelBuffer: buffer)
            return context.createCGImage(masked, from: masked.extent, format: .RGBA8, colorSpace: sRGB) ?? image
        } catch {
            return image
        }
    }

    // MARK: - Blending

    /// `generated` with the region `rect` (normalized, top-left origin) taken from `original`
    /// through a soft-edged oval, so the user's own face survives the diffusion pass exactly.
    static func pasteBack(_ rect: UnitRect, from original: CGImage, onto generated: CGImage) -> CGImage? {
        let base = CIImage(cgImage: generated)
        var source = CIImage(cgImage: original)
        if source.extent.size != base.extent.size {
            source = source.transformed(by: CGAffineTransform(
                scaleX: base.extent.width / source.extent.width,
                y: base.extent.height / source.extent.height
            ))
        }
        let width = base.extent.width, height = base.extent.height
        // Core Image's origin is bottom-left.
        let center = CIVector(x: (rect.x + rect.width / 2) * width, y: (1 - (rect.y + rect.height / 2)) * height)
        let radius = max(rect.width * width, rect.height * height) * 0.62

        let gradient = CIFilter.radialGradient()
        gradient.center = CGPoint(x: center.x, y: center.y)
        gradient.radius0 = Float(radius * 0.7)
        gradient.radius1 = Float(radius)
        gradient.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        gradient.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard let mask = gradient.outputImage?.cropped(to: base.extent) else { return nil }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = source
        blend.backgroundImage = base
        blend.maskImage = mask
        guard let output = blend.outputImage else { return nil }
        return context.createCGImage(output, from: base.extent, format: .RGBA8, colorSpace: sRGB)
    }

    // MARK: - Utilities

    /// An 8-bit sRGB bitmap context with premultiplied alpha.
    static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// `image` scaled to exactly `size`×`size` (the diffusion model's input size).
    static func resized(_ image: CGImage, to size: Int) -> CGImage? {
        if image.width == size, image.height == size { return image }
        guard let cg = makeContext(width: size, height: size) else { return nil }
        cg.interpolationQuality = .high
        cg.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return cg.makeImage()
    }

    static func jpegData(_ image: CGImage, quality: Double = 0.9) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
