import SwiftUI
import WardrobeCore

/// An item's thumbnail, or its category symbol when it has no photo.
struct ItemThumbnail: View {
    let data: Data?
    let category: ItemCategory
    var cornerRadius: CGFloat = Theme.Radius.m

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.Palette.surfaceRaised
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: category.systemImage)
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: data) {
            guard let data else {
                image = nil
                return
            }
            // Decode off the main actor; thumbnails are small but grids show many at once.
            image = await Task.detached(priority: .userInitiated) { UIImage(data: data)?.preparingForDisplay() }.value
        }
    }
}

/// A round color chip with a hairline border so dark colors stay visible on dark backgrounds.
struct ColorSwatchView: View {
    let color: RGBColor
    var size: CGFloat = 22
    var isSelected = false

    var body: some View {
        Circle()
            .fill(Color(color))
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Theme.Palette.textPrimary.opacity(0.25), lineWidth: 1))
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(Theme.Palette.accent, lineWidth: 2)
                        .padding(-4)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A capsule toggle used for filters and multi-select options.
struct ChipButton: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .foregroundStyle(isSelected ? Theme.Palette.background : Theme.Palette.textPrimary)
            .background(isSelected ? Theme.Palette.accent : Theme.Palette.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small "needs details" badge for items the outfit generator can't use yet.
struct IncompleteBadge: View {
    var body: some View {
        Label("Needs details", systemImage: "exclamationmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .labelStyle(.iconOnly)
            .foregroundStyle(Theme.Palette.background, Theme.Palette.accent)
            .padding(4)
            .accessibilityLabel("Needs details")
    }
}
