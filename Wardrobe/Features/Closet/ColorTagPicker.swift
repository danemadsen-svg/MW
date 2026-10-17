import SwiftUI
import UIKit
import WardrobeCore

/// An item's primary and secondary color. A secondary color needs a primary one, and the two differ.
struct ItemColorSelection: Equatable {
    enum Slot: Hashable {
        case primary
        case secondary
    }

    var primary: RGBColor?
    var secondary: RGBColor?

    func color(in slot: Slot) -> RGBColor? {
        switch slot {
        case .primary: primary
        case .secondary: secondary
        }
    }

    /// Without a primary color, a secondary pick becomes the primary.
    mutating func select(_ color: RGBColor, for slot: Slot) {
        switch slot {
        case .primary:
            primary = color
            if secondary == color { secondary = nil }
        case .secondary:
            if primary == nil {
                primary = color
            } else if primary != color {
                secondary = color
            }
        }
    }

    /// Clearing the primary color promotes the secondary one.
    mutating func clear(_ slot: Slot) {
        switch slot {
        case .primary:
            primary = secondary
            secondary = nil
        case .secondary:
            secondary = nil
        }
    }
}

/// Picks an item's primary and optional secondary color: from the garment swatches, the photo's
/// dominant colors, or any custom color.
struct ColorTagPicker: View {
    @Binding private var primary: RGBColor?
    @Binding private var secondary: RGBColor?
    private let photoData: Data?
    private let category: ItemCategory

    @State private var slot: ItemColorSelection.Slot = .primary
    @State private var photoColors: DominantColors?
    @State private var isReadingPhoto = false

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: Theme.Spacing.s)]

    init(primary: Binding<RGBColor?>, secondary: Binding<RGBColor?>, photoData: Data?, category: ItemCategory) {
        _primary = primary
        _secondary = secondary
        self.photoData = photoData
        self.category = category
    }

    var body: some View {
        Form {
            if !category.usesColor {
                Section {
                    Label {
                        Text("Colors are optional for \(category.displayName.lowercased()). Outfits treat them as going with everything.")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.Palette.accent)
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }

            Section {
                if primary != nil {
                    Picker("Color", selection: $slot) {
                        Text("Primary").tag(ItemColorSelection.Slot.primary)
                        Text("Secondary").tag(ItemColorSelection.Slot.secondary)
                    }
                    .pickerStyle(.segmented)
                }
                currentColorRow
            } footer: {
                Text(slot == .primary ? "The color that covers most of the item." : "For stripes, prints and two-tone pieces.")
            }
            .listRowBackground(Theme.Palette.surface)

            if photoData != nil {
                Section("From Photo") {
                    photoColorRows
                }
                .listRowBackground(Theme.Palette.surface)
            }

            Section("Swatches") {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                    ForEach(GarmentSwatches.all) { swatch in
                        swatchButton(swatch)
                    }
                }
                .padding(.vertical, Theme.Spacing.s)
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                ColorPicker("Custom Color", selection: customColor, supportsOpacity: false)
                    .foregroundStyle(Theme.Palette.textPrimary)
            } footer: {
                Text("Any shade works. It's named after the closest swatch.")
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .themedScreen()
        .navigationTitle("Colors")
        .navigationBarTitleDisplayMode(.inline)
        .task { await readPhotoColors() }
    }

    // MARK: - Rows

    private var currentColor: RGBColor? {
        selection.color(in: slot)
    }

    private var selection: ItemColorSelection {
        ItemColorSelection(primary: primary, secondary: secondary)
    }

    @ViewBuilder
    private var currentColorRow: some View {
        if let color = currentColor {
            HStack(spacing: Theme.Spacing.m) {
                ColorSwatchView(color: color, size: 32)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(Self.name(for: color))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(color.hex)
                        .font(Theme.Typography.caption.monospaced())
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                Button("Clear", role: .destructive) {
                    update { $0.clear(slot) }
                }
                .buttonStyle(.borderless)
            }
        } else {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "circle.dashed")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text(slot == .primary ? "No color yet" : "No secondary color")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var photoColorRows: some View {
        if isReadingPhoto {
            HStack(spacing: Theme.Spacing.m) {
                ProgressView()
                Text("Finding colors…")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        } else if let photoColors {
            photoColorButton(photoColors.primary, coverage: photoColors.primaryCoverage)
            if let photoSecondary = photoColors.secondary {
                photoColorButton(photoSecondary, coverage: photoColors.secondaryCoverage)
                Button("Use Both") {
                    update { $0 = ItemColorSelection(primary: photoColors.primary, secondary: photoSecondary) }
                }
            }
        } else {
            Text("No clear colors found in this photo.")
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private func photoColorButton(_ color: RGBColor, coverage: Double) -> some View {
        Button {
            update { $0.select(color, for: slot) }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                ColorSwatchView(color: color, size: 28, isSelected: currentColor == color)
                Text(Self.name(for: color))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: Theme.Spacing.s)
                Text("\(coverage, format: .percent.precision(.fractionLength(0))) of item")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .accessibilityAddTraits(currentColor == color ? .isSelected : [])
    }

    private func swatchButton(_ swatch: GarmentSwatch) -> some View {
        let isSelected = currentColor == swatch.color
        return Button {
            update { $0.select(swatch.color, for: slot) }
        } label: {
            VStack(spacing: Theme.Spacing.s) {
                ColorSwatchView(color: swatch.color, size: 32, isSelected: isSelected)
                Text(swatch.name)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { currentColor.map { Color($0) } ?? Theme.Palette.textSecondary },
            set: { newValue in
                guard let rgb = Self.rgb(from: newValue) else { return }
                update { $0.select(rgb, for: slot) }
            }
        )
    }

    // MARK: - Actions

    private func update(_ change: (inout ItemColorSelection) -> Void) {
        var updated = selection
        change(&updated)
        primary = updated.primary
        secondary = updated.secondary
        if updated.primary == nil { slot = .primary }
    }

    @MainActor
    private func readPhotoColors() async {
        guard let photoData, photoColors == nil else { return }
        isReadingPhoto = true
        let colors = await Task.detached(priority: .userInitiated) {
            Self.dominantColors(in: photoData)
        }.value
        photoColors = colors
        isReadingPhoto = false
    }

    // MARK: - Color helpers

    /// The closest garment swatch's name ("Navy"), for any color.
    nonisolated static func name(for color: RGBColor) -> String {
        GarmentSwatches.nearest(to: color).name
    }

    /// `color` as 8-bit sRGB. Wide-gamut colors come back from UIKit outside 0...1 and are clamped.
    nonisolated static func rgb(from color: Color) -> RGBColor? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func channel(_ value: CGFloat) -> UInt8 {
            UInt8((min(max(value, 0), 1) * 255).rounded())
        }
        return RGBColor(red: channel(red), green: channel(green), blue: channel(blue))
    }

    /// Slow: decodes the photo. Call off the main actor.
    nonisolated static func dominantColors(in photoData: Data) -> DominantColors? {
        guard let image = try? PhotoProcessor.cgImage(from: photoData, maxPixelSize: 256),
              let sample = PhotoProcessor.samplePixels(of: image)
        else { return nil }
        return DominantColorExtractor().extract(
            pixels: sample.pixels,
            width: sample.width,
            height: sample.height,
            mask: sample.alphaMask
        )
    }
}

#Preview {
    NavigationStack {
        ColorTagPicker(
            primary: .constant(RGBColor(red: 0x1F, green: 0x2A, blue: 0x44)),
            secondary: .constant(nil),
            photoData: nil,
            category: .clothing
        )
    }
    .preferredColorScheme(.dark)
}
