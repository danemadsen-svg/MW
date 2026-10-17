import SwiftUI

/// First-launch walkthrough (Chapter 6.3). The presenter records completion in `onFinish`.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page {
        let symbol: String
        let title: String
        let message: String
    }

    private let pages = [
        Page(
            symbol: "hanger",
            title: "Everything you own, in one place",
            message: "Photograph your clothes, shoes, watches, rings, bags and cologne. Wardrobe suggests the category and colors for you."
        ),
        Page(
            symbol: "paintpalette",
            title: "Outfits from a century-old color book",
            message: "Suggestions follow the pairings in Sanzo Wada's A Dictionary of Color Combinations, with neutrals that go with everything."
        ),
        Page(
            symbol: "lock.shield",
            title: "Private by design",
            message: "Your photos, outfits and avatar never leave this iPhone. No account, no cloud, no tracking."
        ),
    ]

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Continue" : "Start Your Closet")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.m)
                    .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.xl)

            Button("Skip", action: onFinish)
                .foregroundStyle(Theme.Palette.textSecondary)
                .opacity(page < pages.count - 1 ? 1 : 0)
                .disabled(page == pages.count - 1)
                .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: 0)
            Image(systemName: page.symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.Palette.accent)
                .accessibilityHidden(true)
            Text(page.title)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(page.message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView {}
        .preferredColorScheme(.dark)
}
