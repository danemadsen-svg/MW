# Wardrobe & AI Outfit App — Build Doc

Oct 12, 2026 · @dane madsen

## Concept

A personal wardrobe catalog and AI outfit generator, sold as a native app for a one-time fee. Users catalog every item they own (clothing plus rings, watches, cologne, shoes, belts, hats, scarves, gloves, bags), and the app builds outfit suggestions and a visual preview of the user wearing them.

**Key business constraint:** this is not a subscription or a cloud-dependent product. The AI (outfit logic and avatar/try-on image generation) runs locally on the customer's own device, which shapes every technical decision below.

## Core features

| Feature | What it does |
|---|---|
| Wardrobe catalog | Add any item (clothing, rings, watches, cologne, shoes, belts, hats, scarves, gloves, bags) with a photo, category, and dominant color tag |
| Auto-tagging | An on-device image model detects category and dominant color from the photo, and the user confirms or corrects |
| Outfit builder | Combines cataloged items into full outfits using the color-matching engine |
| Avatar | A consistent 3D or AI-generated likeness of the user, built once from a few reference photos |
| Outfit preview | Renders the avatar wearing a generated outfit, so the user sees it before committing |
| Closet insights | Flags items never used in an outfit, gaps in the wardrobe, and over-used pieces |

## Color engine

The outfit builder's matching logic is based on *A Dictionary of Color Combinations*, a Japanese color-pairing reference. Each cataloged item gets a dominant color tag (plus a secondary tag for patterns). The engine encodes the book's approved color pairings as a lookup table or ruleset, then suggests only outfit combinations where every pair of items falls within a sanctioned harmony.

1. Digitize the book's color palette and pairing rules into a structured dataset (hex or named color plus its approved partners)
2. Build a color-matching function that scores or filters candidate outfit combinations against that dataset
3. Layer basic constraints on top (season, formality, one hat max) so results stay wearable, not just color-correct

## Local AI avatar and try-on

Paying users generate images entirely on their own device, with no cloud inference. That rules out hosted models like Nano Banana 2 or Bria's API for end users (fine for prototyping, not for shipping).

| Requirement | Local-device approach |
|---|---|
| Consistent avatar from reference photos | A small open-weight diffusion model. Per-user LoRA training is desktop-class (SD 1.5 LoRA needs ~8-12GB VRAM, SDXL ~16-24GB), not something a phone can do. On mobile, use reference-image conditioning (IP-Adapter style) instead of training a per-user model |
| Outfit try-on render | A local virtual try-on model. IDM-VTON, OOTDiffusion, CatVTON and most research models are CC BY-NC-SA (non-commercial), so a paid product needs a permissively licensed one (FASHN VTON v1.5 or Qwen-Image-Edit, both Apache/MIT) |
| Hardware reality | Inference alone needs ~4-6GB VRAM for SD 1.5, ~8GB+ for SDXL, or Apple Silicon with enough unified memory. Training needs far more |
| Mitigation | Ship quantized/distilled weights; set a minimum device spec; offer a lower-fidelity "sketch preview" mode for weak hardware |

## Architecture

- **App shell:** native iPhone app (SwiftUI) for the catalog UI, photo capture, and outfit browsing
- **Local data store:** an on-device database holding item records, color tags, and outfit history. It never leaves the device
- **Local inference runtime:** Core ML for the avatar and try-on models
- **Color engine module:** the digitized color-dictionary ruleset, running as plain logic with no AI
- **Model packaging:** quantized weights shipped in the bundle or downloaded once on first launch

No backend server is required for the core product.

## Build chapters

**Platform decision (locked): iPhone only, SwiftUI.** Work the chapters in order, with one handoff per sub-chapter.

### Chapter 1: Catalog MVP
1. Project scaffold, navigation shell, dark-mode theme
2. Local database schema (items, categories, colors, outfits)
3. Add-item flow: camera capture plus photo library import
4. Category picker covering clothing, rings, watches, cologne, shoes, belts, hats, scarves, gloves, bags
5. Manual color tagging on each item
6. Browse, search, and filter the catalog
7. Edit and delete items

### Chapter 2: Color engine
1. Digitize the color dictionary into a structured dataset (color plus approved partners)
2. Map item color tags onto that dataset's palette
3. Matching function that scores or filters candidate outfit combinations
4. Wearability constraints layered on top (season, formality, one hat max)
5. Outfit generator screen: hit generate, get suggested combinations
6. Save, favorite, and re-browse generated outfits

### Chapter 3: Auto-tagging
1. Pick and bundle an on-device image classification model
2. Detect category from the item photo
3. Extract dominant color from the item photo
4. Confirm-or-correct UI so the user fixes wrong guesses
5. Background re-tagging for items already in the catalog

### Chapter 4: Avatar
1. Confirm the licensing path (permissive model only, see Risks)
2. Reference photo capture flow, three to five shots
3. Bundle the on-device diffusion runtime (Core ML)
4. Build the avatar via reference-image conditioning, not per-user training
5. Avatar preview, regenerate, and save

### Chapter 5: Try-on render
1. Integrate a permissively licensed try-on model
2. Compose avatar plus outfit items into a single render request
3. Generation progress UI, since this will be slow on a phone
4. Low-fidelity sketch fallback for weaker devices
5. Save and share the rendered look

### Chapter 6: Ship
1. Minimum device spec check with graceful degradation
2. One-time purchase flow and receipt validation
3. Onboarding walkthrough
4. App Store assets and submission

Chapters 1 and 2 are a sellable product on their own if the AI work stalls.

## Open questions and risks

- **Licensing is the biggest risk:** most open-source try-on models are non-commercial. Confirm a permissively licensed model (and check its base-model and training-data licenses too) before building on it
- **On-device personalization:** true per-user model training won't run on phones. Reference-conditioning works on mobile at lower fidelity
- **Image quality vs one-time price:** local models lag cloud models on quality. Set expectations, or offer a "sketch preview" fallback
- **Model size in the bundle:** quantized weights still add hundreds of MB to GBs to the download
- **The color dataset:** digitizing *A Dictionary of Color Combinations* needs care in how its palettes map to real garment colors, plus a check that reproducing its rules is fine for commercial use
