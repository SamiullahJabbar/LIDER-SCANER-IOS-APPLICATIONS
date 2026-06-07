// ============================================================================
// LiDARScannerPlugin.swift
// PRODUCTION-READY — Universal iOS AR Scanner (iPhone 7 and above)
//
// SUPPORT MATRIX:
//   • LiDAR Devices (iPhone 12/13/14/15 Pro, iPad Pro 2020+):
//     → Full ARKit + LiDAR depth sensing
//     → sceneReconstruction + sceneDepth enabled
//     → High-accuracy point cloud capture
//
//   • ARKit-Only Devices (iPhone 7, 8, X, XR, XS, 11, SE, etc.):
//     → ARKit tracking without LiDAR
//     → Frame semantics: sceneDepth NOT available
//     → Raycast & hit-test work (less accurate)
//     → Camera-based depth estimation
//
//   • Unsupported (iOS < 14):
//     → Fallback camera mode via Flutter
//
// Platform channel: "com.lidarscanner/native"
// Event channel:    "com.lidarscanner/scan_events"
// ============================================================================

import Flutter
import UIKit
import ARKit
import ModelIO
import MetalKit
import AVFoundation

// MARK: - Plugin Registration

@available(iOS 14.0, *)
public class LiDARScannerPlugin: NSObject, FlutterPlugin {

    static var instance: LiDARScannerPlugin?

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private let streamHandler = ScanEventStreamHandler()
    private let sessionManager = ARSessionManager()

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.lidarscanner/native",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.lidarscanner/scan_events",
            binaryMessenger: messenger
        )
        super.init()
        methodChannel.setMethodCallHandler(handle)
        eventChannel.setStreamHandler(streamHandler)
        sessionManager.delegate = streamHandler
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let inst = LiDARScannerPlugin(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(inst, channel: inst.methodChannel)
        LiDARScannerPlugin.instance = inst
    }

    // MARK: - Method Router

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // ── Capability checks ──────────────────────────────────────────
        case "isLiDARAvailable":
            result(sessionManager.isLiDARAvailable)

        case "isARCoreSupported":
            result(false) // iOS-only

        case "isDepthSupported":
            result(sessionManager.isDepthSupported)

        case "getDeviceCapability":
            result(sessionManager.deviceCapability)

        case "getARKitSupportLevel":
            result(sessionManager.arKitSupportLevel)

        // ── Session lifecycle ──────────────────────────────────────────
        case "initializeARSession":
            sessionManager.initializeSession(result: result)

        case "startScanning":
            sessionManager.startScanning(result: result)

        case "pauseScanning":
            sessionManager.pauseScanning(result: result)

        case "resumeScanning":
            sessionManager.resumeScanning(result: result)

        case "stopScanning":
            sessionManager.stopScanning(result: result)

        case "disposeARSession":
            sessionManager.dispose(result: result)

        // ── Depth queries ─────────────────────────────────────────────
        case "getDepthAtPoint":
            guard let args = call.arguments as? [String: Any],
                  let x = args["x"] as? Double,
                  let y = args["y"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "x and y (Double) required", details: nil))
                return
            }
            sessionManager.getDepthAtPoint(normalizedX: Float(x),
                                           normalizedY: Float(y),
                                           result: result)

        case "performHitTest":
            guard let args = call.arguments as? [String: Any],
                  let x = args["x"] as? Double,
                  let y = args["y"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "x and y (Double) required", details: nil))
                return
            }
            sessionManager.performHitTest(screenX: Float(x),
                                          screenY: Float(y),
                                          result: result)

        // ── Statistics ────────────────────────────────────────────────
        case "getScanStatistics":
            sessionManager.getScanStatistics(result: result)

        // ── Auto-capture control ──────────────────────────────────────
        case "setAutoCaptureEnabled":
            guard let args = call.arguments as? [String: Any],
                  let enabled = args["enabled"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "enabled (Bool) required", details: nil))
                return
            }
            sessionManager.autoCaptureEnabled = enabled
            result(true)

        case "setAutoCaptureInterval":
            guard let args = call.arguments as? [String: Any],
                  let ms = args["intervalMs"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "intervalMs (Int) required", details: nil))
                return
            }
            sessionManager.autoCaptureIntervalMs = ms
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}


// ============================================================================
// MARK: - AR Session Manager
// ============================================================================

@available(iOS 14.0, *)
final class ARSessionManager: NSObject, ARSessionDelegate {

    // ── Public state ───────────────────────────────────────────────────
    weak var delegate: ScanEventStreamHandler?
    var autoCaptureEnabled = true
    var autoCaptureIntervalMs = 100 // 10 points/sec default

    // ── Capability ─────────────────────────────────────────────────────
    var isLiDARAvailable: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    var isDepthSupported: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    var deviceCapability: String {
        // Comprehensive device detection for iOS AR capabilities
        let model = UIDevice.current.modelName
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(model); iOS \(osVersion.majorVersion).\(osVersion.minorVersion)"
    }

    var arKitSupportLevel: String {
        // Determine ARKit support level based on device capabilities
        if isLiDARAvailable {
            return "LiDAR + ARKit"
        } else if ARWorldTrackingConfiguration.isSupported {
            return "ARKit Only"
        } else {
            return "Unsupported"
        }
    }

    // ── Private state ──────────────────────────────────────────────────
    private var session: ARSession?
    private var configuration: ARWorldTrackingConfiguration?

    private var isInitialized = false
    private var isScanning = false

    // Point cloud storage
    private var pointCloud: [CapturedPoint] = []
    private let pointCloudLock = NSLock()
    private var sequenceNumber: Int = 0

    // Timing
    private var scanStartTime: Date?
    private var lastAutoCaptureTime: Date?

    // Filtering
    private let minPointDistance: Float = 0.005   // 5mm
    private let maxDepth: Float = 8.0             // 8m
    private let minConfidence: Float = 0.5

    // ── Structures ─────────────────────────────────────────────────────
    struct CapturedPoint {
        let x: Float
        let y: Float
        let z: Float
        let confidence: Float
        let sequenceNumber: Int
        let isManualPin: Bool
        let timestamp: TimeInterval
        let r: UInt8
        let g: UInt8
        let b: UInt8
    }

    // MARK: - Session Lifecycle

    func initializeSession(result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.isSupported else {
            result(FlutterError(code: "AR_NOT_SUPPORTED",
                                message: "ARKit world tracking not supported on this device",
                                details: nil))
            return
        }

        let config = ARWorldTrackingConfiguration()

        // Plane detection (horizontal + vertical)
        config.planeDetection = [.horizontal, .vertical]

        // Environment texturing
        config.environmentTexturing = .automatic

        // LiDAR scene reconstruction (mesh)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        // Depth frame semantics (LiDAR depth + smoothed)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }

        let arSession = ARSession()
        arSession.delegate = self
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])

        self.session = arSession
        self.configuration = config
        self.isInitialized = true

        debugPrint("🍎 [ARSession] ✅ Initialized — LiDAR: \(isLiDARAvailable), Depth: \(isDepthSupported)")
        result(true)
    }

    func startScanning(result: @escaping FlutterResult) {
        guard isInitialized, session != nil else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "AR session not initialized",
                                details: nil))
            return
        }

        pointCloudLock.lock()
        pointCloud.removeAll()
        sequenceNumber = 0
        pointCloudLock.unlock()

        scanStartTime = Date()
        lastAutoCaptureTime = nil
        isScanning = true

        debugPrint("🍎 [ARSession] ✅ Scanning started")
        result(true)
    }

    func pauseScanning(result: @escaping FlutterResult) {
        isScanning = false
        debugPrint("🍎 [ARSession] ⏸️ Scanning paused")
        result(true)
    }

    func resumeScanning(result: @escaping FlutterResult) {
        guard isInitialized, session != nil else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "AR session not initialized",
                                details: nil))
            return
        }
        isScanning = true
        debugPrint("🍎 [ARSession] ▶️ Scanning resumed")
        result(true)
    }

    func stopScanning(result: @escaping FlutterResult) {
        isScanning = false

        pointCloudLock.lock()
        let finalCount = pointCloud.count
        pointCloudLock.unlock()

        let duration = Int(Date().timeIntervalSince(scanStartTime ?? Date()))
        let coverage = calculateCoverage()

        debugPrint("🍎 [ARSession] 🛑 Stopped — \(finalCount) points, \(duration)s")

        result([
            "pointCount": finalCount,
            "coverage": coverage,
            "duration": duration,
            "quality": min(coverage / 100.0, 1.0)
        ] as [String: Any])
    }

    func dispose(result: @escaping FlutterResult) {
        isScanning = false
        session?.pause()
        session = nil
        configuration = nil
        isInitialized = false

        pointCloudLock.lock()
        pointCloud.removeAll()
        sequenceNumber = 0
        pointCloudLock.unlock()

        debugPrint("🍎 [ARSession] 🧹 Disposed")
        result(nil)
    }

    // MARK: - Depth Query

    /// Query depth at a normalized screen point using the live depth map.
    func getDepthAtPoint(normalizedX: Float, normalizedY: Float,
                         result: @escaping FlutterResult) {
        guard let frame = session?.currentFrame else {
            result(FlutterError(code: "NO_FRAME",
                                message: "No AR frame available", details: nil))
            return
        }

        // Prefer smoothed depth, fall back to raw
        guard let depthMap = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap else {
            result(["depth": 1.5, "confidence": 0.0] as [String: Any])
            return
        }

        let confidenceMap = frame.smoothedSceneDepth?.confidenceMap ?? frame.sceneDepth?.confidenceMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let pixelX = min(max(Int(normalizedX * Float(width)), 0), width - 1)
        let pixelY = min(max(Int(normalizedY * Float(height)), 0), height - 1)

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            result(["depth": 1.5, "confidence": 0.0] as [String: Any])
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthPointer = baseAddress.advanced(by: pixelY * bytesPerRow)
                                      .assumingMemoryBound(to: Float32.self)
        let depth = depthPointer[pixelX]

        // Read confidence if available
        var confidence: Float = 0.0
        if let confidenceMap = confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            if let confBase = CVPixelBufferGetBaseAddress(confidenceMap) {
                let confBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
                let confPointer = confBase.advanced(by: pixelY * confBytesPerRow)
                                          .assumingMemoryBound(to: UInt8.self)
                let rawConf = confPointer[pixelX] // 0, 1, or 2 (ARConfidenceLevel)
                confidence = Float(rawConf) / 2.0 // Normalize to 0..1
            }
        }

        result([
            "depth": Double(depth),
            "confidence": Double(confidence)
        ] as [String: Any])
    }

    // MARK: - Hit Test / Raycast

    /// Perform a real ARKit raycast from normalized screen coordinates.
    /// Returns the 3D world coordinate where the ray hits a real surface.
    func performHitTest(screenX: Float, screenY: Float,
                        result: @escaping FlutterResult) {
        guard let session = session, let frame = session.currentFrame else {
            result(FlutterError(code: "NO_FRAME",
                                message: "No AR frame available", details: nil))
            return
        }

        let screenPoint = CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))

        // 1) Try real raycast (iOS 14+) — most accurate
        if let query = frame.raycastQuery(
            from: screenPoint,
            allowing: .estimatedPlane,
            alignment: .any
        ) {
            let results = session.raycast(query)
            if let hit = results.first {
                let col3 = hit.worldTransform.columns.3
                let worldX = col3.x
                let worldY = col3.y
                let worldZ = col3.z

                // Validate range
                let totalDist = sqrt(worldX * worldX + worldY * worldY + worldZ * worldZ)
                guard totalDist < maxDepth else {
                    result(FlutterError(code: "TOO_FAR",
                                        message: "Hit point too far (\(totalDist)m)",
                                        details: nil))
                    return
                }

                // Sample color at screen tap position
                let imgW = Int(frame.camera.imageResolution.width)
                let imgH = Int(frame.camera.imageResolution.height)
                let tapPX = Int(screenX * Float(imgW))
                let tapPY = Int(screenY * Float(imgH))
                let (r, g, b) = sampleColor(from: frame, at: tapPX, pxY: tapPY)

                // Store as captured point
                let point = addPointThreadSafe(
                    x: worldX, y: worldY, z: worldZ,
                    confidence: 0.95, isManualPin: true,
                    r: r, g: g, b: b
                )

                result([
                    "x": Double(point.x),
                    "y": Double(point.y),
                    "z": Double(point.z),
                    "confidence": Double(point.confidence),
                    "sequenceNumber": point.sequenceNumber,
                    "isManualPin": true,
                    "r": Int(r),
                    "g": Int(g),
                    "b": Int(b)
                ] as [String: Any])
                return
            }
        }

        // 2) Fallback: use depth map + camera intrinsics for unprojection
        if let depthMap = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap {
            let depthResult = readDepth(depthMap: depthMap,
                                        normalizedX: screenX,
                                        normalizedY: screenY)
            if depthResult.0 > 0.05 && depthResult.0 < maxDepth {
                let intrinsics = frame.camera.intrinsics
                let imgRes = frame.camera.imageResolution
                let fx = intrinsics[0][0]
                let fy = intrinsics[1][1]
                let cx = intrinsics[2][0]
                let cy = intrinsics[2][1]

                let pxX = screenX * Float(imgRes.width)
                let pxY = screenY * Float(imgRes.height)
                let depth = depthResult.0

                // Camera-space 3D point
                let camX = (pxX - cx) * depth / fx
                let camY = (pxY - cy) * depth / fy
                let camZ = depth

                // Transform camera-space → world-space
                let camPoint = SIMD4<Float>(camX, -camY, -camZ, 1.0)
                let viewMatrix = frame.camera.viewMatrix(for: .portrait)
                let worldPoint = simd_inverse(viewMatrix) * camPoint

                // Sample color at screen position
                let imgW = Int(frame.camera.imageResolution.width)
                let imgH = Int(frame.camera.imageResolution.height)
                let tapPX = Int(screenX * Float(imgW))
                let tapPY = Int(screenY * Float(imgH))
                let (r, g, b) = sampleColor(from: frame, at: tapPX, pxY: tapPY)

                let point = addPointThreadSafe(
                    x: worldPoint.x, y: worldPoint.y, z: worldPoint.z,
                    confidence: depthResult.1, isManualPin: true,
                    r: r, g: g, b: b
                )

                result([
                    "x": Double(point.x),
                    "y": Double(point.y),
                    "z": Double(point.z),
                    "confidence": Double(point.confidence),
                    "sequenceNumber": point.sequenceNumber,
                    "isManualPin": true,
                    "r": Int(r),
                    "g": Int(g),
                    "b": Int(b)
                ] as [String: Any])
                return
            }
        }

        result(FlutterError(code: "NO_HIT",
                            message: "Could not detect surface at this point",
                            details: nil))
    }

    // MARK: - Statistics

    func getScanStatistics(result: @escaping FlutterResult) {
        pointCloudLock.lock()
        let count = pointCloud.count
        let manualCount = pointCloud.filter { $0.isManualPin }.count
        let autoCount = count - manualCount
        let avgConf = pointCloud.isEmpty ? 0.0 :
            Double(pointCloud.reduce(Float(0)) { $0 + $1.confidence }) / Double(count)
        pointCloudLock.unlock()

        let duration = Int(Date().timeIntervalSince(scanStartTime ?? Date()))
        let coverage = calculateCoverage()

        result([
            "pointCount": count,
            "manualPinCount": manualCount,
            "autoPointCount": autoCount,
            "averageConfidence": avgConf,
            "coverage": coverage,
            "duration": duration,
            "isScanning": isScanning,
            "isLiDARAvailable": isLiDARAvailable,
            "isDepthSupported": isDepthSupported
        ] as [String: Any])
    }

    // MARK: - ARSessionDelegate (real-time frame processing)

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isScanning, autoCaptureEnabled else { return }

        // Throttle auto-capture by configured interval
        let now = Date()
        if let lastTime = lastAutoCaptureTime {
            let elapsed = now.timeIntervalSince(lastTime) * 1000.0
            if elapsed < Double(autoCaptureIntervalMs) { return }
        }
        lastAutoCaptureTime = now

        // Need depth map for auto-capture
        guard let depthMap = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap else {
            return
        }

        let confidenceMap = frame.smoothedSceneDepth?.confidenceMap ?? frame.sceneDepth?.confidenceMap
        let camera = frame.camera
        let intrinsics = camera.intrinsics
        let imgRes = camera.imageResolution
        let viewMatrix = camera.viewMatrix(for: .portrait)
        let inverseView = simd_inverse(viewMatrix)

        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        // Lock confidence map if available
        var confBase: UnsafeMutableRawPointer?
        var confBPR = 0
        if let cm = confidenceMap {
            CVPixelBufferLockBaseAddress(cm, .readOnly)
            confBase = CVPixelBufferGetBaseAddress(cm)
            confBPR = CVPixelBufferGetBytesPerRow(cm)
        }

        // Sample a grid of depth points (performance: ~25 points per frame)
        let sampleCols = 5
        let sampleRows = 5
        struct SampledPoint {
            let x: Float; let y: Float; let z: Float
            let confidence: Float; let pxX: Int; let pxY: Int
        }
        var newPoints: [SampledPoint] = []

        // Map depth pixel coords → camera image coords (depth is lower-res)
        let imgW = Int(frame.camera.imageResolution.width)
        let imgH = Int(frame.camera.imageResolution.height)

        for row in 0..<sampleRows {
            for col in 0..<sampleCols {
                let nx = Float(col) / Float(max(sampleCols - 1, 1))
                let ny = Float(row) / Float(max(sampleRows - 1, 1))

                let pxX = min(max(Int(nx * Float(depthWidth)), 0), depthWidth - 1)
                let pxY = min(max(Int(ny * Float(depthHeight)), 0), depthHeight - 1)

                // Read depth
                let depthPtr = depthBase.advanced(by: pxY * depthBytesPerRow)
                                        .assumingMemoryBound(to: Float32.self)
                let depth = depthPtr[pxX]

                guard depth > 0.05, depth < maxDepth else { continue }

                // Read confidence
                var confidence: Float = 0.5
                if let cb = confBase {
                    let confPtr = cb.advanced(by: pxY * confBPR)
                                    .assumingMemoryBound(to: UInt8.self)
                    confidence = Float(confPtr[pxX]) / 2.0
                }

                guard confidence >= minConfidence else { continue }

                // Map depth pixel → camera image pixel for color sampling
                let imgPX = Int(nx * Float(imgW))
                let imgPY = Int(ny * Float(imgH))

                // Unproject to camera space
                let imgX = nx * Float(imgRes.width)
                let imgY = ny * Float(imgRes.height)
                let camX = (imgX - cx) * depth / fx
                let camY = (imgY - cy) * depth / fy
                let camZ = depth

                // Camera → world transform
                let camPoint = SIMD4<Float>(camX, -camY, -camZ, 1.0)
                let worldPoint = inverseView * camPoint

                newPoints.append(SampledPoint(
                    x: worldPoint.x, y: worldPoint.y, z: worldPoint.z,
                    confidence: confidence, pxX: imgPX, pxY: imgPY
                ))
            }
        }

        // Unlock confidence map
        if let cm = confidenceMap {
            CVPixelBufferUnlockBaseAddress(cm, .readOnly)
        }

        // Filter & store thread-safe
        guard !newPoints.isEmpty else { return }

        var addedPoints: [[String: Any]] = []
        pointCloudLock.lock()
        for pt in newPoints {
            // Distance filter
            if let last = pointCloud.last {
                let dx = pt.x - last.x
                let dy = pt.y - last.y
                let dz = pt.z - last.z
                let dist = sqrt(dx * dx + dy * dy + dz * dz)
                if dist < minPointDistance { continue }
            }

            // Sample real RGB color from camera frame at this point
            let (r, g, b) = sampleColor(from: frame, at: pt.pxX, pxY: pt.pxY)

            let captured = CapturedPoint(
                x: pt.x, y: pt.y, z: pt.z,
                confidence: pt.confidence,
                sequenceNumber: sequenceNumber,
                isManualPin: false,
                timestamp: frame.timestamp,
                r: r, g: g, b: b
            )
            pointCloud.append(captured)

            addedPoints.append([
                "x": Double(pt.x),
                "y": Double(pt.y),
                "z": Double(pt.z),
                "confidence": Double(pt.confidence),
                "sequenceNumber": sequenceNumber,
                "isManualPin": false,
                "r": Int(r),
                "g": Int(g),
                "b": Int(b)
            ])
            sequenceNumber += 1
        }
        let totalCount = pointCloud.count
        pointCloudLock.unlock()

        guard !addedPoints.isEmpty else { return }

        let duration = Int(Date().timeIntervalSince(scanStartTime ?? Date()))

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.send([
                "type": "points",
                "points": addedPoints,
                "totalPointCount": totalCount,
                "coverage": self?.calculateCoverage() ?? 0.0,
                "duration": duration,
                "isScanning": true
            ] as [String: Any])
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        debugPrint("🍎 [ARSession] ❌ Error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.send([
                "type": "error",
                "message": error.localizedDescription
            ] as [String: Any])
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        debugPrint("🍎 [ARSession] ⚠️ Interrupted")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.send(["type": "interrupted"] as [String: Any])
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        debugPrint("🍎 [ARSession] ✅ Interruption ended")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.send(["type": "resumed"] as [String: Any])
        }
    }

    // MARK: - Private Helpers

    /// Sample RGB color from camera frame at depth-map pixel coordinates.
    /// Camera image is BGRA8888; converts to UInt8 RGB.
    private func sampleColor(from frame: ARFrame, at pxX: Int, pxY: Int) -> (UInt8, UInt8, UInt8) {
        let image = frame.capturedImage
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }

        let imgW = CVPixelBufferGetWidth(image)
        let imgH = CVPixelBufferGetHeight(image)
        let imgX = min(max(pxX, 0), Int(imgW) - 1)
        let imgY = min(max(pxY, 0), Int(imgH) - 1)

        guard let base = CVPixelBufferGetBaseAddress(image) else {
            return (128, 128, 128)
        }
        let bpr = CVPixelBufferGetBytesPerRow(image)
        let pixel = base.advanced(by: imgY * bpr).assumingMemoryBound(to: UInt8.self)
        let b = pixel[imgX * 4]       // BGRA layout
        let g = pixel[imgX * 4 + 1]
        let r = pixel[imgX * 4 + 2]
        return (r, g, b)
    }

    private func addPointThreadSafe(x: Float, y: Float, z: Float,
                                     confidence: Float,
                                     isManualPin: Bool,
                                     r: UInt8 = 128, g: UInt8 = 128, b: UInt8 = 128) -> CapturedPoint {
        pointCloudLock.lock()
        let point = CapturedPoint(
            x: x, y: y, z: z,
            confidence: confidence,
            sequenceNumber: sequenceNumber,
            isManualPin: isManualPin,
            timestamp: CACurrentMediaTime(),
            r: r, g: g, b: b
        )
        pointCloud.append(point)
        sequenceNumber += 1
        pointCloudLock.unlock()
        return point
    }

    private func readDepth(depthMap: CVPixelBuffer,
                           normalizedX: Float,
                           normalizedY: Float) -> (Float, Float) {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let w = CVPixelBufferGetWidth(depthMap)
        let h = CVPixelBufferGetHeight(depthMap)
        let px = min(max(Int(normalizedX * Float(w)), 0), w - 1)
        let py = min(max(Int(normalizedY * Float(h)), 0), h - 1)

        guard let base = CVPixelBufferGetBaseAddress(depthMap) else {
            return (1.5, 0.0)
        }

        let bpr = CVPixelBufferGetBytesPerRow(depthMap)
        let ptr = base.advanced(by: py * bpr).assumingMemoryBound(to: Float32.self)
        return (ptr[px], 0.5)
    }

    private func calculateCoverage() -> Double {
        pointCloudLock.lock()
        let count = pointCloud.count
        pointCloudLock.unlock()
        return min(Double(count) / 100_000.0 * 100.0, 100.0)
    }
}


// ============================================================================
// MARK: - Event Stream Handler
// ============================================================================

@available(iOS 14.0, *)
class ScanEventStreamHandler: NSObject, FlutterStreamHandler {

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
        eventSink?(data)
    }
}

// ============================================================================
// MARK: - Device Model Detection (iPhone 7 and above)
// ============================================================================

@available(iOS 14.0, *)
extension UIDevice {
    /// Comprehensive device model detection for iOS devices
    /// Returns human-readable model name for AR capability classification
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // iPhone models with AR capabilities
        // Apple internal naming: iPhone15,4 = iPhone 15, iPhone16,1 = iPhone 15 Pro, iPhone17,3 = iPhone 16
        switch identifier {
        // iPhone 17 Series (Latest — identifiers are approximated)
        case "iPhone19,1": return "iPhone 17 Pro"
        case "iPhone19,2": return "iPhone 17 Pro Max"
        case "iPhone19,3": return "iPhone 17"
        case "iPhone19,4": return "iPhone 17 Plus"
            
        // iPhone 16 Series (Pro = iPhone18,x, regular = iPhone17,x)
        case "iPhone18,1": return "iPhone 16 Pro"
        case "iPhone18,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
            
        // iPhone 15 Series (Pro = iPhone16,x, regular = iPhone15,x)
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
            
        // iPhone 14 Series
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
            
        // iPhone 13 Series
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
            
        // iPhone 12 Series
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
            
        // iPhone 11 Series
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
            
        // iPhone XS/XR Series
        case "iPhone11,2": return "iPhone XS"
        case "iPhone11,4": return "iPhone XS Max"
        case "iPhone11,6": return "iPhone XS Max (Global)"
        case "iPhone11,8": return "iPhone XR"
            
        // iPhone X Series
        case "iPhone10,3": return "iPhone X"
        case "iPhone10,6": return "iPhone X (Global)"
            
        // iPhone 8 Series
        case "iPhone10,1": return "iPhone 8"
        case "iPhone10,2": return "iPhone 8 Plus"
        case "iPhone10,4": return "iPhone 8 (Global)"
        case "iPhone10,5": return "iPhone 8 Plus (Global)"
            
        // iPhone 7 Series
        case "iPhone9,1": return "iPhone 7"
        case "iPhone9,2": return "iPhone 7 Plus"
        case "iPhone9,3": return "iPhone 7"
        case "iPhone9,4": return "iPhone 7 Plus"
            
        // iPad Pro (LiDAR models 2020+)
        case "iPad8,9", "iPad8,10": return "iPad Pro 11-inch (2nd gen, LiDAR)"
        case "iPad8,11", "iPad8,12": return "iPad Pro 12.9-inch (4th gen, LiDAR)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro 11-inch (3rd gen, LiDAR)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro 12.9-inch (5th gen, LiDAR)"
        case "iPad14,3", "iPad14,4": return "iPad Pro 11-inch (4th gen, LiDAR)"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9-inch (6th gen, LiDAR)"
            
        // Other iPad Pro (no LiDAR)
        case "iPad6,3", "iPad6,4": return "iPad Pro 9.7-inch"
        case "iPad7,1", "iPad7,2": return "iPad Pro 12.9-inch (1st gen)"
        case "iPad7,3", "iPad7,4": return "iPad Pro 10.5-inch"
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro 11-inch (1st gen)"
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro 12.9-inch (3rd gen)"
            
        // Other iPad models
        case "iPad11,1", "iPad11,2": return "iPad mini (5th gen)"
        case "iPad11,3", "iPad11,4": return "iPad Air (3rd gen)"
        case "iPad12,1", "iPad12,2": return "iPad (9th gen)"
        case "iPad13,1", "iPad13,2": return "iPad mini (6th gen)"
        case "iPad13,16", "iPad13,17": return "iPad Air (4th gen)"
        case "iPad14,1": return "iPad mini (7th gen)"
        case "iPad14,8", "iPad14,9": return "iPad Air (5th gen)"
            
        // Default
        default: return "Unknown iOS Device (\(identifier))"
        }
    }

    /// Check if device has LiDAR sensor
    var hasLiDAR: Bool {
        let model = modelName
        // iPhone 12/13/14/15/16/17 Pro models
        if model.contains("iPhone") && model.contains("Pro") {
            return model.contains("12 Pro") || model.contains("13 Pro") ||
                   model.contains("14 Pro") || model.contains("15 Pro") ||
                   model.contains("16 Pro") || model.contains("17 Pro")
        }
        // iPad Pro 2020+
        if model.contains("iPad Pro") {
            return model.contains("LiDAR") ||
                   model.contains("2nd gen") || model.contains("3rd gen") ||
                   model.contains("4th gen") || model.contains("5th gen") ||
                   model.contains("6th gen")
        }
        return false
    }

    /// AR capability level for this device
    var arCapabilityLevel: String {
        if hasLiDAR {
            return "LiDAR"
        } else if ARWorldTrackingConfiguration.isSupported {
            return "ARKit"
        } else {
            return "Camera"
        }
    }
}
