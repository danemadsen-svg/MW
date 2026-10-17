import SwiftUI

enum AddItemSource: Hashable {
    case camera
    case library
    case withoutPhoto
}

/// The "+" menu for adding an item: take a photo, choose one, or skip the photo.
/// Pair it with `.addItemFlow(_:itemCount:)` on a view outside the toolbar, which does the presenting.
struct AddItemButton: View {
    enum Style {
        /// Icon-only "+" for a toolbar.
        case toolbar
        /// A filled capsule for empty states.
        case prominent
    }

    private let style: Style
    private let onSelect: (AddItemSource) -> Void

    init(style: Style = .toolbar, onSelect: @escaping (AddItemSource) -> Void) {
        self.style = style
        self.onSelect = onSelect
    }

    var body: some View {
        Menu {
            if ItemPhotoSource.isCameraAvailable {
                Button("Take Photo", systemImage: "camera") { onSelect(.camera) }
            }
            Button("Choose from Library", systemImage: "photo.on.rectangle") { onSelect(.library) }
            Button("Add without Photo", systemImage: "square.and.pencil") { onSelect(.withoutPhoto) }
        } label: {
            switch style {
            case .toolbar:
                Label("Add Item", systemImage: "plus")
                    .labelStyle(.iconOnly)
            case .prominent:
                Label("Add an Item", systemImage: "plus")
                    .font(Theme.Typography.headline)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.m)
                    .foregroundStyle(Theme.Palette.background)
                    .background(Theme.Palette.accent, in: Capsule())
            }
        }
        .accessibilityLabel("Add Item")
    }
}

extension View {
    /// Runs the add-item flow whenever `request` is set: checks the free item limit (showing the
    /// paywall when it's reached), picks a photo, then opens a new item in the editor.
    func addItemFlow(_ request: Binding<AddItemSource?>, itemCount: Int) -> some View {
        modifier(AddItemFlow(request: request, itemCount: itemCount))
    }
}

private struct AddItemFlow: ViewModifier {
    private struct EditorRequest: Identifiable {
        let id = UUID()
        let photo: PendingItemPhoto?
    }

    @Binding var request: AddItemSource?
    let itemCount: Int

    @Environment(PurchaseManager.self) private var purchases
    @State private var photoSource: ItemPhotoSource?
    @State private var editorRequest: EditorRequest?
    @State private var isShowingPaywall = false

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, newValue in
                guard let newValue else { return }
                request = nil
                start(newValue)
            }
            .itemPhotoPicker($photoSource) { photo in
                editorRequest = EditorRequest(photo: photo)
            }
            .sheet(item: $editorRequest) { editor in
                NavigationStack {
                    ItemEditorView(newItemPhoto: editor.photo)
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
    }

    @MainActor
    private func start(_ source: AddItemSource) {
        guard purchases.canAddItem(currentItemCount: itemCount) else {
            isShowingPaywall = true
            return
        }
        switch source {
        case .camera: photoSource = .camera
        case .library: photoSource = .library
        case .withoutPhoto: editorRequest = EditorRequest(photo: nil)
        }
    }
}
