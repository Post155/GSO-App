import SwiftUI

enum GSOColors {
    /// System blue — matches Apple's own apps (Maps, Settings) instead of a custom brand tone.
    static let primary = Color.blue
}

/// Shared layout tokens so every screen uses the same spacing/radius scale
/// instead of each view inventing its own numbers.
enum GSOMetrics {
    static let cardRadius: CGFloat = 16
    static let sheetRadius: CGFloat = 20
    static let controlRadius: CGFloat = 12
    static let pillRadius: CGFloat = 10

    static let hairline: CGFloat = 0.5
    static let hairlineColor = Color.primary.opacity(0.08)
}

extension View {
    /// Apple-style floating card: translucent material, hairline border, soft shadow.
    func gsoFloatingCard(radius: CGFloat = GSOMetrics.cardRadius) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(GSOMetrics.hairlineColor, lineWidth: GSOMetrics.hairline)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }

    /// Small floating circular control button, like Apple Maps' locate-me/compass buttons.
    func gsoFloatingButton() -> some View {
        self
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(GSOMetrics.hairlineColor, lineWidth: GSOMetrics.hairline))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
    }
}
