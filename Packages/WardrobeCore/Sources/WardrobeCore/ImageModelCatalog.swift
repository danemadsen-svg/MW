import Foundation

/// An on-device image model the app can download once and run locally (Chapters 4 and 5).
public struct ImageModelDescriptor: Hashable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    /// Pinned to a repository revision so the bytes can't change underneath the checksum.
    public let downloadURL: URL
    public let downloadByteCount: Int64
    /// Lowercase hex SHA-256 of the downloaded archive.
    public let sha256: String
    /// The folder inside the archive that holds the model resources.
    public let archiveFolder: String
    /// Files and folders the runtime needs inside `archiveFolder`.
    public let requiredResources: [String]
    /// Native output size in pixels (square).
    public let resolution: Int
    public let licenseName: String
    /// Name of the bundled license text resource (without extension).
    public let licenseResource: String
    public let sourcePage: URL

    /// Space needed during install: the archive plus its unpacked contents, with headroom.
    public var requiredFreeBytes: Int64 {
        downloadByteCount * 2 + 300 * 1_024 * 1_024
    }

    /// Which required resources are missing from a directory listing of the installed folder.
    public func missingResources(in presentNames: Set<String>) -> [String] {
        requiredResources.filter { !presentNames.contains($0) }
    }
}

public enum ImageModelCatalog {
    /// Apple's 6-bit palettized Core ML conversion of Stable Diffusion 1.5 (split-einsum v2 attention
    /// for the Neural Engine, iOS 17+). Weights: CreativeML Open RAIL-M; the use-based
    /// restrictions in its Attachment A are passed through to users before download.
    public static let stableDiffusion15Palettized = ImageModelDescriptor(
        id: "sd15-palettized-split-einsum-v2",
        displayName: "Stable Diffusion 1.5 (Core ML, 6-bit)",
        downloadURL: URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-v1-5-palettized/resolve/04a6a0bdd66fb8da470c14e56d762343ef579d88/coreml-stable-diffusion-v1-5-palettized_split_einsum_v2_compiled.zip")!,
        downloadByteCount: 1_565_721_769,
        sha256: "49a6ac1f62e12a2b3e426730d686fa466e30cba11c03b85305775714fb9814ec",
        archiveFolder: "coreml-stable-diffusion-v1-5-palettized_split_einsum_v2_compiled",
        requiredResources: [
            "TextEncoder.mlmodelc",
            "Unet.mlmodelc",
            "VAEDecoder.mlmodelc",
            "VAEEncoder.mlmodelc",
            "SafetyChecker.mlmodelc",
            "vocab.json",
            "merges.txt",
        ],
        resolution: 512,
        licenseName: "CreativeML Open RAIL-M",
        licenseResource: "CreativeML-OpenRAIL-M",
        sourcePage: URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-v1-5-palettized")!
    )

    public static let `default` = stableDiffusion15Palettized
}
