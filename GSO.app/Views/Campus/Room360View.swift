import SwiftUI
import SceneKit

struct Room360View: View {
    let imageName: String
    let roomName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PanoramaView(imageName: imageName)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text(roomName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        HStack(spacing: 4) {
                            Image(systemName: "pano.fill")
                                .font(.system(size: 9))
                            Text(L.s("gso.360title"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                    .colorScheme(.dark)
                    Spacer()
                }
                .padding(.top, 12)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 11))
                    Text(L.s("gso.360hint"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.7))
                .clipShape(Capsule())
                .colorScheme(.dark)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - SceneKit 360° Panorama Viewer

struct PanoramaView: UIViewRepresentable {
    let imageName: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = false
        scnView.backgroundColor = .black

        #if !targetEnvironment(simulator)
        scnView.antialiasingMode = .multisampling4X
        #else
        scnView.antialiasingMode = .none
        #endif

        let scene = SCNScene()
        scnView.scene = scene

        // Larger sphere reduces perspective distortion at the edges
        let sphere = SCNSphere(radius: 50.0)
        sphere.segmentCount = 96
        sphere.isGeodesic = false

        let material = SCNMaterial()
        if let processed = Self.processedPanoramaImage(named: imageName) {
            material.diffuse.contents = processed
        } else {
            material.diffuse.contents = UIColor(white: 0.15, alpha: 1.0)
        }
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.diffuse.minificationFilter = .linear
        material.diffuse.magnificationFilter = .linear
        material.diffuse.mipFilter = .linear
        material.lightingModel = .constant
        material.isDoubleSided = true
        sphere.materials = [material]

        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3Zero
        // Flip sphere inside-out so we see the texture from inside
        sphereNode.scale = SCNVector3(-1, 1, 1)
        scene.rootNode.addChildNode(sphereNode)

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 75
        camera.zNear = 0.05
        camera.zFar = 200
        cameraNode.camera = camera
        cameraNode.position = SCNVector3Zero
        scene.rootNode.addChildNode(cameraNode)

        context.coordinator.cameraNode = cameraNode
        context.coordinator.camera = camera

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePinch(_:)))
        scnView.addGestureRecognizer(pinch)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: - Image processing
    // Pads non-2:1 panoramas with black bars to true equirectangular ratio
    // and downscales oversized textures (Simulator Metal limit = 8192x8192).
    static func processedPanoramaImage(named: String) -> UIImage? {
        guard let original = UIImage(named: named) else { return nil }

        let cgSize = original.size
        guard cgSize.width > 0, cgSize.height > 0 else { return original }

        let originalAspect = cgSize.width / cgSize.height
        let targetAspect: CGFloat = 2.0  // true equirectangular = 2:1

        // Compute canvas: pad height upwards if image is too wide for 2:1
        var canvas = cgSize
        if originalAspect > targetAspect {
            canvas.height = cgSize.width / targetAspect
        } else if originalAspect < targetAspect {
            canvas.width = cgSize.height * targetAspect
        }

        // Cap canvas width at 8192 (Simulator Metal limit; safe on devices too)
        let maxDim: CGFloat = 8192
        if canvas.width > maxDim {
            let scale = maxDim / canvas.width
            canvas = CGSize(width: maxDim, height: canvas.height * scale)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)

        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))

            // Fit original into canvas keeping aspect, centered vertically
            let scaleFactor = canvas.width / cgSize.width
            let drawW = cgSize.width * scaleFactor
            let drawH = cgSize.height * scaleFactor
            let drawX = (canvas.width - drawW) / 2
            let drawY = (canvas.height - drawH) / 2
            original.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
        }
    }

    final class Coordinator: NSObject {
        weak var cameraNode: SCNNode?
        weak var camera: SCNCamera?

        private var yaw: Float = 0
        private var pitch: Float = 0
        private var lastPanPoint: CGPoint = .zero

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let cam = cameraNode else { return }
            let p = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                lastPanPoint = p
            case .changed:
                let dx = Float(p.x - lastPanPoint.x)
                let dy = Float(p.y - lastPanPoint.y)
                let sensitivity: Float = 0.0045
                yaw   -= dx * sensitivity
                pitch -= dy * sensitivity
                let pitchLimit = Float.pi / 2 - 0.05
                pitch = max(-pitchLimit, min(pitchLimit, pitch))
                cam.eulerAngles = SCNVector3(pitch, yaw, 0)
                lastPanPoint = p
            default:
                lastPanPoint = .zero
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let camera = camera else { return }
            let scale = Double(gesture.scale)
            var newFov = camera.fieldOfView / scale
            newFov = max(35, min(105, newFov))
            camera.fieldOfView = newFov
            gesture.scale = 1.0
        }
    }
}
