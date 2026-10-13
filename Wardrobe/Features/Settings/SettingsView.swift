import SwiftUI

struct SettingsView: View {
    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("On-device only")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Your photos, catalog and outfits never leave this iPhone.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(Theme.Palette.accent)
                }
            } header: {
                Text("Privacy")
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                LabeledContent("Version", value: versionString)
                    .foregroundStyle(Theme.Palette.textPrimary)
            } header: {
                Text("About")
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .themedScreen()
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
}
