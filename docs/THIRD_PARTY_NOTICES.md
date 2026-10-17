# Third-party notices

The app ships the following third-party material. Show these notices in the app (Settings → Acknowledgements) and keep this file up to date.

## Color combination data

`Packages/WardrobeCore/Sources/WardrobeCore/Resources/color-dictionary.json` is derived from
[dictionary-of-colour-combinations](https://github.com/mattdesl/dictionary-of-colour-combinations): 159 colors and 348 combinations from
*A Dictionary of Color Combinations* by Sanzo Wada (1883–1967). The original digitization is by Dain M. Blodorn Kim
([sanzo-wada](https://github.com/dblodorn/sanzo-wada)), with corrections and print-profile CMYK→sRGB conversion by Matt DesLauriers.
It was converted to this project's schema (ids, names, hex, swatch chapter, combinations) without changing any color values or pairings.

```
The MIT License (MIT)
Copyright (c) 2020 Matt DesLauriers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
```

See `docs/LICENSING.md` for the analysis of the underlying book's status.

## ml-stable-diffusion

[apple/ml-stable-diffusion](https://github.com/apple/ml-stable-diffusion), the Swift package that runs the on-device image model. MIT License, Copyright (c) 2024 Apple Inc. (same terms as above).

## ZIPFoundation

[weichsel/ZIPFoundation](https://github.com/weichsel/ZIPFoundation), used to unpack the model download. MIT License, Copyright (c) 2017-2026 Thomas Zoechling (same terms as above).

## Stable Diffusion 1.5 (downloaded, not bundled)

The optional image model is Apple's Core ML conversion of Stable Diffusion 1.5
([apple/coreml-stable-diffusion-v1-5-palettized](https://huggingface.co/apple/coreml-stable-diffusion-v1-5-palettized)),
which the user downloads after accepting its license in the app. It is licensed under the CreativeML Open RAIL-M
(Copyright (c) 2022 Robin Rombach and Patrick Esser and contributors). The full text ships at
`Wardrobe/Resources/Licenses/CreativeML-OpenRAIL-M.txt`, and its use-based restrictions are part of the app's EULA
(`docs/EULA.md`).
