import SwiftData
import SwiftUI
import WardrobeCore

/// The user's avatar: create it from photos, regenerate, add appearance notes, or delete it
/// (Chapter 4.5). Part of the Lifetime unlock.
struct AvatarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ModelStore.self) private var modelStore
    @Query(filter: #Predicate<AvatarProfile> { $0.isCurrent }, sort: \AvatarProfile.createdAt, order: .reverse)
    private var profiles: [AvatarProfile]

    @State private var isCapturing = false
    @State private var isShowingPaywall = false
    @State private var isShowingModel = false
    @State private var isConfirmingDelete = false
    @State private var buildProgress: BuildProgress?
    @State private var errorMessage: String?
    @State private var notesDraft = ""

    private struct BuildProgress: Equatable {
        var step = 0
        var total = 0
    }

    private var profile: AvatarProfile? { profiles.first }

    var body: some View {
        List {
            if !purchases.isUnlocked {
                lockedSection
            } else if let profile {
                avatarSection(profile)
                notesSection(profile)
                renderingSection
                Section {
                    Button("Retake Photos") { isCapturing = true }
                    Button("Delete Avatar", role: .destructive) { isConfirmingDelete = true }
                }
                .listRowBackground(Theme.Palette.surface)
            } else {
                emptySection
                renderingSection
            }
        }
        .themedScreen()
        .navigationTitle("Your Avatar")
        .sheet(isPresented: $isCapturing) {
            NavigationStack {
                AvatarCaptureView { photos in
                    Task { await createProfile(from: photos) }
                }
            }
        }
        .sheet(isPresented: $isShowingPaywall) { PaywallView() }
        .sheet(isPresented: $isShowingModel) {
            NavigationStack {
                ModelDownloadView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingModel = false }
                        }
                    }
            }
        }
        .confirmationDialog("Delete your avatar?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Avatar", role: .destructive) { deleteAvatar() }
        } message: {
            Text("Its reference photos are deleted from this iPhone too. Saved try-on renders stay.")
        }
        .alert("Avatar", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear { notesDraft = profile?.appearanceNotes ?? "" }
    }

    // MARK: - Sections

    private var lockedSection: some View {
        Section {
            ContentUnavailableView {
                Label("Unlock your avatar", systemImage: "person.crop.square")
            } description: {
                Text("See outfits on a likeness of you, generated on this iPhone. Part of Wardrobe Lifetime.")
            } actions: {
                Button("Unlock") { isShowingPaywall = true }
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(Theme.Palette.textSecondary)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var emptySection: some View {
        Section {
            ContentUnavailableView {
                Label("No avatar yet", systemImage: "person.crop.square")
            } description: {
                Text("Take three to five photos of yourself. Your avatar is built on this iPhone and never leaves it.")
            } actions: {
                Button("Create Avatar") { isCapturing = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(buildProgress != nil)
            }
            .foregroundStyle(Theme.Palette.textSecondary)
            if buildProgress != nil {
                progressRow
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func avatarSection(_ profile: AvatarProfile) -> some View {
        Section {
            ZStack {
                Theme.Palette.surfaceRaised
                if let data = profile.avatarImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Your avatar")
                } else {
                    Image(systemName: "person.crop.square")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .listRowInsets(EdgeInsets(top: Theme.Spacing.m, leading: Theme.Spacing.m, bottom: Theme.Spacing.m, trailing: Theme.Spacing.m))

            if buildProgress != nil {
                progressRow
            } else {
                Button {
                    Task { await rebuild(profile, newSeed: true) }
                } label: {
                    Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        } footer: {
            Text(profile.modelIdentifier == nil
                ? "A clean cut-out of your photo. Install the image model for a re-rendered studio look."
                : "Re-rendered on this iPhone. Your face is kept exactly from your photo.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func notesSection(_ profile: AvatarProfile) -> some View {
        Section {
            TextField("Appearance", text: $notesDraft, prompt: Text("Optional, like “short dark hair, glasses”"), axis: .vertical)
                .lineLimit(1...3)
                .foregroundStyle(Theme.Palette.textPrimary)
                .onSubmit { saveNotes(profile) }
            if notesDraft != profile.appearanceNotes {
                Button("Save and Regenerate") {
                    saveNotes(profile)
                    Task { await rebuild(profile, newSeed: false) }
                }
                .disabled(buildProgress != nil)
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Helps the image model keep details your photos don't show clearly.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var renderingSection: some View {
        let tier = DeviceCapability.currentTier(for: DeviceProfileProvider.current())
        return Section {
            LabeledContent("This iPhone", value: tier.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            if tier != .sketchOnly {
                Button {
                    isShowingModel = true
                } label: {
                    LabeledContent("Image model", value: modelStore.state == .installed ? "Installed" : "Not installed")
                }
            }
        } header: {
            Text("On-Device Rendering")
        } footer: {
            Text(tier.summary)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let buildProgress, buildProgress.total > 0 {
                ProgressView(value: Double(buildProgress.step), total: Double(buildProgress.total)) {
                    Text("Rendering on this iPhone… step \(buildProgress.step) of \(buildProgress.total)")
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            } else {
                ProgressView("Preparing your photos…")
            }
            Button("Cancel", role: .cancel) { DiffusionEngine.shared.cancel() }
                .buttonStyle(.borderless)
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Actions

    private func diffusionSetup() -> DiffusionSetup? {
        let tier = DeviceCapability.currentTier(for: DeviceProfileProvider.current())
        guard tier != .sketchOnly, let url = modelStore.resourcesURL else { return nil }
        return DiffusionSetup(resourcesURL: url, settings: DeviceCapability.settings(for: tier))
    }

    @MainActor
    private func createProfile(from photos: [AvatarPose: Data]) async {
        for existing in profiles {
            existing.isCurrent = false
        }
        let profile = AvatarProfile(seed: Int(UInt32.random(in: .min ... .max)), appearanceNotes: notesDraft)
        modelContext.insert(profile)
        for (pose, data) in photos {
            let reference = AvatarReference(poseRaw: pose.rawValue, imageData: data)
            modelContext.insert(reference)
            reference.profile = profile
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Your photos couldn't be saved. \(error.localizedDescription)"
            return
        }
        await rebuild(profile, newSeed: false)
    }

    @MainActor
    private func rebuild(_ profile: AvatarProfile, newSeed: Bool) async {
        let references = Dictionary(profile.references.map { ($0.poseRaw, $0.imageData) }, uniquingKeysWith: { first, _ in first })
        guard let photo = references[AvatarPose.fullBody.rawValue] ?? references[AvatarPose.front.rawValue] else {
            errorMessage = "Add a full-body photo to build your avatar."
            return
        }
        if newSeed {
            profile.seed = Int(UInt32.random(in: .min ... .max))
        }
        let setup = diffusionSetup()
        buildProgress = BuildProgress()
        defer { buildProgress = nil }
        do {
            let output = try await AvatarBuilder.build(
                referencePhoto: photo,
                appearanceNotes: profile.appearanceNotes,
                seed: UInt32(truncatingIfNeeded: profile.seed),
                diffusion: setup
            ) { step, total in
                Task { @MainActor in
                    // A late update after the build finished must not bring the progress back.
                    if buildProgress != nil { buildProgress = BuildProgress(step: step, total: total) }
                }
            }
            profile.avatarImageData = output.imageData
            profile.modelIdentifier = output.usedDiffusion ? modelStore.model.id : nil
            try modelContext.save()
        } catch DiffusionEngine.EngineError.cancelled {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveNotes(_ profile: AvatarProfile) {
        profile.appearanceNotes = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
    }

    private func deleteAvatar() {
        for profile in profiles {
            modelContext.delete(profile)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Your avatar couldn't be deleted. \(error.localizedDescription)"
        }
    }
}
