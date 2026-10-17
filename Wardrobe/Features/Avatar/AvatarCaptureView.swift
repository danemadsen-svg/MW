import SwiftUI

/// Collects three to five reference photos of the user (Chapter 4.2). Present in a
/// `NavigationStack`. Calls `onFinish` with the processed photos when the user taps Create.
struct AvatarCaptureView: View {
    let onFinish: ([AvatarPose: Data]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var photos: [AvatarPose: Data] = [:]
    @State private var activePose: AvatarPose?
    @State private var photoSource: ItemPhotoSource?
    @State private var processingPose: AvatarPose?
    @State private var hasConsented = false
    @State private var errorMessage: String?

    static let requiredPoses: Set<AvatarPose> = [.fullBody, .front]

    init(onFinish: @escaping ([AvatarPose: Data]) -> Void) {
        self.onFinish = onFinish
    }

    private var canFinish: Bool {
        hasConsented && Self.requiredPoses.isSubset(of: photos.keys) && processingPose == nil
    }

    var body: some View {
        List {
            Section {
                Text("Your avatar is made from your own photos, on this iPhone. Photos are stored only in Wardrobe and never uploaded.")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                ForEach(AvatarPose.allCases) { pose in
                    poseRow(pose)
                }
            } header: {
                Text("Photos")
            } footer: {
                Text("Stand in good, even light against a plain wall. Full body and front are required; the others improve the result.")
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                Toggle("These photos are of me", isOn: $hasConsented)
                    .foregroundStyle(Theme.Palette.textPrimary)
            } footer: {
                Text("Only create an avatar of yourself, or of someone who has agreed to it.")
            }
            .listRowBackground(Theme.Palette.surface)

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.Palette.destructive)
                }
                .listRowBackground(Theme.Palette.surface)
            }
        }
        .themedScreen()
        .navigationTitle("Your Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    onFinish(photos)
                    dismiss()
                }
                .disabled(!canFinish)
            }
        }
        .itemPhotoPicker($photoSource) { picked in
            guard let pose = activePose else { return }
            Task { await process(picked, for: pose) }
        }
    }

    private func poseRow(_ pose: AvatarPose) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Theme.Palette.surfaceRaised
                if processingPose == pose {
                    ProgressView()
                } else if let data = photos[pose], let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: pose.systemImage)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .frame(width: 56, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(pose.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if Self.requiredPoses.contains(pose) {
                        Text("Required")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.Palette.accent)
                    }
                }
                Text(pose.instructions)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            Menu {
                if ItemPhotoSource.isCameraAvailable {
                    Button("Take Photo", systemImage: "camera") { pick(.camera, for: pose) }
                }
                Button("Choose from Library", systemImage: "photo.on.rectangle") { pick(.library, for: pose) }
                if photos[pose] != nil {
                    Button("Remove", systemImage: "trash", role: .destructive) { photos[pose] = nil }
                }
            } label: {
                Image(systemName: photos[pose] == nil ? "plus.circle" : "arrow.triangle.2.circlepath")
                    .font(.title3)
            }
            .disabled(processingPose != nil)
            .accessibilityLabel(photos[pose] == nil ? "Add \(pose.title) photo" : "Replace \(pose.title) photo")
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func pick(_ source: ItemPhotoSource, for pose: AvatarPose) {
        activePose = pose
        errorMessage = nil
        photoSource = source
    }

    @MainActor
    private func process(_ picked: PendingItemPhoto, for pose: AvatarPose) async {
        processingPose = pose
        defer { processingPose = nil }
        do {
            let processed: ProcessedPhoto
            switch picked {
            case .captured(let image):
                processed = try await Task.detached(priority: .userInitiated) { try PhotoProcessor.process(image) }.value
            case .library(let item):
                guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoProcessingError.unreadableImage }
                processed = try await Task.detached(priority: .userInitiated) { try PhotoProcessor.process(data) }.value
            }
            photos[pose] = processed.fullData
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "That photo couldn't be used."
        }
    }
}

extension AvatarPose {
    var title: String {
        switch self {
        case .front: "Face, front"
        case .leftProfile: "Left side"
        case .rightProfile: "Right side"
        case .fullBody: "Full body"
        case .smile: "Smiling"
        }
    }

    var instructions: String {
        switch self {
        case .front: "Head and shoulders, looking at the camera."
        case .leftProfile: "Turn to show your left side."
        case .rightProfile: "Turn to show your right side."
        case .fullBody: "Head to toe, arms relaxed, in fitted clothes."
        case .smile: "A natural smile, looking at the camera."
        }
    }

    var systemImage: String {
        switch self {
        case .front, .smile: "person.crop.square"
        case .leftProfile, .rightProfile: "person.crop.rectangle"
        case .fullBody: "figure.stand"
        }
    }
}
