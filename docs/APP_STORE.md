# App Store submission (Chapter 6.4)

## Listing

- **Name:** Wardrobe: Closet & Outfits *(check availability; the bundle display name is "Wardrobe")*
- **Subtitle (30):** Outfits from a color classic
- **Category:** Lifestyle (secondary: Photo & Video)
- **Price:** Free, with a one-time in-app purchase (Wardrobe Lifetime, `com.danemadsen.wardrobe.lifetime`)

**Promotional text (170):**
Catalog everything you own and get outfit ideas guided by a classic Japanese color dictionary. Private by design: your closet never leaves your iPhone.

**Description:**

> Wardrobe is a private, on-device closet for everything you wear: clothing, shoes, hats, scarves, gloves, belts, bags, watches, rings and cologne.
>
> CATALOG IN SECONDS
> Snap a photo or pick one from your library. Wardrobe suggests the category and colors for you, and you confirm or correct them. Search, filter by category or color, and see what still needs details.
>
> OUTFITS THAT WORK
> Tap Generate for outfits built on color pairings from a classic Japanese color dictionary, plus the neutrals that go with everything. Choose a season and formality, build around one piece you love, and save your favorites. Each suggestion shows its palette.
>
> CLOSET INSIGHTS
> Find pieces you never wear, gaps in your wardrobe, over-worn favorites, and the colors that would unlock the most new outfits.
>
> SEE IT ON YOU
> Create an avatar from a few photos of yourself and preview outfits on it. Everything is generated on your iPhone. Previews are AI-generated and approximate.
>
> PRIVATE BY DESIGN
> No account. No cloud. No tracking. Your photos, outfits and avatar never leave your device.
>
> PAY ONCE
> The free version holds 25 items, with unlimited outfit generation. Wardrobe Lifetime is a one-time purchase that unlocks an unlimited closet, your avatar and try-on previews. No subscription.

**Keywords (100 chars):** `closet,wardrobe,outfit,planner,style,fashion,color,palette,clothes,catalog,stylist,try on,avatar`

**Support URL / Marketing URL:** [to fill]
**Privacy Policy URL:** host [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md)
**License Agreement:** custom; paste [`EULA.md`](EULA.md)

## App Privacy (nutrition label)

- **Data Not Collected.** The app has no analytics, no accounts, no servers and no third-party SDKs that collect data.
- The optional model download contacts huggingface.co once. It transmits no user data, and the developer collects nothing, so it isn't "collection" under Apple's definitions. It is disclosed in the privacy policy.

## Age rating

Answer the questionnaire accurately. The app generates images of the user from their own photos, on device, with a safety checker and a NSFW-excluding negative prompt. There's no user-generated content sharing, chat or web browsing. Expect 4+ or 9+ depending on how the generative-image questions are worded; don't understate the generative feature.

## App Review notes

> Wardrobe runs entirely on device. There is no account or server.
>
> **Purchase testing:** use the sandbox. The non-consumable `com.danemadsen.wardrobe.lifetime` unlocks unlimited items, the avatar and try-on. The free tier allows 25 items.
>
> **Image generation (optional):** Settings → Image Model. After the user accepts the model's license terms (CreativeML Open RAIL-M use restrictions), the app downloads Apple's Core ML conversion of Stable Diffusion 1.5 (about 1.6 GB) from Apple's Hugging Face page, apple/coreml-stable-diffusion-v1-5-palettized. The model is data, not code. Without it, the app shows non-generative previews.
>
> **Avatar:** made from photos of the user, with explicit consent ("These photos are of me"). Apple's safety checker is enabled for all generated images.
>
> **Camera:** used only to photograph items and avatar reference photos.

## Screenshots (6.9" and 6.5" iPhone)

1. Closet grid with a filled catalog and filter chips
2. Item editor showing the auto-tag suggestion banner
3. Outfit generator results with palette swatches and the book combination number
4. Saved outfit with its sketch preview
5. Insights: gaps and suggested colors
6. Try-on preview on an avatar (use the developer's own likeness or a consenting model)

Use items you photograph yourself. Don't use photos of people who haven't agreed.

## Submission checklist

- [ ] App Store Connect app record, bundle ID `com.danemadsen.wardrobe`, team set in Xcode signing
- [ ] In-app purchase `com.danemadsen.wardrobe.lifetime` (non-consumable, Family Sharing on), with review screenshot and metadata, submitted with the build
- [ ] Increased Memory Limit capability enabled for the App ID (matches `Wardrobe.entitlements`)
- [ ] Custom EULA pasted; privacy policy URL live
- [ ] App Privacy: Data Not Collected
- [ ] Age rating questionnaire completed
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption = NO` (already in `project.yml`)
- [ ] Archive with Xcode, run the full test suite (⌘U) on a simulator and a device first
- [ ] Test on a 6 GB iPhone (reduced tier) and a pre-A14 or low-memory device (sketch tier)
- [ ] Test the model download on Wi-Fi and cellular, cancel and resume, and Settings → Remove Model
- [ ] Screenshots and app preview uploaded
- [ ] Legal review of [`LICENSING.md`](LICENSING.md) items marked ⚖️
