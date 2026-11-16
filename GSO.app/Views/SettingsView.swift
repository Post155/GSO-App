import SwiftUI

#Preview {
    SettingsView()
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var currentLang: String = "de"
    @AppStorage("appAppearance") private var appearanceRaw: Int = 0
    @AppStorage("accessibilityMode") private var accessibilityMode: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isWide = geo.size.width > 700

                HStack(spacing: 0) {
                    if isWide { Spacer(minLength: 0) }

                    settingsList
                        .frame(maxWidth: isWide ? 640 : .infinity)

                    if isWide { Spacer(minLength: 0) }
                }
            }
            .navigationTitle(L.s("settings.title"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var settingsList: some View {
        List {
            Section(header: Text(L.s("settings.language"))) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        currentLang = lang.rawValue
                    } label: {
                        HStack {
                            Text(lang.flag)
                            Text(lang.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if currentLang == lang.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(GSOColors.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section(header: Text(L.s("settings.appearance"))) {
                Picker(L.s("settings.appearance"), selection: $appearanceRaw) {
                    Text(L.s("settings.appearance.system")).tag(0)
                    Text(L.s("settings.appearance.light")).tag(1)
                    Text(L.s("settings.appearance.dark")).tag(2)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text(L.s("settings.accessibility")),
                    footer: Text(L.s("settings.accessibilityHint"))) {
                Toggle(isOn: $accessibilityMode) {
                    HStack {
                        Image(systemName: "accessibility")
                            .foregroundStyle(GSOColors.primary)
                        Text(L.s("settings.accessibilityToggle"))
                    }
                }
                .tint(GSOColors.primary)
            }

            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "building.columns.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                        Text("Georg-Simon-Ohm Berufskolleg Köln")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(L.s("settings.info"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }
}
