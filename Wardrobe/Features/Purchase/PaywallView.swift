import SwiftUI

/// Explains and sells the one-time unlock. Present as a sheet; it dismisses itself once unlocked.
struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    init() {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("Wardrobe Lifetime")
                            .font(Theme.Typography.display)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Pay once. No subscription, no account, nothing leaves your iPhone.")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        feature("infinity", "Unlimited closet", "Catalog everything you own. The free version holds \(PurchaseManager.freeItemLimit) items.")
                        feature("person.crop.square", "Your avatar", "A likeness of you, built on this iPhone from a few photos.")
                        feature("sparkles.rectangle.stack", "Try-on previews", "See outfits on your avatar before you get dressed.")
                        feature("lock.shield", "Private by design", "Every photo, outfit and render stays on this device.")
                    }

                    purchaseButtons
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
        }
        .task { await purchases.loadProduct() }
        .onChange(of: purchases.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var purchaseButtons: some View {
        VStack(spacing: Theme.Spacing.m) {
            Button {
                Task { await purchases.purchase() }
            } label: {
                Group {
                    if purchases.purchaseState == .purchasing {
                        ProgressView()
                            .tint(Theme.Palette.background)
                    } else if let product = purchases.product {
                        Text("Unlock for \(product.displayPrice)")
                    } else {
                        Text("Unlock")
                    }
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.m)
                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(purchases.purchaseState == .purchasing)

            Button("Restore Purchase") {
                Task { await purchases.restore() }
            }
            .disabled(purchases.purchaseState == .purchasing)

            switch purchases.purchaseState {
            case .pending:
                Text("Your purchase is waiting for approval. It will unlock automatically.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            case .failed(let message):
                Text(message)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.destructive)
                    .multilineTextAlignment(.center)
            case .idle, .purchasing:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
