import SwiftUI

/// Licenses and credits for third-party material shipped in the app. Keep in sync with
/// docs/THIRD_PARTY_NOTICES.md.
struct AcknowledgementsView: View {
    private struct Notice: Identifiable {
        let title: String
        let detail: String
        let license: String

        var id: String { title }
    }

    private let notices = [
        Notice(
            title: "A Dictionary of Color Combinations data",
            detail: "159 colors and 348 combinations from Sanzo Wada's A Dictionary of Color Combinations. Digitized by Dain M. Blodorn Kim (sanzo-wada) and Matt DesLauriers (dictionary-of-colour-combinations).",
            license: AcknowledgementsView.mit(copyright: "Copyright (c) 2020 Matt DesLauriers")
        ),
        Notice(
            title: "ml-stable-diffusion",
            detail: "Apple's Core ML Stable Diffusion runtime, used for on-device avatar and try-on rendering.",
            license: AcknowledgementsView.mit(copyright: "Copyright (c) 2024 Apple Inc.")
        ),
        Notice(
            title: "ZIPFoundation",
            detail: "Unpacks the image model after its one-time download.",
            license: AcknowledgementsView.mit(copyright: "Copyright (c) 2017-2026 Thomas Zoechling (https://www.peakstep.com)")
        ),
    ]

    var body: some View {
        List {
            ForEach(notices) { notice in
                Section {
                    Text(notice.detail)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(notice.license)
                        .font(Theme.Typography.caption.monospaced())
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .textSelection(.enabled)
                } header: {
                    Text(notice.title)
                }
                .listRowBackground(Theme.Palette.surface)
            }
        }
        .themedScreen()
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func mit(copyright: String) -> String {
        """
        MIT License

        \(copyright)

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
    }
}
