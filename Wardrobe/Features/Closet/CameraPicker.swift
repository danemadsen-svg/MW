import PhotosUI
import SwiftUI
import UIKit

/// Where an item photo comes from.
enum ItemPhotoSource: Hashable {
    case camera
    case library

    /// False on the simulator and on devices where the camera is restricted.
    @MainActor static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

/// A photo the user picked that hasn't been loaded and processed yet.
enum PendingItemPhoto {
    case captured(UIImage)
    case library(PhotosPickerItem)
}

/// The system camera, for photographing an item.
struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the photo, or `nil` when the user cancels. The presenter dismisses the camera.
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

extension View {
    /// Presents the camera or the photo library (single image) while `source` is set, and hands
    /// the picked photo to `onPick`. A camera photo is delivered after the camera has finished
    /// dismissing, so `onPick` can present another sheet.
    func itemPhotoPicker(_ source: Binding<ItemPhotoSource?>, onPick: @escaping (PendingItemPhoto) -> Void) -> some View {
        modifier(ItemPhotoPickerModifier(source: source, onPick: onPick))
    }
}

private struct ItemPhotoPickerModifier: ViewModifier {
    @Binding var source: ItemPhotoSource?
    let onPick: (PendingItemPhoto) -> Void

    @State private var capturedImage: UIImage?
    @State private var libraryItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: isShowing(.camera), onDismiss: deliverCapturedImage) {
                CameraPicker { image in
                    capturedImage = image
                    source = nil
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: isShowing(.library), selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                libraryItem = nil
                onPick(.library(item))
            }
    }

    private func isShowing(_ kind: ItemPhotoSource) -> Binding<Bool> {
        Binding(
            get: { source == kind },
            set: { isPresented in
                if !isPresented, source == kind { source = nil }
            }
        )
    }

    private func deliverCapturedImage() {
        guard let image = capturedImage else { return }
        capturedImage = nil
        onPick(.captured(image))
    }
}
