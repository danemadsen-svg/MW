/// How much on-device image generation a device can handle.
public enum RenderTier: Int, Comparable, CaseIterable, Sendable {
    /// No diffusion: flat-lay sketch previews only.
    case sketchOnly = 0
    /// Diffusion with memory-saving options and fewer steps (6 GB devices).
    case reduced = 1
    /// Diffusion at full settings (8 GB+ devices).
    case full = 2

    public static func < (lhs: RenderTier, rhs: RenderTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ThermalLevel: Int, Comparable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    public static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The facts about a device that decide its render tier. Gathered by the app from
/// `ProcessInfo` and Core ML; kept platform-independent here so the policy is testable.
public struct DeviceProfile: Hashable, Sendable {
    public var physicalMemoryBytes: UInt64
    public var hasNeuralEngine: Bool
    public var osMajorVersion: Int
    public var isLowPowerModeEnabled: Bool
    public var thermalLevel: ThermalLevel

    public init(physicalMemoryBytes: UInt64, hasNeuralEngine: Bool, osMajorVersion: Int, isLowPowerModeEnabled: Bool = false, thermalLevel: ThermalLevel = .nominal) {
        self.physicalMemoryBytes = physicalMemoryBytes
        self.hasNeuralEngine = hasNeuralEngine
        self.osMajorVersion = osMajorVersion
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.thermalLevel = thermalLevel
    }
}

/// Generation parameters for a tier.
public struct RenderSettings: Hashable, Sendable {
    public let tier: RenderTier
    public let stepCount: Int
    /// Square output size in pixels.
    public let resolution: Int
    /// Load and unload model parts on demand to fit in less memory (slower).
    public let reduceMemory: Bool
}

public enum DeviceCapability {
    /// Devices report slightly less than their marketed RAM, so thresholds sit below 8 GB and 6 GB.
    public static let fullTierMemory: UInt64 = 7_500 * 1_024 * 1_024
    public static let reducedTierMemory: UInt64 = 5_500 * 1_024 * 1_024
    public static let minimumOSVersion = 17

    /// What the hardware supports, ignoring temporary conditions.
    public static func hardwareTier(for profile: DeviceProfile) -> RenderTier {
        guard profile.hasNeuralEngine, profile.osMajorVersion >= minimumOSVersion else { return .sketchOnly }
        if profile.physicalMemoryBytes >= fullTierMemory { return .full }
        if profile.physicalMemoryBytes >= reducedTierMemory { return .reduced }
        return .sketchOnly
    }

    /// The tier to use right now: one step down in Low Power Mode or when the device is hot,
    /// sketch only when it's critically hot.
    public static func currentTier(for profile: DeviceProfile) -> RenderTier {
        let hardware = hardwareTier(for: profile)
        if profile.thermalLevel == .critical { return .sketchOnly }
        if profile.isLowPowerModeEnabled || profile.thermalLevel == .serious {
            return RenderTier(rawValue: max(0, hardware.rawValue - 1)) ?? .sketchOnly
        }
        return hardware
    }

    public static func settings(for tier: RenderTier) -> RenderSettings {
        switch tier {
        case .full: RenderSettings(tier: tier, stepCount: 25, resolution: 512, reduceMemory: false)
        case .reduced: RenderSettings(tier: tier, stepCount: 20, resolution: 512, reduceMemory: true)
        case .sketchOnly: RenderSettings(tier: tier, stepCount: 0, resolution: 0, reduceMemory: true)
        }
    }
}
