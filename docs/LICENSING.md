# Licensing

The licensing path for everything the app ships or downloads (Chapter 4.1). Model research was done in October 2026 from primary sources: model cards, LICENSE files and official docs. **This is engineering due diligence, not legal advice.** Have a lawyer review the items marked ⚖️ before launch.

## Summary

| Component | Used for | License | Commercial use | Status |
|---|---|---|---|---|
| apple/ml-stable-diffusion (Swift package) | On-device diffusion runtime | MIT | Yes | ✅ Shipped; notice in Acknowledgements |
| apple/coreml-stable-diffusion-v1-5-palettized (6-bit, split_einsum_v2) | Avatar clean-up, try-on blend | CreativeML Open RAIL-M | Yes, with pass-through use restrictions | ✅ Downloaded by the user after accepting the restrictions ⚖️ |
| Apple Vision (classification, segmentation, body pose, faces) | Auto-tagging, avatar cut-out, garment placement | iOS SDK (Apple Developer Program License) | Yes | ✅ |
| ZIPFoundation | Unpacking the model download | MIT | Yes | ✅ Notice in Acknowledgements |
| dictionary-of-colour-combinations (color data) | Color engine | MIT (digitization) | Yes for the digitization; see the book section | ✅ With caveats ⚖️ |
| FASHN VTON v1.5 | Future dedicated try-on model | Apache-2.0 (code and weights) | Yes | ⏳ Planned; needs a Core ML conversion |

**Not used, and must not be added:** anything that depends on InsightFace: IP-Adapter-FaceID, InstantID, PhotoMaker V2, PuLID and Arc2Face are non-commercial. The same goes for the CMU OpenPose detector; Apple Vision's body pose is used instead. Other excluded options:

| Excluded | Reason |
|---|---|
| IDM-VTON, OOTDiffusion, CatVTON (including its Core ML port), StableVITON, LaDI-VTON, GP-VTON, Mobile-VTON | CC BY-NC(-SA) or non-commercial research licenses |
| Leffa | Trained on VITON-HD and DressCode, whose licenses bar commercial use |
| FLUX.1 [dev], Fill [dev], Kontext [dev] and their derivatives (OmniTry, Any2AnyTryon, CatVTON-FLUX) | FLUX.1 [dev] Non-Commercial License |
| OmniGen2 | Bundles a VLM under the non-commercial Qwen Research License |
| FLUX.2 klein 9B, FLUX.3 klein | Non-commercial or unclear licenses |

## The image model: CreativeML Open RAIL-M

The model is Apple's 6-bit palettized Core ML conversion of Stable Diffusion 1.5, pinned to Hugging Face revision `04a6a0bdd66fb8da470c14e56d762343ef579d88` and checked by SHA-256 (`Packages/WardrobeCore/Sources/WardrobeCore/ImageModelCatalog.swift`). It runs on iPhone 12 (A14) and newer on iOS 17. Apple's benchmarks put a comparable 512 px, 20-step model at 8–18 s per image.

The license allows commercial use (paragraph 4, royalty-free) under these conditions, and the app meets them as follows:

| Obligation | How the app complies |
|---|---|
| ¶4(a): the Attachment A use restrictions must be an enforceable provision in any agreement governing use | The custom EULA ([`EULA.md`](EULA.md)) includes Attachment A verbatim. The model can't be downloaded until the user accepts the restrictions in `ModelDownloadView` |
| ¶4(b): give recipients a copy of the license | The full text is bundled (`Wardrobe/Resources/Licenses/CreativeML-OpenRAIL-M.txt`), linked from the download screen and Acknowledgements |
| ¶4(c): modified files must carry notices | The app downloads Apple's conversion unmodified from Apple's Hugging Face page and doesn't redistribute weights. Apple's conversion and palettization is credited in Acknowledgements |
| ¶5: require users to comply with the use restrictions | Download-time acceptance plus the EULA. The app adds its own consent rule: avatars only of yourself or people who agreed |
| ¶7: reasonable efforts to use the latest version; the licensor may restrict use | Model files can be removed and re-downloaded from Settings → Image Model. Update the pinned revision in `ImageModelCatalog` when Apple updates the model |
| Safety | Apple's `SafetyChecker` stays enabled (`disableSafety: false`), and the negative prompt excludes NSFW output |

**Risks to review** ⚖️:
- Whether Apple's standard EULA would suffice is untested. That's why the custom EULA is recommended.
- SD 1.5's training data (LAION-5B) has known provenance problems. Expect possible App Review questions, and be ready to describe the safety measures.
- Processing face photos may fall under biometric or likeness laws (BIPA, GDPR Art. 9, right-of-publicity) even on device. The app never extracts face embeddings: it uses Vision face *rectangles* only, to blend the original pixels back. It also requires consent before creating an avatar.

## Why there is no dedicated try-on model yet

Every widely used academic virtual try-on model is non-commercial (see above). The only commercially licensed, phone-sized dedicated try-on model is **FASHN VTON v1.5** (Apache-2.0 code and weights, 972M parameters, released January 2026). It has no Core ML conversion. Adopting it means:

1. Fork the inference code and remove its default human parser, which is under NVIDIA's research-only SegFormer license. Run it with `segmentation_free=True` and `garment_photo_type='flat-lay'`, which suits catalog photos.
2. Convert the MMDiT and DWPose (Apache-2.0) with coremltools, as 6–8-bit palettized models.
3. Benchmark on A17 Pro and newer, then put it behind `TryOnRenderer`, which keeps the same entry point.
4. Get a lawyer to review the undisclosed training data. Apache-2.0 carries no data warranty.

Until then, Chapter 5 uses an honest compositing approach built only from permissive parts: Vision body pose places garment cut-outs on the avatar, then SD 1.5 image-to-image blends them. On devices without diffusion, the composite and the flat-lay sketch are the previews.

A second track for later is FLUX.2 [klein] 4B (Apache-2.0) through Apple's Core AI on iOS 27 and 8 GB+ iPhones. It isn't viable with the iOS 17 floor today.

## The color data ⚖️

`color-dictionary.json` holds the 159 colors and 348 combinations of Sanzo Wada's *A Dictionary of Color Combinations* (配色総鑑, 1933–34). The MIT-licensed digitization covers the digitizers' work, not any rights in the book itself.

- **Japan:** Wada died in 1967. Under the life + 50 term in force then, his works entered the public domain on January 1, 2018. The 2018 extension to life + 70 wasn't retroactive for works already in the public domain.
- **United States:** a foreign work still protected in its source country on January 1, 1996 could have its US copyright restored under the URAA, for 95 years from publication. For a 1933–34 publication that would run to the end of 2028 or 2029. Individual colors and the fact that two colors pair aren't copyrightable, but a compilation's creative *selection and arrangement* can be. Reproducing all 348 combinations reproduces that selection, so treat this as a low-to-moderate risk until 2029.
- **The modern edition** (Seigensha, 2010) has its own copyright in layout, photography and text. The app reproduces none of it: no scans, page layouts, swatch imagery or text from the book.

Safe practices the app follows: credit Wada and the digitizers; don't use the book's title or cover as branding (the App Store copy says "inspired by a classic Japanese color dictionary"); show colors as plain swatches with the dataset names; never imply endorsement by the publisher.

## App Store and privacy

- Downloading ML model weights after install is data, not executable code (guideline 2.5.2). It is user-initiated and disclosed on the download screen.
- Privacy nutrition label: **Data Not Collected**. All processing is on device, there are no analytics, and there is no account. The model download contacts huggingface.co once; disclose it in the privacy policy ([`PRIVACY_POLICY.md`](PRIVACY_POLICY.md)).
- Privacy manifest: `Wardrobe/Resources/PrivacyInfo.xcprivacy` declares no tracking and no collected data, with required-reason APIs UserDefaults (CA92.1), disk space (E174.1, the pre-download space check) and file timestamp (C617.1, app-container files).
- Generated images show a caption saying they are AI-generated previews.
