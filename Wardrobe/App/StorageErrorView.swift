import SwiftUI

/// Shown instead of the app when the local store can't be opened.
struct StorageErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Can't open your closet", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Your wardrobe data couldn't be loaded. Restart the app, and if this keeps happening, free up some storage on your iPhone.")
        } actions: {
            Text(String(describing: error))
                .font(Theme.Typography.caption.monospaced())
                .foregroundStyle(Theme.Palette.textTertiary)
                .textSelection(.enabled)
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .themedScreen()
    }
}
