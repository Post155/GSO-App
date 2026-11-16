import SwiftUI
import SceneKit

struct CampusView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GSOHeader()

                GeometryReader { geo in
                    let isWide = geo.size.width > geo.size.height && geo.size.width > 700

                    if isWide {
                        // iPad / Landscape: Side-by-Side
                        wideLayout
                    } else {
                        // iPhone / Portrait: vertikales Scrollen
                        compactLayout
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Compact (iPhone / Portrait)
    private var compactLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroHeader
                model3DSection(height: 280)
                panorama360Section
                footer
            }
        }
    }

    // MARK: - Wide (iPad Landscape)
    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroHeader

            HStack(alignment: .top, spacing: 16) {
                // Left: 3D Modell (groß)
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(titleKey: "gso.3d", icon: "cube.fill",
                                  hintKey: "gso.3dHint", hintIcon: "hand.draw")

                    SceneViewWrapper(modelName: "school_model")
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)

                // Right: 360° Panorama Liste
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

    private var heroHeader: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.s("gso.campusTitle"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(L.s("gso.campusSubtitle"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "building.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(GSOColors.primary.opacity(0.2))
            }
            .padding(.horizontal)
            .padding(.top, 16)

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
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private func sectionHeader(titleKey: String, icon: String,
                               hintKey: String, hintIcon: String) -> some View {
        HStack {
            Label(L.s(titleKey), systemImage: icon)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Spacer()
            Label(L.s(hintKey), systemImage: hintIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private func model3DSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(titleKey: "gso.3d", icon: "cube.fill",
                          hintKey: "gso.3dHint", hintIcon: "hand.draw")
                .padding(.horizontal)

            SceneViewWrapper(modelName: "school_model")
                .frame(height: height)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(.horizontal)
        }
    }

    private var panorama360Section: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(titleKey: "gso.360title", icon: "pano.fill",
                          hintKey: "gso.360hint", hintIcon: "arrow.triangle.2.circlepath")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Panorama360Card(imageName: "MiddleAreaB", title: L.s("gso.blockB"), accentColor: GSOColors.primary)
                    Panorama360Card(imageName: "MiddleAreaC", title: L.s("gso.blockC"), accentColor: GSOColors.primary)
                    Panorama360Card(imageName: "UpperLevelA", title: L.s("gso.upperA"), accentColor: GSOColors.primary)
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
                    .foregroundColor(.secondary.opacity(0.3))
                Text("Westerwaldstraße 92, Köln")
                    .font(.system(size: 11)).foregroundColor(.secondary.opacity(0.4))
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
                .font(.system(size: 13))
                .foregroundColor(GSOColors.primary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 360 Card (compact, horizontal scroll)

struct Panorama360Card: View {
    let imageName: String
    let title: String
    let accentColor: Color

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
                        .font(.system(size: 10))
                        .foregroundColor(accentColor)
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(width: 200)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
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
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: "pano.fill")
                            .font(.system(size: 9))
                            .foregroundColor(GSOColors.primary)
                        Text(L.s("gso.360title"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
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
