import SwiftUI

enum AppAppearance: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct GSONavApp: App {
    @AppStorage("appAppearance") private var appearanceRaw: Int = 0
    @State private var showSplash = true

    private var preferredColorScheme: ColorScheme? {
        (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainNavView()

                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(preferredColorScheme)
        }
    }
}
