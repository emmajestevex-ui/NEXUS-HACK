import SwiftUI
import SceneKit
import UIKit

struct CharacterViewer: UIViewRepresentable {
    let accent: UIColor
    static var available: Bool { Bundle.main.url(forResource: "character", withExtension: "mesh") != nil }
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.scene = Self.scene(accent: accent)
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.isPlaying = true
        return view
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
    private static func scene(accent: UIColor) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let camera = SCNNode(); camera.name = "camera"; camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.20
        camera.camera?.projectionDirection = .vertical
        camera.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(camera)
        func light(_ type: SCNLight.LightType, _ color: UIColor, _ intensity: CGFloat, _ position: SCNVector3) {
            let node = SCNNode(); node.light = SCNLight(); node.light?.type = type
            node.light?.color = color; node.light?.intensity = intensity; node.position = position
            scene.rootNode.addChildNode(node)
        }
        // Keep the baked base-color texture natural; no colored light on skin or clothing.
        light(.ambient, .white, 550, SCNVector3(0, 0, 0))
        light(.directional, .white, 350, SCNVector3(-2, 3, 4))
        guard let url = Bundle.main.url(forResource: "character", withExtension: "mesh"),
              let raw = try? Data(contentsOf: url), raw.count > 8,
              raw.prefix(4) == Data([78, 51, 68, 49]) else { return scene }
        let count = raw[4..<8].enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
        guard count > 0, count % 3 == 0, count <= 1_000_000, raw.count == 8 + count * 32 else { return scene }
        // FBX UVs are bottom-origin, but this SceneKit image path samples top-origin.
        // The optimized mesh retains the original FBX coordinates.
        var payload = Data(raw.dropFirst(8))
        payload.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            for i in 0..<count {
                let offset = i * 32 + 28
                let bits = bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                let v = Float(bitPattern: UInt32(littleEndian: bits))
                bytes.storeBytes(of: (1 - v).bitPattern.littleEndian, toByteOffset: offset, as: UInt32.self)
            }
        }
        func source(_ semantic: SCNGeometrySource.Semantic, _ offset: Int, _ components: Int) -> SCNGeometrySource {
            SCNGeometrySource(data: payload, semantic: semantic, vectorCount: count, usesFloatComponents: true, componentsPerVector: components, bytesPerComponent: 4, dataOffset: offset, dataStride: 32)
        }
        let indices = (0..<count).map { UInt32($0).littleEndian }
        let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles, primitiveCount: count / 3, bytesPerIndex: 4)
        let geometry = SCNGeometry(sources: [source(.vertex, 0, 3), source(.normal, 12, 3), source(.texcoord, 24, 2)], elements: [element])
        let material = SCNMaterial(); material.lightingModel = .constant; material.isDoubleSided = true
        func texture(_ name: String) -> UIImage? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "jpg") else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
        // Base color already includes the character's shading. Constant lighting avoids
        // overexposure and metallic artifacts. Other texture files remain bundled.
        if let colorMap = texture("basecolor") {
            material.diffuse.contents = colorMap
        } else {
            material.diffuse.contents = UIColor.white
        }
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.diffuse.magnificationFilter = .linear
        material.diffuse.minificationFilter = .linear
        material.diffuse.mipFilter = .linear
        geometry.materials = [material]
        let model = SCNNode(geometry: geometry); scene.rootNode.addChildNode(model)
        let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 12)
        spin.timingMode = .linear; model.runAction(.repeatForever(spin))
        return scene
    }
}
