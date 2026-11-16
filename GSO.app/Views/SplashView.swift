import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.2, blue: 0.55),
                    GSOColors.primary,
                    Color(red: 0.0, green: 0.15, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    // Outer ring pulse
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Inner ring
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Logo
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 90, height: 90)
                            .shadow(color: .white.opacity(0.3), radius: 20)

                        Text("GSO")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(GSOColors.primary)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                }

                VStack(spacing: 10) {
                    Text("GSO Navigation")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(titleOpacity)

                    Text("Georg-Simon-Ohm Berufskolleg")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(subtitleOpacity)
                }

                Spacer()

                VStack(spacing: 6) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Indoor Navigation & 3D Campus")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
                .opacity(subtitleOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringScale = 1.1
                ringOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                titleOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.9)) {
                subtitleOpacity = 1.0
            }
            // Auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    onFinished()
                }
            }
        }
    }
}
