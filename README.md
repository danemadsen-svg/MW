# Wardrobe

A personal wardrobe catalog and outfit generator for iPhone, sold for a one-time fee. Everything runs on the device: the catalog, the color engine, auto-tagging, and the avatar and try-on renders. There's no backend and no cloud inference.

- [`docs/BUILD.md`](docs/BUILD.md): product build doc and chapter plan
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): layers, conventions, cross-feature contracts
- [`docs/LICENSING.md`](docs/LICENSING.md): model and data licensing decisions (read before launch)
- [`docs/APP_STORE.md`](docs/APP_STORE.md): listing, privacy label, review notes, submission checklist
- [`docs/EULA.md`](docs/EULA.md), [`docs/PRIVACY_POLICY.md`](docs/PRIVACY_POLICY.md), [`docs/THIRD_PARTY_NOTICES.md`](docs/THIRD_PARTY_NOTICES.md)

## Getting started

```sh
brew install xcodegen
xcodegen generate
open Wardrobe.xcodeproj
```

1. In *Signing & Capabilities*, choose your team. The Increased Memory Limit capability comes from `Wardrobe/Wardrobe.entitlements`.
2. Run on a simulator for the catalog and outfits, or on a device for the camera, Vision and image generation. The simulator has no Neural Engine, so it uses sketch previews.
3. The scheme uses `Wardrobe/Resources/Wardrobe.storekit`, so the Lifetime purchase works locally without App Store Connect.

`project.yml` is the source of truth, and the generated `Wardrobe.xcodeproj` is git-ignored. Re-run `xcodegen generate` after adding or moving files. Swift packages (apple/ml-stable-diffusion, ZIPFoundation) resolve on first open.

## Tests

- **Everything:** ⌘U in Xcode runs `WardrobeTests` (persistence, closet logic, outfit saving, auto-tag review) and `WardrobeCoreTests`
- **Core only:** `swift test --package-path Packages/WardrobeCore`. It runs anywhere Swift does, Linux included; 89 tests

## Status

All six chapters are implemented. The pure logic in `WardrobeCore` is compiled and tested. **The app layer (SwiftUI, SwiftData, Vision, StoreKit, Core ML) was written without access to Xcode or the iOS SDK.** Every file passes a Swift syntax parse and was reviewed against the iOS 17 APIs, but expect a round of compile fixes on the first Xcode build.

| Chapter | What's there |
|---|---|
| 1 Catalog | Closet grid, search, category and color filters, add flow (camera, library or no photo), editor (category and clothing type, primary and secondary colors, seasons, formality, notes), item detail, edit and delete |
| 2 Color engine | 159 colors and 348 combinations from *A Dictionary of Color Combinations*. Garment colors are mapped to the book with CIEDE2000, accent pairs must be sanctioned by the book, and fashion neutrals go with anything. Wearability rules cover season, formality, one hat max and accessory limits. Generator UI, saved and favorite outfits |
| 3 Auto-tagging | Vision's built-in classifier (no bundled model) maps to categories. Item-only dominant colors use a foreground mask and k-means in Lab. A confirm-or-correct banner, background re-tagging, and a review queue |
| 4 Avatar | Consent-gated photo capture and a one-time, license-gated download of Apple's Core ML SD 1.5. The person is cut out, cleaned up with image-to-image, and the original face is kept exactly |
| 5 Try-on | Vision body pose places garment cut-outs on the avatar, then on-device diffusion blends them. Progress and cancel, save and share, a quick-preview fallback and a flat-lay sketch for every device |
| 6 Ship | Device tiers (memory, Neural Engine, Low Power Mode, thermal state), a StoreKit 2 one-time unlock with on-device verification, onboarding, privacy manifest, app icon, and App Store documents |

### Business rules (easy to change)

- Free tier: 25 items (`PurchaseManager.freeItemLimit`), unlimited outfit generation and sketch previews
- Lifetime unlock (`com.danemadsen.wardrobe.lifetime`, $9.99 in the StoreKit config): unlimited items, avatar, try-on

### Needs a person

- **Xcode:** build, fix any compile errors, run the tests, and test on real devices (a 6 GB and an 8 GB iPhone, plus one without diffusion support)
- **App Store Connect:** create the app record and the in-app purchase, then fill in the metadata from `docs/APP_STORE.md`
- **Legal review** of the items marked ⚖️ in `docs/LICENSING.md`: the OpenRAIL-M pass-through EULA, US status of the color book's selection, and biometric and likeness law
- **Hosting:** the privacy policy and support URLs
- **Later:** convert FASHN VTON v1.5 (Apache-2.0) to Core ML for dedicated try-on (plan in `docs/LICENSING.md`)

## Layout

```
Wardrobe/
  App/            entry point, tab shell, storage error screen
  Persistence/    SwiftData schema (SchemaV1), migration plan, model → Core snapshots
  Services/       PhotoProcessor, VisionAutoTagger, BackgroundRetagger, SketchRenderer,
                  PurchaseManager, DeviceProfileProvider
    Generation/   ModelStore, DiffusionEngine, ImageCompositing, AvatarBuilder, TryOnRenderer
  Shared/         display names, shared components
  Features/       Closet, Outfits, Insights, Settings, Avatar, TryOn, Onboarding, Purchase
  Theme/          design tokens, bar appearance
  Resources/      assets, app icon, StoreKit config, privacy manifest, model license
WardrobeTests/    app unit tests (run in Xcode)
Packages/WardrobeCore/
                  color dictionary data, CIEDE2000, harmony rules, outfit generator,
                  dominant colors, label → category mapping, insights, sketch and body
                  layouts, render prompts, model catalog, device tiers
scripts/          make_app_icon.py
```

## Web companion

A browser version built from the same rules (same dataset and harmony thresholds, with data stored only in the browser) lives on Replit as a remix of the original "Modern Wardrobe App" prototype. It's useful for trying the color engine without a Mac.
