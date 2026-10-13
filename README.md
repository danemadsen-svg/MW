# Wardrobe

A personal wardrobe catalog and AI outfit generator for iPhone. Everything (catalog, color engine, and later the avatar and try-on models) runs on the device, with no backend or cloud inference.

See [`docs/BUILD.md`](docs/BUILD.md) for the full build doc and chapter plan.

## Stack

- SwiftUI, iPhone only, iOS 17+
- Xcode project generated from [`project.yml`](project.yml) with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- SwiftData for on-device storage (`Wardrobe/Persistence`). The store is local only, with CloudKit sync explicitly disabled
- `WardrobeCore`, a local Swift package for platform-independent domain logic (categories, colors, later the color engine). It builds and tests on macOS and Linux without the iOS SDK
- Dark-only theme. Design tokens are in `Wardrobe/Theme/Theme.swift`, and UIKit bar styling is in `Wardrobe/Theme/Appearance.swift`

## Getting started

```sh
brew install xcodegen
xcodegen generate
open Wardrobe.xcodeproj
```

Choose your signing team under *Signing & Capabilities*, then run on a simulator or device. The generated `Wardrobe.xcodeproj` is git-ignored: `project.yml` is the source of truth, so re-run `xcodegen generate` after adding or moving files.

## Tests

- **Everything:** ⌘U in Xcode runs `WardrobeTests` (SwiftData persistence, needs the iOS simulator) and `WardrobeCoreTests`
- **Core only:** `swift test --package-path Packages/WardrobeCore`, which runs anywhere Swift does, Linux included

## Data model

`Wardrobe/Persistence/SchemaV1.swift` defines two models:

- **`Item`:** name, category, primary and optional secondary color (packed `0xRRGGBB`, `nil` until tagged), notes, photo and thumbnail (external storage), and timestamps
- **`Outfit`:** name, favorite flag, creation date, and a many-to-many `items` relationship. Deleting an item drops it from its outfits, and deleting an outfit keeps its items

Enums are stored as raw strings so they work in `#Predicate`. Typed accessors (`item.category`, `item.primaryColor`) wrap them. Until the first App Store release, `SchemaV1` may be edited in place. After that, freeze it and add a new `VersionedSchema` plus a migration stage.

## Layout

```
Wardrobe/
  App/          app entry point, tab shell, storage error screen
  Persistence/  SwiftData schema, migration plan, container factory
  Theme/        colors, spacing, typography, bar appearance
  Features/     one folder per tab (Closet, Outfits, Insights, Settings)
  Resources/    asset catalog
WardrobeTests/  app unit tests (run in Xcode)
Packages/
  WardrobeCore/ platform-independent domain types and tests
```

## Progress

- [x] 1.1 Project scaffold, navigation shell, dark-mode theme
- [x] 1.2 Local database schema
- [ ] 1.3 Add-item flow
- [ ] 1.4 Category picker
- [ ] 1.5 Manual color tagging
- [ ] 1.6 Browse, search, filter
- [ ] 1.7 Edit and delete
