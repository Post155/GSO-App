import SwiftUI
import SceneKit

#Preview {
    CampusView()
}

struct CampusView: View {
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isWide = geo.size.width > geo.size.height && geo.size.width > 700

                Group {
                    if isWide {
                        wideLayout
                    } else {
                        compactLayout
                    }
                }
            }
            .navigationTitle(L.s("gso.campusTitle"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Compact (iPhone / Portrait)
    private var compactLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsCard
                model3DSection(height: 280)
                panorama360Section
                footer
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Wide (iPad Landscape)
    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            statsCard
                .padding(.horizontal)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(titleKey: "gso.3d", icon: "cube.fill",
                                  hintKey: "gso.3dHint", hintIcon: "hand.draw")

                    SceneViewWrapper(modelName: "school_model")
                        .gsoFloatingCard()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(titleKey: "gso.360title", icon: "pano.fill",
                                  hintKey: "gso.360hint", hintIcon: "arrow.triangle.2.circlepath")

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            Panorama360RowCard(imageName: "MiddleAreaB", title: L.s("gso.blockB"))
                            Panorama360RowCard(imageName: "MiddleAreaC", title: L.s("gso.blockC"))
                            Panorama360RowCard(imageName: "UpperLevelA", title: L.s("gso.upperA"))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: 380)
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)

            footer
        }
        .padding(.top, 12)
    }

    // MARK: - Shared Pieces

    private var statsCard: some View {
        HStack(spacing: 0) {
            StatPill(value: "2.560", label: L.s("gso.stats.students"), icon: "person.2.fill")
            Divider().frame(height: 30)
            StatPill(value: "80", label: L.s("gso.stats.teachers"), icon: "person.fill")
            Divider().frame(height: 30)
            StatPill(value: "1822", label: L.s("gso.stats.founded"), icon: "calendar")
            Divider().frame(height: 30)
            StatPill(value: "3", label: L.s("gso.stats.buildings"), icon: "building.fill")
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: GSOMetrics.cardRadius, style: .continuous))
        .padding(.horizontal)
    }

    private func sectionHeader(titleKey: String, icon: String,
                               hintKey: String, hintIcon: String) -> some View {
        HStack {
            Label(L.s(titleKey), systemImage: icon)
                .font(.headline)
            Spacer()
            Label(L.s(hintKey), systemImage: hintIcon)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func model3DSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(titleKey: "gso.3d", icon: "cube.fill",
                          hintKey: "gso.3dHint", hintIcon: "hand.draw")

            SceneViewWrapper(modelName: "school_model")
                .frame(height: height)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: GSOMetrics.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: GSOMetrics.cardRadius, style: .continuous)
                        .stroke(GSOMetrics.hairlineColor, lineWidth: GSOMetrics.hairline)
                )
                .padding(.horizontal)
        }
    }

    private var panorama360Section: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(titleKey: "gso.360title", icon: "pano.fill",
                          hintKey: "gso.360hint", hintIcon: "arrow.triangle.2.circlepath")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Panorama360Card(imageName: "MiddleAreaB", title: L.s("gso.blockB"))
                    Panorama360Card(imageName: "MiddleAreaC", title: L.s("gso.blockC"))
                    Panorama360Card(imageName: "UpperLevelA", title: L.s("gso.upperA"))
                }
                .padding(.horizontal)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "building.columns.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Westerwaldstraße 92, Köln")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(GSOColors.primary)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 360 Card (compact, horizontal scroll)

struct Panorama360Card: View {
    let imageName: String
    let title: String

    var body: some View {
        NavigationLink(destination: Room360View(imageName: imageName, roomName: title)) {
            VStack(spacing: 0) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 120)
                    .clipped()

                HStack {
                    Image(systemName: "pano")
                        .font(.caption2)
                        .foregroundStyle(GSOColors.primary)
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(width: 200)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous)
                    .stroke(GSOMetrics.hairlineColor, lineWidth: GSOMetrics.hairline)
            )
        }
    }
}

// MARK: - 360 Row Card (full-width, used in iPad landscape)

struct Panorama360RowCard: View {
    let imageName: String
    let title: String

    var body: some View {
        NavigationLink(destination: Room360View(imageName: imageName, roomName: title)) {
            HStack(spacing: 12) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: "pano.fill")
                            .font(.caption2)
                            .foregroundStyle(GSOColors.primary)
                        Text(L.s("gso.360title"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous)
                    .stroke(GSOMetrics.hairlineColor, lineWidth: GSOMetrics.hairline)
            )
        }
    }
}

// MARK: - Scene View

struct SceneViewWrapper: UIViewRepresentable {
    let modelName: String

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X

        if let url = Bundle.main.url(forResource: modelName, withExtension: "usdz") {
            if let scene = try? SCNScene(url: url, options: nil) {
                view.scene = scene
            }
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
