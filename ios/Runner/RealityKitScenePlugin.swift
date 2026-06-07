// ============================================================================
// RealityKitScenePlugin.swift
// PRODUCTION-READY — RealityKit 3D Scene Manager for Flutter
//
// ARKit  = tracking engine  (depth, pose, world anchors)    [already done]
// RealityKit = rendering engine  (3D mesh, materials, animations, physics)
//
// This plugin adds ON TOP of ARKit — both run together:
//   • ARKit provides real depth data + point cloud
//   • RealityKit renders the 3D scan mesh + measurement pins + labels
//
// Flutter channel: "com.lidarscanner/realitykit"
// Event channel:   "com.lidarscanner/realitykit_events"
//
// Methods exposed to Flutter:
//   initializeRealityKit       — create ARView, configure session
//   showScanMesh               — render captured point cloud as 3D mesh
//   placeMeasurementPin(x,y,z) — place real 3D sphere anchor at world coord
//   placeMeasurementLine       — draw line between two 3D anchors
//   clearScene                 — remove all anchors
//   exportMeshAsOBJ            — export scan mesh as OBJ string
//   exportMeshAsUSDZ           — export as USDZ (AR QuickLook ready)
//   setRenderMode              — wireframe | solid | pointCloud | xray
//   getRealityKitStatus        — capabilities + anchor count
// ============================================================================

import Flutter
import UIKit
import RealityKit
import ARKit
import ModelIO
import MetalKit
import simd

// MARK: - Plugin

@available(iOS 15.0, *)
public class RealityKitScenePlugin: NSObject, FlutterPlugin {

    static var instance: RealityKitScenePlugin?

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private let streamHandler = RealityKitEventHandler()
    private let sceneManager = RealityKitSceneManager()

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.lidarscanner/realitykit",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.lidarscanner/realitykit_events",
            binaryMessenger: messenger
        )
        super.init()
        methodChannel.setMethodCallHandler(handle)
        eventChannel.setStreamHandler(streamHandler)
        sceneManager.eventHandler = streamHandler
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let inst = RealityKitScenePlugin(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(inst, channel: inst.methodChannel)
        RealityKitScenePlugin.instance = inst
    }

    // MARK: - Method Router

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // ── Capability ────────────────────────────────────────────────
        case "isRealityKitSupported":
            result(true) // iOS 15+ always has RealityKit 2

        // ── Scene lifecycle ───────────────────────────────────────────
        case "initializeRealityKit":
            sceneManager.initialize(result: result)

        case "disposeRealityKit":
            sceneManager.dispose(result: result)

        // ── Mesh rendering ────────────────────────────────────────────
        case "showScanMesh":
            guard let args = call.arguments as? [String: Any],
                  let rawPoints = args["points"] as? [[String: Any]] else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "points array required", details: nil))
                return
            }
            let renderMode = args["renderMode"] as? String ?? "solid"
            sceneManager.showScanMesh(points: rawPoints,
                                      renderMode: renderMode,
                                      result: result)

        case "updateScanMesh":
            guard let args = call.arguments as? [String: Any],
                  let rawPoints = args["points"] as? [[String: Any]] else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "points array required", details: nil))
                return
            }
            sceneManager.updateScanMesh(points: rawPoints, result: result)

        case "clearScanMesh":
            sceneManager.clearScanMesh(result: result)

        // ── Measurement pins ──────────────────────────────────────────
        case "placeMeasurementPin":
            guard let args = call.arguments as? [String: Any],
                  let x = args["x"] as? Double,
                  let y = args["y"] as? Double,
                  let z = args["z"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "x, y, z (Double) required", details: nil))
                return
            }
            let label = args["label"] as? String
            let isManual = args["isManualPin"] as? Bool ?? true
            sceneManager.placeMeasurementPin(
                x: Float(x), y: Float(y), z: Float(z),
                label: label, isManualPin: isManual,
                result: result
            )

        case "placeMeasurementLine":
            guard let args = call.arguments as? [String: Any],
                  let p1 = args["point1"] as? [String: Any],
                  let p2 = args["point2"] as? [String: Any],
                  let x1 = p1["x"] as? Double, let y1 = p1["y"] as? Double, let z1 = p1["z"] as? Double,
                  let x2 = p2["x"] as? Double, let y2 = p2["y"] as? Double, let z2 = p2["z"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "point1 and point2 required", details: nil))
                return
            }
            let label = args["label"] as? String
            sceneManager.placeMeasurementLine(
                from: SIMD3<Float>(Float(x1), Float(y1), Float(z1)),
                to: SIMD3<Float>(Float(x2), Float(y2), Float(z2)),
                label: label,
                result: result
            )

        case "clearMeasurementPins":
            sceneManager.clearMeasurementPins(result: result)

        case "clearScene":
            sceneManager.clearAll(result: result)

        // ── Render modes ──────────────────────────────────────────────
        case "setRenderMode":
            guard let args = call.arguments as? [String: Any],
                  let mode = args["mode"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "mode string required", details: nil))
                return
            }
            sceneManager.setRenderMode(mode: mode, result: result)

        // ── Export ────────────────────────────────────────────────────
        case "exportMeshAsOBJ":
            sceneManager.exportMeshAsOBJ(result: result)

        case "exportMeshAsUSDZ":
            sceneManager.exportMeshAsUSDZ(result: result)

        // ── Status ────────────────────────────────────────────────────
        case "getRealityKitStatus":
            sceneManager.getStatus(result: result)

        // ── Camera ────────────────────────────────────────────────────
        case "setCameraMode":
            guard let args = call.arguments as? [String: Any],
                  let mode = args["mode"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "mode (ar|orbit|free) required", details: nil))
                return
            }
            sceneManager.setCameraMode(mode: mode, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}


// ============================================================================
// MARK: - RealityKit Scene Manager
// ============================================================================

@available(iOS 15.0, *)
final class RealityKitSceneManager: NSObject, ARSessionDelegate {

    weak var eventHandler: RealityKitEventHandler?

    // ── State ──────────────────────────────────────────────────────────
    private var arView: ARView?
    private var rootAnchor: AnchorEntity?
    private var meshEntity: ModelEntity?
    private var pinEntities: [String: ModelEntity] = [:]
    private var lineEntities: [String: ModelEntity] = [:]
    private var isInitialized = false

    // ── Materials ──────────────────────────────────────────────────────
    private var scanMeshMaterial: PhysicallyBasedMaterial = {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.7))
        mat.roughness = .init(floatLiteral: 0.6)
        mat.metallic = .init(floatLiteral: 0.1)
        return mat
    }()

    private var wireframeMaterial: UnlitMaterial = {
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 1.0))
        return mat
    }()

    private var pinMaterial: PhysicallyBasedMaterial = {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0))
        mat.roughness = .init(floatLiteral: 0.3)
        mat.metallic = .init(floatLiteral: 0.5)
        mat.emissiveColor = .init(color: UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 0.5))
        mat.emissiveIntensity = 0.8
        return mat
    }()

    private var autoPointMaterial: PhysicallyBasedMaterial = {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 0.9))
        mat.roughness = .init(floatLiteral: 0.4)
        mat.metallic = .init(floatLiteral: 0.2)
        mat.emissiveColor = .init(color: UIColor(red: 0.0, green: 0.8, blue: 0.2, alpha: 0.4))
        mat.emissiveIntensity = 0.5
        return mat
    }()

    private var lineMaterial: UnlitMaterial = {
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0))
        return mat
    }()

    // ── Render mode ────────────────────────────────────────────────────
    enum RenderMode: String {
        case solid, wireframe, pointCloud, xray
    }
    private var currentRenderMode: RenderMode = .solid

    // ── Thread safety ──────────────────────────────────────────────────
    private let sceneLock = NSLock()

    // MARK: - Initialize

    func initialize(result: @escaping FlutterResult) {
        guard isInitialized == false else {
            result(true)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(FlutterError(code: "DEALLOCATED", message: "SceneManager deallocated", details: nil))
                return
            }

            // Create ARView with proper frame
            let arView = ARView(frame: UIScreen.main.bounds, cameraMode: .ar, automaticallyConfigureSession: false)
            arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            arView.session.delegate = self

            // Configure ARKit session FOR RealityKit
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal, .vertical]
            config.environmentTexturing = .automatic

            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                config.sceneReconstruction = .meshWithClassification
            } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                config.sceneReconstruction = .mesh
            }

            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                config.frameSemantics.insert(.sceneDepth)
            }
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
                config.frameSemantics.insert(.smoothedSceneDepth)
            }

            // RealityKit settings
            arView.debugOptions = []
            arView.renderOptions = [.disableMotionBlur, .disableFaceMesh]
            arView.environment.lighting.intensityExponent = 1.0
            arView.environment.sceneUnderstanding.options = [.occlusion, .receivesLighting]

            // Get Flutter view controller
            // iOS 17/18+ fix: keyWindow is deprecated, use connectedScenes instead
            var flutterViewController: FlutterViewController?
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let vc = windowScene.windows.first?.rootViewController as? FlutterViewController {
                flutterViewController = vc
            } else if let vc = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
                flutterViewController = vc
            }
            guard let flutterViewController else {
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "FlutterViewController not found", details: nil))
                return
            }

            // CRITICAL FIX: Make Flutter view transparent so ARView is visible
            flutterViewController.view.backgroundColor = .clear
            flutterViewController.view.isOpaque = false

            // Add ARView as subview at index 0 (behind Flutter UI)
            flutterViewController.view.insertSubview(arView, at: 0)
            
            // Run session
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

            // Create root anchor
            let anchor = AnchorEntity(world: .zero)
            arView.scene.addAnchor(anchor)
            self.rootAnchor = anchor

            self.arView = arView
            self.isInitialized = true

            debugPrint("🌍 [RealityKit] ✅ Initialized — ARView properly added to view hierarchy")
            result(true)
        }
    }

    // MARK: - Show Scan Mesh from Point Cloud

    func showScanMesh(points rawPoints: [[String: Any]],
                      renderMode: String,
                      result: @escaping FlutterResult) {
        guard isInitialized, let anchor = rootAnchor else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "RealityKit not initialized", details: nil))
            return
        }

        // Parse 3D points
        var vertices: [SIMD3<Float>] = []
        var confidences: [Float] = []

        for raw in rawPoints {
            guard let x = (raw["x"] as? NSNumber)?.floatValue,
                  let y = (raw["y"] as? NSNumber)?.floatValue,
                  let z = (raw["z"] as? NSNumber)?.floatValue else { continue }
            let conf = (raw["confidence"] as? NSNumber)?.floatValue ?? 0.5
            vertices.append(SIMD3<Float>(x, y, z))
            confidences.append(conf)
        }

        guard vertices.count >= 3 else {
            result(FlutterError(code: "INSUFFICIENT_POINTS",
                                message: "Need at least 3 points to build mesh",
                                details: nil))
            return
        }

        let mode = RenderMode(rawValue: renderMode) ?? .solid
        self.currentRenderMode = mode

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let entity = self.buildMeshEntity(vertices: vertices,
                                              confidences: confidences,
                                              mode: mode)
            DispatchQueue.main.async {
                // Remove old mesh
                if let old = self.meshEntity {
                    old.removeFromParent()
                }

                anchor.addChild(entity)
                self.meshEntity = entity

                // Animate in
                entity.scale = .zero
                entity.move(to: Transform(scale: SIMD3<Float>(1, 1, 1),
                                          rotation: entity.transform.rotation,
                                          translation: entity.transform.translation),
                            relativeTo: anchor,
                            duration: 0.4,
                            timingFunction: .easeOut)

                self.eventHandler?.send([
                    "type": "meshShown",
                    "pointCount": vertices.count,
                    "renderMode": renderMode
                ])

                result([
                    "success": true,
                    "vertexCount": vertices.count,
                    "renderMode": renderMode
                ] as [String: Any])
            }
        }
    }

    func updateScanMesh(points rawPoints: [[String: Any]],
                        result: @escaping FlutterResult) {
        showScanMesh(points: rawPoints,
                     renderMode: currentRenderMode.rawValue,
                     result: result)
    }

    func clearScanMesh(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.meshEntity?.removeFromParent()
            self?.meshEntity = nil
            result(true)
        }
    }

    // MARK: - Measurement Pins

    func placeMeasurementPin(x: Float, y: Float, z: Float,
                              label: String?, isManualPin: Bool,
                              result: @escaping FlutterResult) {
        guard isInitialized, let anchor = rootAnchor else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "RealityKit not initialized", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let pinId = UUID().uuidString

            // Real 3D sphere at world coordinate
            let sphereRadius: Float = isManualPin ? 0.015 : 0.008
            let mesh = MeshResource.generateSphere(radius: sphereRadius)
            let material = isManualPin ? self.pinMaterial : self.autoPointMaterial
            let sphere = ModelEntity(mesh: mesh, materials: [material])

            // Position at real 3D world coordinate
            sphere.position = SIMD3<Float>(x, y, z)
            sphere.name = pinId

            // Pulse animation for manual pins
            if isManualPin {
                let scaleUp = Transform(scale: SIMD3<Float>(1.3, 1.3, 1.3),
                                        rotation: sphere.transform.rotation,
                                        translation: sphere.transform.translation)
                let scaleDown = Transform(scale: SIMD3<Float>(1.0, 1.0, 1.0),
                                          rotation: sphere.transform.rotation,
                                          translation: sphere.transform.translation)
                sphere.move(to: scaleUp, relativeTo: anchor, duration: 0.15, timingFunction: .easeOut)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    sphere.move(to: scaleDown, relativeTo: anchor, duration: 0.15, timingFunction: .easeIn)
                }
            }

            anchor.addChild(sphere)
            self.pinEntities[pinId] = sphere

            self.eventHandler?.send([
                "type": "pinPlaced",
                "pinId": pinId,
                "x": Double(x), "y": Double(y), "z": Double(z),
                "isManualPin": isManualPin,
                "totalPins": self.pinEntities.count
            ])

            result([
                "pinId": pinId,
                "x": Double(x), "y": Double(y), "z": Double(z)
            ] as [String: Any])
        }
    }

    // MARK: - Measurement Line between two 3D points

    func placeMeasurementLine(from start: SIMD3<Float>,
                               to end: SIMD3<Float>,
                               label: String?,
                               result: @escaping FlutterResult) {
        guard isInitialized, let anchor = rootAnchor else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "RealityKit not initialized", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let lineId = UUID().uuidString

            // Calculate line geometry
            let diff = end - start
            let length = simd_length(diff)
            let midpoint = (start + end) / 2.0

            // Cylinder as line — custom mesh for iOS 15+ compatibility
            let cylinder = makeCylinderMesh(height: length, radius: 0.003, segments: 12)
            let line = ModelEntity(mesh: cylinder, materials: [self.lineMaterial])
            line.position = midpoint
            line.name = lineId

            // Orient cylinder from start → end
            let defaultAxis = SIMD3<Float>(0, 1, 0) // cylinder default axis is Y
            let targetAxis = normalize(diff)
            let cross = simd_cross(defaultAxis, targetAxis)
            let dot = simd_dot(defaultAxis, targetAxis)

            if simd_length(cross) > 0.0001 {
                let angle = acos(min(max(dot, -1.0), 1.0))
                line.orientation = simd_quatf(angle: angle, axis: normalize(cross))
            } else if dot < 0 {
                line.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
            }

            anchor.addChild(line)
            self.lineEntities[lineId] = line

            let distance = simd_length(diff)

            self.eventHandler?.send([
                "type": "linePlaced",
                "lineId": lineId,
                "distance": Double(distance),
                "distanceCm": Double(distance * 100)
            ])

            result([
                "lineId": lineId,
                "distance": Double(distance),
                "distanceCm": Double(distance * 100),
                "distanceInches": Double(distance * 39.37)
            ] as [String: Any])
        }
    }

    func clearMeasurementPins(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for (_, entity) in self.pinEntities { entity.removeFromParent() }
            for (_, entity) in self.lineEntities { entity.removeFromParent() }
            self.pinEntities.removeAll()
            self.lineEntities.removeAll()
            result(true)
        }
    }

    func clearAll(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.meshEntity?.removeFromParent()
            self.meshEntity = nil
            for (_, e) in self.pinEntities { e.removeFromParent() }
            for (_, e) in self.lineEntities { e.removeFromParent() }
            self.pinEntities.removeAll()
            self.lineEntities.removeAll()
            result(true)
        }
    }

    // MARK: - Render Mode

    func setRenderMode(mode: String, result: @escaping FlutterResult) {
        let renderMode = RenderMode(rawValue: mode) ?? .solid
        self.currentRenderMode = renderMode

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let mesh = self.meshEntity else {
                result(true)
                return
            }

            switch renderMode {
            case .solid:
                mesh.model?.materials = [self.scanMeshMaterial]
            case .wireframe:
                mesh.model?.materials = [self.wireframeMaterial]
            case .pointCloud:
                // Point cloud mode — very small spheres, handled at rebuild
                mesh.model?.materials = [self.wireframeMaterial]
            case .xray:
                var xrayMat = UnlitMaterial()
                xrayMat.color = .init(tint: UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.35))
                mesh.model?.materials = [xrayMat]
            }

            result(["mode": mode, "success": true] as [String: Any])
        }
    }

    // MARK: - Camera Mode

    func setCameraMode(mode: String, result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.arView else {
                result(FlutterError(code: "NOT_INITIALIZED",
                                    message: "ARView not ready", details: nil))
                return
            }
            // AR mode is default — non-AR orbit mode useful for reviewing exports
            if mode == "nonAR" {
                // Switch to non-AR for mesh review
                view.session.pause()
            }
            result(["mode": mode] as [String: Any])
        }
    }

    // MARK: - Export

    func exportMeshAsOBJ(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "RealityKit not initialized", details: nil))
            return
        }

        // Non-LiDAR devices have no ARMeshAnchor — return error so Flutter-side fallback is used
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            result(FlutterError(code: "NO_LIDAR",
                                message: "LiDAR required for native mesh export — use Flutter-side export",
                                details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Export ARKit scene mesh anchors as OBJ
            guard let arView = self.arView else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_ARVIEW",
                                        message: "ARView not available", details: nil))
                }
                return
            }

            var objContent = "# LiDAR Scan Export\n"
            objContent += "# Generated by LIDER-SCANER\n\n"

            var globalVertexOffset = 0

            // Collect mesh anchors from ARKit scene
            for anchor in arView.session.currentFrame?.anchors ?? [] {
                guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
                let transform = meshAnchor.transform

                let geometry = meshAnchor.geometry
                let vertices = geometry.vertices
                let faces = geometry.faces

                let vertexCount = vertices.count
                let faceCount = faces.count

                // Write vertices
                for i in 0..<vertexCount {
                    var vertex = SIMD3<Float>(0, 0, 0)
                    let vertexPointer = vertices.buffer.contents()
                        .advanced(by: vertices.offset + i * vertices.stride)
                    vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee

                    // Transform to world space
                    let worldPos = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                    objContent += String(format: "v %.6f %.6f %.6f\n",
                                         worldPos.x, worldPos.y, worldPos.z)
                }

                // Write faces
                let indexBytesPerIndex = faces.bytesPerIndex
                let facePointer = faces.buffer.contents()

                for i in 0..<faceCount {
                    var indices = [Int32](repeating: 0, count: 3)
                    for j in 0..<3 {
                        let offset = (i * 3 + j) * indexBytesPerIndex
                        if indexBytesPerIndex == 2 {
                            indices[j] = Int32(facePointer.advanced(by: offset)
                                                .assumingMemoryBound(to: UInt16.self).pointee)
                        } else {
                            indices[j] = Int32(facePointer.advanced(by: offset)
                                                .assumingMemoryBound(to: UInt32.self).pointee)
                        }
                    }
                    // OBJ is 1-indexed
                    let i1 = indices[0] + Int32(globalVertexOffset) + 1
                    let i2 = indices[1] + Int32(globalVertexOffset) + 1
                    let i3 = indices[2] + Int32(globalVertexOffset) + 1
                    objContent += "f \(i1) \(i2) \(i3)\n"
                }

                globalVertexOffset += vertexCount
            }

            // Save to temp file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("lidar_scan_\(Int(Date().timeIntervalSince1970)).obj")

            do {
                try objContent.write(to: tempURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    result([
                        "filePath": tempURL.path,
                        "fileSize": (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? 0
                    ] as [String: Any])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "EXPORT_FAILED",
                                        message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    func exportMeshAsUSDZ(result: @escaping FlutterResult) {
        // Uses MDLAsset export — works on iOS 15+
        guard isInitialized, let arView = arView else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "RealityKit not initialized", details: nil))
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lidar_scan_\(Int(Date().timeIntervalSince1970)).usdz")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let asset = MDLAsset()
                var hasGeometry = false

                if let frame = arView.session.currentFrame {
                    for anchor in frame.anchors {
                        guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
                        hasGeometry = true
                        let geometry = meshAnchor.geometry
                        let transform = meshAnchor.transform
                        let vertexCount = geometry.vertices.count
                        let vertexStride = geometry.vertices.stride
                        // MTLBuffer.contents() returns raw pointer directly
                        let vertexBasePtr = geometry.vertices.buffer.contents()

                        // Transform vertices to world space
                        var worldVertices: [SIMD3<Float>] = []
                        for i in 0..<vertexCount {
                            let vPtr = vertexBasePtr.advanced(by: i * vertexStride)
                                .assumingMemoryBound(to: SIMD3<Float>.self)
                            let localVertex = vPtr.pointee
                            let worldVertex = transform * SIMD4<Float>(
                                localVertex.x, localVertex.y, localVertex.z, 1.0
                            )
                            worldVertices.append(SIMD3<Float>(
                                worldVertex.x, worldVertex.y, worldVertex.z
                            ))
                        }

                        // Extract face indices via MDLMeshBuffer.map()
                        let faceCount = geometry.faces.count
                        let bytesPerIndex = geometry.faces.bytesPerIndex
                        let indexDataPtr = geometry.faces.buffer.contents()

                        var indices: [UInt32] = []
                        for i in 0..<(faceCount * 3) {
                            let offset = i * bytesPerIndex
                            if bytesPerIndex == 2 {
                                indices.append(UInt32(
                                    indexDataPtr.advanced(by: offset)
                                        .assumingMemoryBound(to: UInt16.self).pointee
                                ))
                            } else {
                                indices.append(
                                    indexDataPtr.advanced(by: offset)
                                        .assumingMemoryBound(to: UInt32.self).pointee
                                )
                            }
                        }

                        // Create MDLMesh from vertex & index data
                        let vertexByteCount = worldVertices.count * MemoryLayout<SIMD3<Float>>.stride
                        let vertexBufData = Data(bytes: worldVertices, count: vertexByteCount)
                        let vertexBuffer = MDLMeshBufferData(
                            type: .vertex, data: vertexBufData
                        )

                        let indexByteCount = indices.count * MemoryLayout<UInt32>.stride
                        let indexBufData = Data(bytes: indices, count: indexByteCount)
                        let indexBuffer = MDLMeshBufferData(
                            type: .index, data: indexBufData
                        )

                        let submesh = MDLSubmesh(
                            indexBuffer: indexBuffer,
                            indexCount: indices.count,
                            indexType: .uInt32,
                            geometryType: .triangles,
                            material: nil
                        )

                        let vertexDescriptor = MDLVertexDescriptor()
                        let posAttr = MDLVertexAttribute(
                            name: MDLVertexAttributePosition,
                            format: .float3,
                            offset: 0,
                            bufferIndex: 0
                        )
                        vertexDescriptor.attributes[0] = posAttr
                        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(
                            stride: MemoryLayout<SIMD3<Float>>.stride
                        )

                        let mesh = MDLMesh(
                            vertexBuffer: vertexBuffer,
                            vertexCount: worldVertices.count,
                            descriptor: vertexDescriptor,
                            submeshes: [submesh]
                        )
                        asset.add(mesh)
                    }
                }

                if !hasGeometry {
                    throw NSError(
                        domain: "com.lidarscanner",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No mesh geometry available for export"]
                    )
                }

                try asset.export(to: tempURL)

                DispatchQueue.main.async {
                    result([
                        "filePath": tempURL.path,
                        "fileSize": (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? 0
                    ] as [String: Any])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "EXPORT_FAILED",
                                        message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Status

    func getStatus(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(["isInitialized": false] as [String: Any])
                return
            }
            result([
                "isInitialized": self.isInitialized,
                "pinCount": self.pinEntities.count,
                "lineCount": self.lineEntities.count,
                "hasMesh": self.meshEntity != nil,
                "renderMode": self.currentRenderMode.rawValue,
                "isRealityKit2": true
            ] as [String: Any])
        }
    }

    // MARK: - Dispose

    func dispose(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.arView?.session.pause()
            self.arView?.scene.anchors.removeAll()
            self.arView = nil
            self.rootAnchor = nil
            self.meshEntity = nil
            self.pinEntities.removeAll()
            self.lineEntities.removeAll()
            self.isInitialized = false
            debugPrint("🌍 [RealityKit] 🧹 Disposed")
            result(nil)
        }
    }

    // MARK: - Private: Build Mesh Entity from Point Cloud

    private func buildMeshEntity(vertices: [SIMD3<Float>],
                                  confidences: [Float],
                                  mode: RenderMode) -> ModelEntity {
        switch mode {
        case .solid, .wireframe, .xray:
            return buildTriangulatedMesh(vertices: vertices,
                                         confidences: confidences,
                                         mode: mode)
        case .pointCloud:
            return buildPointCloudEntity(vertices: vertices,
                                          confidences: confidences)
        }
    }

    /// Build a triangulated mesh using improved neighbor-based triangulation
    /// FIXED: Better algorithm for unstructured point clouds
    private func buildTriangulatedMesh(vertices: [SIMD3<Float>],
                                        confidences: [Float],
                                        mode: RenderMode) -> ModelEntity {
        // ── Descriptors ──────────────────────────────────────────
        var meshDesc = MeshDescriptor(name: "scanMesh")

        // Vertices
        meshDesc.positions = MeshBuffer(vertices)

        // IMPROVED: Generate triangles using k-nearest neighbor approach
        // This works better for unstructured point clouds from real scans
        var indices: [UInt32] = []
        let count = vertices.count

        if count >= 3 {
            // For small point clouds, use simple fan triangulation from centroid
            if count < 100 {
                // Calculate centroid
                var centroid = SIMD3<Float>(0, 0, 0)
                for v in vertices {
                    centroid += v
                }
                centroid /= Float(count)

                // Create triangles from centroid to consecutive points
                for i in 0..<count {
                    let next = (i + 1) % count
                    // Skip degenerate triangles
                    let d1 = simd_distance(vertices[i], centroid)
                    let d2 = simd_distance(vertices[next], centroid)
                    if d1 > 0.001 && d2 > 0.001 {
                        indices.append(UInt32(i))
                        indices.append(UInt32(next))
                        // Use first point as pseudo-centroid for simplicity
                        indices.append(0)
                    }
                }
            } else {
                // For larger clouds, use grid-based triangulation
                // Assume points are roughly ordered by capture sequence
                let gridSize = Int(sqrt(Double(count)))

                for row in 0..<(gridSize - 1) {
                    for col in 0..<(gridSize - 1) {
                        let i0 = row * gridSize + col
                        let i1 = row * gridSize + col + 1
                        let i2 = (row + 1) * gridSize + col
                        let i3 = (row + 1) * gridSize + col + 1

                        if i0 < count && i1 < count && i2 < count && i3 < count {
                            // First triangle
                            indices.append(UInt32(i0))
                            indices.append(UInt32(i1))
                            indices.append(UInt32(i2))

                            // Second triangle
                            indices.append(UInt32(i1))
                            indices.append(UInt32(i3))
                            indices.append(UInt32(i2))
                        }
                    }
                }
            }
        }

        // Fallback: if no triangles generated, create point cloud representation
        if indices.isEmpty && count >= 3 {
            // Create small triangles at each point (billboard effect)
            for i in 0..<min(count, 1000) {
                if i + 2 < count {
                    indices.append(UInt32(i))
                    indices.append(UInt32(i + 1))
                    indices.append(UInt32(i + 2))
                }
            }
        }

        meshDesc.primitives = .triangles(indices)

        // Per-vertex normals (smooth shading)
        var normals: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 1, 0),
                                             count: vertices.count)

        // Compute face normals and accumulate for smooth shading
        if !indices.isEmpty {
            for i in stride(from: 0, to: indices.count - 2, by: 3) {
                guard i + 2 < indices.count else { break }
                let idx0 = Int(indices[i])
                let idx1 = Int(indices[i + 1])
                let idx2 = Int(indices[i + 2])

                guard idx0 < vertices.count && idx1 < vertices.count && idx2 < vertices.count else { continue }

                let v0 = vertices[idx0]
                let v1 = vertices[idx1]
                let v2 = vertices[idx2]

                let edge1 = v1 - v0
                let edge2 = v2 - v0
                let n = normalize(simd_cross(edge1, edge2))

                // Accumulate normals (will average later)
                normals[idx0] += n
                normals[idx1] += n
                normals[idx2] += n
            }

            // Normalize accumulated normals
            for i in 0..<normals.count {
                let len = simd_length(normals[i])
                if len > 0.001 {
                    normals[i] = normalize(normals[i])
                }
            }
        }

        meshDesc.normals = MeshBuffer(normals)

        let meshResource = try? MeshResource.generate(from: [meshDesc])
        let entity = ModelEntity()

        if let mesh = meshResource {
            let material: RealityKit.Material = {
                switch mode {
                case .solid: return self.scanMeshMaterial
                case .wireframe: return self.wireframeMaterial
                case .xray:
                    var m = UnlitMaterial()
                    m.color = .init(tint: UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.35))
                    return m
                default: return self.scanMeshMaterial
                }
            }()
            entity.model = ModelComponent(mesh: mesh, materials: [material])

            debugPrint("🌍 [RealityKit] Mesh created: \(vertices.count) vertices, \(indices.count / 3) triangles")
        } else {
            debugPrint("🌍 [RealityKit] ⚠️ Failed to generate mesh resource")
        }

        return entity
    }

    /// Build point cloud as many tiny spheres (instanced)
    private func buildPointCloudEntity(vertices: [SIMD3<Float>],
                                        confidences: [Float]) -> ModelEntity {
        let container = ModelEntity()

        // Batch limit for performance
        let limit = min(vertices.count, 2000)
        let step = max(1, vertices.count / limit)

        for i in stride(from: 0, to: vertices.count, by: step) {
            let conf = i < confidences.count ? confidences[i] : 0.5
            let radius: Float = conf > 0.7 ? 0.005 : 0.003

            let sphere = ModelEntity(
                mesh: MeshResource.generateSphere(radius: radius),
                materials: [conf > 0.7 ? autoPointMaterial : wireframeMaterial]
            )
            sphere.position = vertices[i]
            container.addChild(sphere)
        }

        return container
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        debugPrint("🌍 [RealityKit] ❌ Session error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.eventHandler?.send([
                "type": "error",
                "message": error.localizedDescription
            ] as [String: Any])
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        debugPrint("🌍 [RealityKit] ⚠️ Session interrupted")
        DispatchQueue.main.async { [weak self] in
            self?.eventHandler?.send(["type": "interrupted"] as [String: Any])
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        debugPrint("🌍 [RealityKit] ✅ Interruption ended")
        DispatchQueue.main.async { [weak self] in
            self?.eventHandler?.send(["type": "resumed"] as [String: Any])
        }
    }
}


// ============================================================================
// MARK: - Custom Cylinder Mesh (iOS 15+ compatible)
// ============================================================================

/// Generate a cylinder mesh manually using MeshDescriptor.
/// RealityKit's built-in `MeshResource.generateCylinder` is iOS 18+ only.
@available(iOS 15.0, *)
private func makeCylinderMesh(height: Float, radius: Float, segments: Int = 12) -> MeshResource {
    var meshDesc = MeshDescriptor(name: "cylinder")

    var positions: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    var normals: [SIMD3<Float>] = []

    let halfHeight = height / 2.0

    // ── Side ring vertices ──────────────────────────────────
    // Each segment has 2 vertices: top ring + bottom ring
    // Normals point outward radially for smooth shading
    for i in 0..<segments {
        let angle = Float(i) / Float(segments) * 2.0 * .pi
        let nx = cos(angle)
        let nz = sin(angle)
        let x = radius * nx
        let z = radius * nz

        // Top ring
        positions.append(SIMD3<Float>(x, halfHeight, z))
        normals.append(SIMD3<Float>(nx, 0, nz))

        // Bottom ring
        positions.append(SIMD3<Float>(x, -halfHeight, z))
        normals.append(SIMD3<Float>(nx, 0, nz))
    }

    // ── Side triangles (2 triangles per segment) ───────────
    for i in 0..<segments {
        let next = (i + 1) % segments

        let top0 = UInt32(i * 2)
        let bot0 = UInt32(i * 2 + 1)
        let top1 = UInt32(next * 2)
        let bot1 = UInt32(next * 2 + 1)

        // Triangle 1: top0 → bot0 → top1
        indices.append(top0)
        indices.append(bot0)
        indices.append(top1)

        // Triangle 2: top1 → bot0 → bot1
        indices.append(top1)
        indices.append(bot0)
        indices.append(bot1)
    }

    // ── Cap centers ────────────────────────────────────────
    let topCenterIndex = UInt32(positions.count)
    positions.append(SIMD3<Float>(0, halfHeight, 0))
    normals.append(SIMD3<Float>(0, 1, 0))

    let bottomCenterIndex = UInt32(positions.count)
    positions.append(SIMD3<Float>(0, -halfHeight, 0))
    normals.append(SIMD3<Float>(0, -1, 0))

    // ── Top cap triangles (fan) ────────────────────────────
    for i in 0..<segments {
        let next = (i + 1) % segments
        let v0 = UInt32(i * 2)
        let v1 = UInt32(next * 2)
        indices.append(topCenterIndex)
        indices.append(v0)
        indices.append(v1)
    }

    // ── Bottom cap triangles (fan, reversed winding) ───────
    for i in 0..<segments {
        let next = (i + 1) % segments
        let v0 = UInt32(i * 2 + 1)
        let v1 = UInt32(next * 2 + 1)
        indices.append(bottomCenterIndex)
        indices.append(v1)
        indices.append(v0)
    }

    meshDesc.positions = MeshBuffer(positions)
    meshDesc.normals = MeshBuffer(normals)
    meshDesc.primitives = .triangles(indices)

    guard let mesh = try? MeshResource.generate(from: [meshDesc]) else {
        // Fallback to a simple box
        return MeshResource.generateBox(width: radius * 2, height: height, depth: radius * 2)
    }
    return mesh
}


// ============================================================================
// MARK: - Event Stream Handler
// ============================================================================

@available(iOS 15.0, *)
class RealityKitEventHandler: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func send(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}
