import SwiftUI
import WardrobeCore

/// What the auto-tagger thinks an item photo shows. Every field is optional: the user confirms
/// or corrects suggestions before they're applied (Chapter 3).
struct TagSuggestion: Equatable, Sendable {
    var category: ItemCategory?
    var clothingType: ClothingType?
    /// Classifier confidence for `category`, 0...1.
    var categoryConfidence: Double
    var primaryColor: RGBColor?
    var secondaryColor: RGBColor?

    var isEmpty: Bool {
        category == nil && primaryColor == nil
    }
}

/// Produces tag suggestions from an item photo, entirely on device.
protocol AutoTagging: Sendable {
    func suggest(forPhoto data: Data) async -> TagSuggestion?
}

enum AutoTaggerInfo {
    /// Bump when the tagger improves; background re-tagging revisits items tagged by older versions.
    static let currentVersion = 1
    /// Below this confidence the category suggestion is shown as a question, not preselected.
    static let confidentThreshold = 0.5
}

private struct AutoTaggerKey: EnvironmentKey {
    static let defaultValue: any AutoTagging = VisionAutoTagger()
}

extension EnvironmentValues {
    var autoTagger: any AutoTagging {
        get { self[AutoTaggerKey.self] }
        set { self[AutoTaggerKey.self] = newValue }
    }
}
