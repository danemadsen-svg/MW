import SwiftData
import SwiftUI
import WardrobeCore

/// Shows an outfit on the user's avatar (Chapter 5): render, watch progress, save and share.
struct TryOnView: View {
    let outfit: Outfit

    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ModelStore.self) private var modelStore
    @Query(filter: #Predicate<AvatarProfile> { $0.isCurrent }, sort: \AvatarProfile.createdAt, order: .reverse)
    private var profiles: [AvatarProfile]

    @State private var progress: (step: Int, total: Int)?
    @State private var isRendering = false
    @State private var result: Result?
    @State private var errorMessage: String?
    @State private var isShowingPaywall = false
    @State private var isShowingModel = false
    @State private var renderTask: Task<Void, Never>?

    private struct Result {
        let image: UIImage
        let output: TryOnRenderer.Output
        let seed: UInt32
        var isSaved = false
    }

    init(outfit: Outfit) {
        self.outfit = outfit
    }

    private var profile: AvatarProfile? { profiles.first }
    private var tier: RenderTier { DeviceCapability.currentTier(for: DeviceProfileProvider.current()) }
    private var savedRenders: [TryOnRender] { outfit.renders.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        List {
            if !purchases.isUnlocked {
                locked
            } else if profile?.avatarImageData == nil {
                needsAvatar
            } else {
                preview
                controls
                if tier != .sketchOnly && modelStore.state != .installed {
                    modelHint
                }
            }
            if !savedRenders.isEmpty {
                history
            }
        }
        .themedScreen()
        .navigationTitle("Try On")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let result {
                ToolbarItem(placement: .primaryAction) {
                    let image = Image(uiImage: result.image)
                    ShareLink(item: image, preview: SharePreview(outfit.displayName, image: image))
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
        .alert("Try On", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear { renderTask?.cancel() }
    }

    // MARK: - Sections

    private var locked: some View {
        Section {
            ContentUnavailableView {
                Label("Try outfits on", systemImage: "sparkles.rectangle.stack")
            } description: {
                Text("See this outfit on your avatar, rendered on this iPhone. Part of Wardrobe Lifetime. The sketch preview on the outfit page is always free.")
            } actions: {
                Button("Unlock") { isShowingPaywall = true }
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(Theme.Palette.textSecondary)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var needsAvatar: some View {
        Section {
            ContentUnavailableView {
                Label("Create your avatar first", systemImage: "person.crop.square")
            } description: {
                Text("Try-on previews show outfits on a likeness of you, made from your own photos.")
            } actions: {
                NavigationLink("Create Avatar") { AvatarView() }
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(Theme.Palette.textSecondary)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var preview: some View {
        Section {
            ZStack {
                Theme.Palette.surfaceRaised
                if let result {
                    Image(uiImage: result.image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("\(outfit.displayName) on your avatar")
                } else if let latest = savedRenders.first, let image = UIImage(data: latest.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Last saved preview")
                } else if let data = profile?.avatarImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.4)
                        .accessibilityLabel("Your avatar")
                }
                if isRendering {
                    progressOverlay
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .listRowInsets(EdgeInsets(top: Theme.Spacing.m, leading: Theme.Spacing.m, bottom: Theme.Spacing.m, trailing: Theme.Spacing.m))
        } footer: {
            if let result {
                Text(Self.caption(for: result.output.kind))
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var progressOverlay: some View {
        VStack(spacing: Theme.Spacing.s) {
            if let progress, progress.total > 0 {
                ProgressView(value: Double(progress.step), total: Double(progress.total))
                    .tint(Theme.Palette.accent)
                Text("Step \(progress.step) of \(progress.total)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else {
                ProgressView()
                Text("Placing your pieces…")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.Palette.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .padding(Theme.Spacing.xl)
    }

    private var controls: some View {
        Section {
            if isRendering {
                Button("Cancel", role: .cancel) {
                    DiffusionEngine.shared.cancel()
                    renderTask?.cancel()
                }
            } else {
                Button {
                    startRender()
                } label: {
                    Label(renderTitle, systemImage: "sparkles")
                }
                if let result, !result.isSaved {
                    Button {
                        save()
                    } label: {
                        Label("Save Preview", systemImage: "square.and.arrow.down")
                    }
                }
            }
        } footer: {
            Text(renderFooter)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var modelHint: some View {
        Section {
            Button {
                isShowingModel = true
            } label: {
                Label("Download the image model for realistic renders", systemImage: "arrow.down.circle")
            }
        } footer: {
            Text("Until then, previews place your pieces on your avatar without blending.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var history: some View {
        Section("Saved Previews") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(savedRenders) { render in
                        if let image = UIImage(data: render.imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) { delete(render) }
                                }
                                .accessibilityLabel("Saved preview from \(render.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var renderTitle: String {
        if result != nil { return "Render Again" }
        return diffusionSetup() == nil ? "Quick Preview" : "Render on This iPhone"
    }

    private var renderFooter: String {
        if diffusionSetup() != nil {
            return "Takes about 10 to 60 seconds, depending on your iPhone. Everything happens on this device."
        }
        return tier == .sketchOnly
            ? "This iPhone shows quick previews: your pieces placed on your avatar."
            : "Quick previews place your pieces on your avatar."
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private static func caption(for kind: RenderKind) -> String {
        switch kind {
        case .diffusion: "Rendered on this iPhone. AI-generated preview; fit and drape are approximate."
        case .composite: "Quick preview: your pieces placed on your avatar."
        case .sketch: "Sketch preview."
        }
    }

    // MARK: - Actions

    private func diffusionSetup() -> DiffusionSetup? {
        guard tier != .sketchOnly, let url = modelStore.resourcesURL else { return nil }
        return DiffusionSetup(resourcesURL: url, settings: DeviceCapability.settings(for: tier))
    }

    private func startRender() {
        guard let profile, let avatar = profile.avatarImageData else { return }
        let garments = outfit.orderedItems.map { item in
            TryOnRenderer.Garment(piece: item.sketchPiece, photoData: item.photoData ?? item.thumbnailData, color: item.primaryColor)
        }
        let notes = profile.appearanceNotes
        let seed = UInt32.random(in: .min ... .max)
        let setup = diffusionSetup()
        isRendering = true
        progress = nil
        renderTask = Task { @MainActor in
            defer {
                isRendering = false
                progress = nil
            }
            do {
                let output = try await TryOnRenderer.render(avatar: avatar, garments: garments, appearanceNotes: notes, seed: seed, diffusion: setup) { step, total in
                    Task { @MainActor in
                        // A late update after rendering finished must not bring the progress back.
                        if isRendering { progress = (step, total) }
                    }
                }
                guard let image = UIImage(data: output.imageData) else { return }
                result = Result(image: image, output: output, seed: seed)
            } catch DiffusionEngine.EngineError.cancelled {
                return
            } catch is CancellationError {
                return
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func save() {
        guard var result else { return }
        let render = TryOnRender(
            kindRaw: result.output.kind.rawValue,
            imageData: result.output.imageData,
            seed: Int(result.seed),
            modelIdentifier: result.output.kind == .diffusion ? modelStore.model.id : nil
        )
        modelContext.insert(render)
        render.outfit = outfit
        do {
            try modelContext.save()
            result.isSaved = true
            self.result = result
        } catch {
            modelContext.rollback()
            errorMessage = "The preview couldn't be saved. \(error.localizedDescription)"
        }
    }

    private func delete(_ render: TryOnRender) {
        modelContext.delete(render)
        try? modelContext.save()
    }
}
