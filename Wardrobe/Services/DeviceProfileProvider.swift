import CoreML
import Foundation
import WardrobeCore

/// Reads this device's capabilities for `DeviceCapability` (Chapter 6.1).
enum DeviceProfileProvider {
    static func current() -> DeviceProfile {
        let info = ProcessInfo.processInfo
        return DeviceProfile(
            physicalMemoryBytes: info.physicalMemory,
            hasNeuralEngine: hasNeuralEngine,
            osMajorVersion: info.operatingSystemVersion.majorVersion,
            isLowPowerModeEnabled: info.isLowPowerModeEnabled,
            thermalLevel: thermalLevel(info.thermalState)
        )
    }

    /// Whether Core ML can use a Neural Engine. False on the simulator.
    static var hasNeuralEngine: Bool {
        MLComputeDevice.allComputeDevices.contains { device in
            if case .neuralEngine = device { return true }
            return false
        }
    }

    private static func thermalLevel(_ state: ProcessInfo.ThermalState) -> ThermalLevel {
        switch state {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .serious
        }
    }
}

extension RenderTier {
    /// Plain-language description for Settings.
    var summary: String {
        switch self {
        case .full: "Full quality: avatars and try-on renders are generated on this iPhone."
        case .reduced: "Memory-saving mode: renders are generated on this iPhone, a little more slowly."
        case .sketchOnly: "Sketch previews: this device shows outfits as flat-lay lookbooks instead of generated renders."
        }
    }

    var title: String {
        switch self {
        case .full: "Full quality"
        case .reduced: "Memory-saving"
        case .sketchOnly: "Sketch previews"
        }
    }
}
