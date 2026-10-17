# Architecture

How the iPhone app is put together, and the conventions every change follows. Read this before adding a feature.

## Layers

```
Packages/WardrobeCore   Pure Swift domain logic. No UIKit/SwiftUI/SwiftData. Builds and tests on Linux.
  ItemCategory, ClothingType, SeasonSet, Season, Formality, RGBColor, LabColor (CIEDE2000)
  ColorDictionary (book data), ColorHarmony (rules), OutfitGenerator, DominantColorExtractor,
  CategoryClassifier (classifier labels → categories), InsightsAnalyzer, SketchLayout,
  DeviceCapability (render tiers), GarmentSwatches, SeededGenerator, ImageModelCatalog,
  BodyLayout (pose → garment regions), RenderPrompt

Wardrobe/Persistence    SwiftData schema (SchemaV1), migration plan, container factory,
                        ModelMapping (models → Core value snapshots)
Wardrobe/Services       Platform services: PhotoProcessor (ImageIO), AutoTagging (protocol) +
                        VisionAutoTagger, BackgroundRetagger (@ModelActor), SketchRenderer,
                        PurchaseManager (StoreKit 2), DeviceProfileProvider
  Generation/           ModelStore (one-time model download), DiffusionEngine (Core ML SD),
                        ImageCompositing (Vision + Core Image), AvatarBuilder, TryOnRenderer
Wardrobe/Shared         DisplayNames (all user-facing enum wording), Components (thumbnails,
                        swatches, chips, badges)
Wardrobe/Features/*     One folder per area: Closet, Outfits, Insights, Settings, Avatar, TryOn,
                        Onboarding, Purchase
Wardrobe/Theme          Design tokens (Theme.Palette / Spacing / Radius / Typography), bar styling
```

Engines take Core value types (`OutfitCandidate`, `InsightItem`, `SketchLayout.Piece`), never SwiftData models. Snapshot models on the main actor via `ModelMapping`, run the engine in `Task.detached`, and apply results back on the main actor.

## Conventions

- **iOS 17+, Swift 5 language mode.** `@Observable` for app-level state objects, injected with `.environment(_:)` and read with `@Environment(Type.self)`.
- **SwiftData:** use `@Query` in views and `@Environment(\.modelContext)` for writes. Call `try modelContext.save()` after user-initiated changes and surface failures. Set `Outfit.items` through `setItems(_:)`, and only after the outfit has been inserted. Call `item.touch()` after editing an item.
- **Wording:** every user-facing name for an enum comes from `Shared/DisplayNames.swift`.
- **Styling:** use `Theme` tokens only, never ad-hoc colors. Scrolling screens use `.themedScreen()`, list rows use `.listRowBackground(Theme.Palette.surface)`, and empty states use `ContentUnavailableView`.
- **Accessibility:** every icon-only button gets an `accessibilityLabel`, layouts stay readable with Dynamic Type, and color swatches always have a text name next to them or in their label.
- **Privacy:** nothing leaves the device. The only network access is the explicit, user-initiated model download in `ModelStore`. Photos are re-encoded through `PhotoProcessor`, which strips metadata.
- **Heavy work** (image processing, generation, Vision) runs off the main actor.

## Data model (SchemaV1)

- **`Item`:**
  - Basic fields: name, category, clothing type, primary and secondary color (packed RGB), seasons (bitmask), formality, notes, photo and thumbnail (external storage), timestamps.
  - Auto-tag fields: `suggested*`, `needsReview` and `autoTagVersion`. Suggestions never overwrite what the user chose.
- **`Outfit`:** name, favorite flag, score, palette combination ID, season and formality, `itemOrder`, `items` (many-to-many, nullify), and `renders` (cascade).
- **`AvatarProfile`, `AvatarReference`, `TryOnRender`:** Chapters 4 and 5.

## Cross-feature contracts

These are the types and entry points that features use to talk to each other. Change them only on purpose, and update this list when you do.

| Contract | Owner | Used by |
|---|---|---|
| `TagSuggestion`, `protocol AutoTagging { func suggest(forPhoto: Data) async -> TagSuggestion? }`, `@Environment(\.autoTagger)`, `AutoTaggerInfo.currentVersion` | Services/AutoTagging.swift | Closet item editor, background re-tagger |
| `final class VisionAutoTagger: AutoTagging` (init with no arguments) | Services/VisionAutoTagger.swift | AutoTagging environment default |
| `@MainActor @Observable final class PurchaseManager` with `isUnlocked: Bool`, `static let freeItemLimit = 25`, `func canAddItem(currentItemCount: Int) -> Bool`, `func purchase() async`, `func restore() async`, `func start()` | Services/PurchaseManager.swift | Closet add flow, Avatar, TryOn, Settings, Paywall |
| `struct PaywallView: View` (init with no arguments, presented as a sheet) | Features/Purchase/PaywallView.swift | Anywhere a limit is hit |
| `struct OutfitGeneratorView: View` with `init(anchorItemID: UUID? = nil)` | Features/Outfits | Outfits tab, item detail "Build an outfit" |
| `struct OutfitDetailView: View` with `init(outfit: Outfit)` | Features/Outfits | Saved outfits, Insights |
| `enum SketchRenderer { static func render(pieces: [(SketchLayout.Piece, Data?)], size: CGSize) -> UIImage }` | Services/SketchRenderer.swift | Outfit detail, try-on fallback |
| `struct ItemDetailView: View` with `init(item: Item)` | Features/Closet | Closet grid, Insights |
| `DeviceProfileProvider.current() -> DeviceProfile` | Services/DeviceProfileProvider.swift | Avatar, TryOn, Settings |
| `@MainActor @Observable final class ModelStore` with `state`, `resourcesURL`, `download()`, `cancel()`, `remove()`, injected via `.environment` | Services/Generation/ModelStore.swift | Avatar, TryOn, Settings, ModelDownloadView |
| `DiffusionEngine.shared.generate(_:resourcesURL:reduceMemory:progress:)`, `cancel()`, `unload()` | Services/Generation/DiffusionEngine.swift | AvatarBuilder, TryOnRenderer |
| `struct AvatarView: View` (init with no arguments), `struct TryOnView: View` with `init(outfit:)`, `struct ModelDownloadView: View` (no navigation stack) | Features/Avatar, Features/TryOn | Settings, outfit detail |
