import SwiftUI

struct GSOHeader: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            // Modern logo
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 9 : 12)
                    .fill(.white)
                    .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                Text("GSO")
                    .font(.system(size: compact ? 11 : 13, weight: .heavy, design: .rounded))
                    .foregroundColor(GSOColors.primary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Georg-Simon-Ohm")
                    .font(.system(size: compact ? 13 : 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Berufskolleg Köln")
                    .font(.system(size: compact ? 9 : 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 7 : 12)
        .background(.ultraThinMaterial)
    }
}
