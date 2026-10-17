import SwiftData
import SwiftUI
import WardrobeCore

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ModelStore.self) private var modelStore
    @Query private var items: [Item]
    @Query private var outfits: [Outfit]

    @State private var isShowingPaywall = false
    @State private var isConfirmingErase = false
    @State private var errorMessage: String?
    @State private var profile = DeviceProfileProvider.current()

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            purchaseSection
            renderingSection
            dataSection
            privacySection

            Section("About") {
                NavigationLink("Acknowledgements") { AcknowledgementsView() }
                LabeledContent("Version", value: versionString)
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .listRowBackground(Theme.Palette.surface)
        }
        .themedScreen()
        .navigationTitle("Settings")
        .sheet(isPresented: $isShowingPaywall) { PaywallView() }
        .confirmationDialog("Erase everything?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
            Button("Erase All Data", role: .destructive) { eraseAll() }
        } message: {
            Text("Deletes every item, photo, outfit, avatar and render from this iPhone. This can't be undone. Your purchase isn't affected.")
        }
        .alert("Couldn't Erase", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear { profile = DeviceProfileProvider.current() }
    }

    // MARK: - Sections

    private var purchaseSection: some View {
        Section {
            if purchases.isUnlocked {
                Label("Wardrobe Lifetime is unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else {
                LabeledContent("Closet", value: "\(items.count) of \(PurchaseManager.freeItemLimit) free items")
                    .foregroundStyle(Theme.Palette.textPrimary)
                Button("Unlock Wardrobe Lifetime") { isShowingPaywall = true }
                Button("Restore Purchase") {
                    Task { await purchases.restore() }
                }
            }
        } header: {
            Text("Purchase")
        } footer: {
            if !purchases.isUnlocked {
                Text("A one-time purchase. No subscription.")
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var renderingSection: some View {
        let tier = DeviceCapability.currentTier(for: profile)
        return Section {
            NavigationLink("Your Avatar") { AvatarView() }
                .foregroundStyle(Theme.Palette.textPrimary)
            if tier != .sketchOnly {
                NavigationLink {
                    ModelDownloadView()
                } label: {
                    LabeledContent("Image Model", value: modelStore.state == .installed ? "Installed" : "Not installed")
                }
                .foregroundStyle(Theme.Palette.textPrimary)
            }
            LabeledContent("Previews", value: tier.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            if tier < DeviceCapability.hardwareTier(for: profile) {
                Text("Reduced for now because of Low Power Mode or device temperature.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        } header: {
            Text("On-Device Rendering")
        } footer: {
            Text(tier.summary)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Items", value: "\(items.count)")
            LabeledContent("Saved outfits", value: "\(outfits.count)")
            Button("Erase All Data", role: .destructive) { isConfirmingErase = true }
                .disabled(items.isEmpty && outfits.isEmpty)
        } header: {
            Text("Data")
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .listRowBackground(Theme.Palette.surface)
    }

    private var privacySection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("On-device only")
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Your photos, catalog, outfits and avatar never leave this iPhone. Nothing is collected or tracked.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Theme.Palette.accent)
            }
        } header: {
            Text("Privacy")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    // MARK: - Actions

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func eraseAll() {
        do {
            try modelContext.delete(model: TryOnRender.self)
            try modelContext.delete(model: Outfit.self)
            try modelContext.delete(model: AvatarReference.self)
            try modelContext.delete(model: AvatarProfile.self)
            try modelContext.delete(model: Item.self)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Your data couldn't be erased. \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .environment(PurchaseManager())
        .environment(ModelStore())
        .preferredColorScheme(.dark)
}
