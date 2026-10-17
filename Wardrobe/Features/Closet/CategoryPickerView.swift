import SwiftUI
import WardrobeCore

/// A grid of every category and, for clothing, the clothing type. Sized to its content, so it
/// can sit in a form row.
struct CategoryPickerView: View {
    @Binding private var category: ItemCategory?
    @Binding private var clothingType: ClothingType?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.s)]

    init(category: Binding<ItemCategory?>, clothingType: Binding<ClothingType?>) {
        _category = category
        _clothingType = clothingType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                ForEach(ItemCategory.allCases) { option in
                    categoryButton(option)
                }
            }

            if category == .clothing {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Type")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    ForEach(ClothingType.allCases) { type in
                        clothingTypeButton(type)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func categoryButton(_ option: ItemCategory) -> some View {
        let isSelected = category == option
        return Button {
            category = option
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: option.systemImage)
                    .font(.title3)
                    .frame(height: 28)
                Text(option.displayName)
                    .font(Theme.Typography.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, Theme.Spacing.xs)
            .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textPrimary)
            .background(Theme.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Palette.accent : Color.clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func clothingTypeButton(_ type: ClothingType) -> some View {
        let isSelected = clothingType == type
        return Button {
            clothingType = type
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: type.systemImage)
                    .font(.body)
                    .frame(width: 28)
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textSecondary)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(type.displayName)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(type.examples)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .padding(.vertical, Theme.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    Form {
        CategoryPickerView(category: .constant(.clothing), clothingType: .constant(.bottom))
            .listRowBackground(Theme.Palette.surface)
    }
    .themedScreen()
    .preferredColorScheme(.dark)
}
