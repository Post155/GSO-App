import SwiftUI

struct MainNavView: View {
    @AppStorage("appLanguage") private var langTick = "de"

    var body: some View {
        TabView {
            IndoorNavView()
                .tabItem {
                    Label(L.s("tab.nav"), systemImage: "location.fill")
                }

            CampusView()
                .tabItem {
                    Label(L.s("tab.3d"), systemImage: "building.2.fill")
                }

            SettingsView()
                .tabItem {
                    Label(L.s("settings.title"), systemImage: "gearshape.fill")
                }
        }
        .tint(GSOColors.primary)
        .id(langTick) // force refresh on language change
    }
}
