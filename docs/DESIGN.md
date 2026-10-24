# Design files

The app's screens and system diagrams live in Figma. Both mirror the SwiftUI code in this repo; when the code changes, update the design to match (the code is the source of truth).

- **iPhone screens and components:** [Wardrobe — iPhone App](https://www.figma.com/design/8uDE86CKryDccgKPLvsM2K) (Figma design file)
- **System diagrams:** [Wardrobe diagrams](https://www.figma.com/board/PhMgTTMVLrzIyXTFgmofCo) (FigJam board): data model, architecture, try-on render pipeline, color engine

## What's in the design file

One page, three sections:

| Section | Contents |
|---|---|
| Icons | 50 icon components named `Icon/<SF Symbol name>`, one for each symbol the code uses |
| Components | iOS chrome (status bar, home indicator, large and inline nav bars, tab bar) and app components: Chip, Color Swatch, Toggle, Button, Search Field, Banner, Item Tile (Regular and Small sizes), Closet Cell, List Row, Outfit Card |
| Screens | 12 iPhone screens (393 × 852): Onboarding, Closet, Item Editor, Item Detail, Outfit Generator, Outfit Detail, Insights, Paywall, Settings, Image Model, Avatar, Try-On |

The `Wardrobe` variable collection mirrors `Wardrobe/Theme/Theme.swift`: `color/*` for `Theme.Palette`, `spacing/*` for `Theme.Spacing`, `radius/*` for `Theme.Radius`. Each variable's iOS code syntax is set to its Swift name (for example `Theme.Palette.accent`), so Dev Mode shows the token to use. One extra token, `color/accent-tint`, is the background of `.bordered` buttons (accent at 16% over the surface color). Text styles follow the Dynamic Type sizes at the default (Large) setting.

### What each screen shows

Each screen is drawn from its SwiftUI view, with that view's copy, section order and defaults. Screens that scroll are shown at the scroll position where their main content is visible.

| Screen | View | State shown |
|---|---|---|
| Onboarding | `OnboardingView` | Second page, "Outfits from a century-old color book" |
| Closet | `ClosetView` | 12 items, suggestion banner, category chips, one item that needs details |
| Item Editor | `ItemEditorView` | New item from a photo. A confident suggestion has filled the empty fields: "From your photo: Top · Navy" |
| Item Detail | `ItemDetailView` | Navy Oxford Shirt, pushed from Closet |
| Outfit Generator | `OutfitsView` + `OutfitGeneratorView` | Default filters (current season, accessories up to 3, cologne on). Suggestions scored by the color rules: 80% for one accent, 70% for all neutrals |
| Outfit Detail | `OutfitDetailView` | Flat-lay sketch at the exact `SketchLayout` slot positions, with the book palette for combination #12 |
| Insights | `InsightsView` | Gaps, Needs details, Unused, Over-used, Suggested colors |
| Paywall | `PaywallView` | Sheet, before purchase |
| Settings | `SettingsView` | Free tier (18 of 25 items), full-quality rendering |
| Image Model | `ModelDownloadView` | Downloading, 42%, after accepting the license |
| Avatar | `AvatarView` | Avatar built with the image model |
| Try-On | `TryOnView` | Rendering (step 12 of 25) over the last saved preview |

## Substitutions

The design file stands in for some things the app gets from iOS:

| In the app | In the design file | Why |
|---|---|---|
| SF Pro (system font) | Inter | Figma can't lay out SF Pro text in the environment the file was built from |
| New York (serif titles) | Source Serif 4 | New York isn't available in Figma |
| SF Symbols | Lucide icons (ISC license) | Same reason as SF Pro; each icon component's description names the SF Symbol it stands for |
| iOS 26 UI kit components | Local copies of the status bar, nav bars and tab bar | Apple's library couldn't be imported into this file |
| Item photos | Garment-colored tiles with the category symbol | No real photos in the mockups |
| Avatar and try-on renders | Abstract mannequin shapes | No real person's likeness in the design file |

To show real fonts and symbols, open the file on a Mac with SF Pro installed and swap the text styles' font family. Change the font in the 11 text styles and every screen updates.
