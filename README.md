# Wardrobe

A personal wardrobe catalog and AI outfit generator for iPhone. Everything (catalog, color engine, and later the avatar and try-on models) runs on the device, with no backend or cloud inference.

See [`docs/BUILD.md`](docs/BUILD.md) for the full build doc and chapter plan.

## Stack

- SwiftUI, iPhone only, iOS 17+
- Xcode project generated from [`project.yml`](project.yml) with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Dark-only theme. Design tokens are in `Wardrobe/Theme/Theme.swift`, and UIKit bar styling is in `Wardrobe/Theme/Appearance.swift`

## Getting started

```sh
brew install xcodegen
xcodegen generate
open Wardrobe.xcodeproj
```

Choose your signing team under *Signing & Capabilities*, then run on a simulator or device. The generated `Wardrobe.xcodeproj` is not committed: `project.yml` is the source of truth, so re-run `xcodegen generate` after adding or moving files.

## Layout

```
Wardrobe/
  App/         app entry point and tab shell
  Theme/       colors, spacing, typography, bar appearance
  Features/    one folder per tab (Closet, Outfits, Insights, Settings)
  Resources/   asset catalog
```

## Progress

- [x] 1.1 Project scaffold, navigation shell, dark-mode theme
- [ ] 1.2 Local database schema
- [ ] 1.3 Add-item flow
- [ ] 1.4 Category picker
- [ ] 1.5 Manual color tagging
- [ ] 1.6 Browse, search, filter
- [ ] 1.7 Edit and delete
