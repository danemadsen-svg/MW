import SwiftUI
import WardrobeCore

/// The one-time image model download, behind the model license's use restrictions (Chapter 4.1).
/// The CreativeML Open RAIL-M license requires its Attachment A restrictions to be an
/// enforceable term for every user, so downloading requires accepting them here.
/// Has no navigation stack of its own.
struct ModelDownloadView: View {
    @Environment(ModelStore.self) private var modelStore
    @AppStorage("acceptedModelLicenseID") private var acceptedLicenseID = ""

    private var model: ImageModelDescriptor { modelStore.model }
    private var hasAccepted: Bool { acceptedLicenseID == model.id }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Render on this iPhone")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("A one-time download of \(Self.format(model.downloadByteCount)) from Hugging Face. After that, avatars and try-on previews are generated entirely offline, on this device.")
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                Text("\(model.displayName) is licensed under the \(model.licenseName). To use it you agree not to use it, or anything made with it:")
                    .foregroundStyle(Theme.Palette.textPrimary)
                ForEach(Self.restrictions, id: \.self) { restriction in
                    Label(restriction, systemImage: "xmark.circle")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Label("Create avatars only of yourself, or of people who have agreed to it.", systemImage: "person.crop.circle.badge.checkmark")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                NavigationLink("Read the full license") { ModelLicenseView() }
                Toggle("I agree to these use restrictions", isOn: acceptance)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .disabled(modelStore.isBusy)
            } header: {
                Text("Model License")
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                status
            } footer: {
                Text(footerText)
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .themedScreen()
        .navigationTitle("Image Model")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var status: some View {
        switch modelStore.state {
        case .installed:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.Palette.textPrimary)
            Button("Remove Model", role: .destructive) { modelStore.remove() }
        case .downloading(let fraction):
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ProgressView(value: fraction) {
                    Text("Downloading… \(fraction.formatted(.percent.precision(.fractionLength(0))))")
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Text("Keep Wardrobe open until the download finishes.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Button("Cancel Download", role: .cancel) { modelStore.cancel() }
        case .verifying:
            ProgressView("Checking the download…")
        case .installing:
            ProgressView("Installing…")
        case .notInstalled:
            downloadButton(title: "Download Model")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Theme.Palette.destructive)
            downloadButton(title: "Try Again")
        }
    }

    private func downloadButton(title: String) -> some View {
        Button {
            modelStore.download()
        } label: {
            Label(title, systemImage: "arrow.down.circle")
        }
        .disabled(!hasAccepted)
    }

    private var footerText: String {
        var parts = ["Wi-Fi recommended."]
        parts.append("Needs about \(Self.format(model.requiredFreeBytes)) free while installing.")
        if let available = modelStore.availableBytes {
            parts.append("\(Self.format(available)) available.")
        }
        parts.append("Downloading connects to huggingface.co once; nothing about you or your closet is sent.")
        return parts.joined(separator: " ")
    }

    private var acceptance: Binding<Bool> {
        Binding(
            get: { hasAccepted },
            set: { acceptedLicenseID = $0 ? model.id : "" }
        )
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Attachment A of the CreativeML Open RAIL-M license, in plain language. The full text is in
    /// `ModelLicenseView`.
    static let restrictions = [
        "In any way that breaks the law",
        "To exploit or harm minors in any way",
        "To create or spread false information meant to harm others",
        "To create or spread personal information that could be used to harm someone",
        "To defame, disparage or harass others",
        "For fully automated decisions that adversely affect someone's legal rights or obligations",
        "To discriminate against or harm people based on their behavior, personal characteristics or legally protected categories",
        "To exploit vulnerabilities of a group based on age or social, physical or mental characteristics in ways that cause harm",
        "To give medical advice or interpret medical results",
        "For justice, law enforcement, immigration or asylum purposes, such as predicting that someone will commit a crime",
    ]
}

/// The full text of the image model's license, bundled with the app.
struct ModelLicenseView: View {
    private let text: String = {
        let resource = ImageModelCatalog.default.licenseResource
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "The license text is missing from this build." }
        return text
    }()

    var body: some View {
        ScrollView {
            Text(text)
                .font(Theme.Typography.caption.monospaced())
                .foregroundStyle(Theme.Palette.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.l)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle(ImageModelCatalog.default.licenseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
