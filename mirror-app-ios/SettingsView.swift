import SwiftUI

/// Settings screen allowing theme selection and showing legal text.
struct SettingsView: View {
    /// Persisted application theme.
    @AppStorage("appTheme") private var appTheme: Theme = .light

    /// Localized display names for the themes.
    private var themeNames: [Theme: String] {
        [
            .light: "ライト",
            .dark: "ダーク",
            .pink: "ピンク"
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Picker("テーマ", selection: $appTheme) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Text(themeNames[theme] ?? theme.rawValue.capitalized)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("利用規約")
                Text("プライバシーポリシー")
            }

            Spacer()
        }
        .padding()
        .navigationTitle("設定")
        .background(ThemeManager.backgroundColor(for: appTheme))
        .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
