import Flutter
import UIKit
import ARKit
import RealityKit
import ModelIO
import MetalKit

@available(iOS 14.0, *)
class LiDARScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var arView: ARView?
    private var arSession: ARSession?
    private var pointCloud: [SIMD3<Float>] = []
    private var isScanning = false
    private var scanStartTime: Date?
    private var eventSink: FlutterEventSink?
    private var scanTimer: Timer?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.lidarscanner/native", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.lidarscanner/scan_events", binaryMessenger: registrar.messenger())
        
        let instance = LiDARScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isLiDARAvailable":
            result(checkLiDARAvailability())
            
        case "isARCoreSupported":
            result(false) // iOS doesn't use ARCore
            
        case "initializeARSession":
            initializeARSession(result: result)
            
        case "startScanning":
            startScanning(result: result)
            
        case "pauseScanning":
            pauseScanning(result: result)
            
        case "resumeScanning":
            resumeScanning(result: result)
            
        case "stopScanning":
            stopScanning(result: result)
            
        case "exportScan":
            if let args = call.arguments as? [String: Any],
               let scanId = args["scanId"] as? String,
               let format = args["format"] as? String {
                exportScan(scanId: scanId, format: format, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
            
        case "getScanStatistics":
            getScanStatistics(result: result)
            
        case "disposeARSession":
            disposeARSession(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // MARK: - LiDAR Methods
    
    private func checkLiDARAvailability() -> Bool {
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }
    
    private func initializeARSession(result: @escaping FlutterResult) {
        guard checkLiDARAvailability() else {
            result(FlutterError(code: "LIDAR_NOT_AVAILABLE", message: "LiDAR not available on this device", details: nil))
            return
        }
        
        arView = ARView(frame: .zero)
        arSession = arView?.session
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        arSession?.run(configuration)
        result(true)
    }
    
    private func startScanning(result: @escaping FlutterResult) {
        guard arSession != nil else {
            result(FlutterError(code: "SESSION_NOT_INITIALIZED", message: "AR session not initialized", details: nil))
            return
        }
        
        isScanning = true
        scanStartTime = Date()
        pointCloud.removeAll()
        
        // Start timer for real-time updates
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateScanData()
        }
        
        result(true)
    }
    
    private func pauseScanning(result: @escaping FlutterResult) {
        isScanning = false
        scanTimer?.invalidate()
        result(true)
    }
    
    private func resumeScanning(result: @escaping FlutterResult) {
        isScanning = true
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateScanData()
        }
        result(true)
    }
    
    private func updateScanData() {
        guard isScanning, let frame = arSession?.currentFrame else { return }
        
        // Extract depth data
        if let depthData = frame.sceneDepth?.depthMap {
            extractPointCloud(from: depthData, frame: frame)
        }
        
        // Calculate coverage and send to Flutter
        let duration = Int(Date().timeIntervalSince(scanStartTime ?? Date()))
        let coverage = calculateCoverage()
        
        eventSink?([
            "pointCount": pointCloud.count,
            "coverage": coverage,
            "duration": duration,
            "isScanning": isScanning
        ])
    }
    
    private func extractPointCloud(from depthMap: CVPixelBuffer, frame: ARFrame) {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let depthPointer = baseAddress.assumingMemoryBound(to: Float32.self)
        
        let camera = frame.camera
        let viewMatrix = camera.viewMatrix(for: .portrait)
        
        // Sample points (not all pixels for performance)
        let step = 10
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let index = y * width + x
                let depth = depthPointer[index]
                
                // Skip invalid depth values
                guard depth > 0 && depth < 10 else { continue }
                
                // Convert 2D pixel to 3D point
                let normalizedX = Float(x) / Float(width)
                let normalizedY = Float(y) / Float(height)
                
                let point = camera.unprojectPoint(
                    SIMD3<Float>(normalizedX, normalizedY, depth),
                    ontoPlaneWithTransform: viewMatrix
                )
                
                pointCloud.append(point)
            }
        }
    }
    
    private func calculateCoverage() -> Double {
        // Simple coverage calculation based on point density
        let targetPoints = 100000.0
        let coverage = min(Double(pointCloud.count) / targetPoints * 100.0, 100.0)
        return coverage
    }
    
    private func stopScanning(result: @escaping FlutterResult) {
        isScanning = false
        scanTimer?.invalidate()
        
        // Generate 3D mesh from point cloud
        generateMesh { [weak self] filePath in
            guard let self = self else {
                result(FlutterError(code: "ERROR", message: "Plugin deallocated", details: nil))
                return
            }
            
            if let filePath = filePath {
                let coverage = self.calculateCoverage()
                let quality = min(coverage / 100.0, 1.0)
                
                result([
                    "filePath": filePath,
                    "pointCount": self.pointCloud.count,
                    "coverage": coverage,
                    "quality": quality
                ])
            } else {
                result(FlutterError(code: "MESH_GENERATION_FAILED", message: "Failed to generate mesh", details: nil))
            }
        }
    }
    
    private func generateMesh(completion: @escaping (String?) -> Void) {
        guard !pointCloud.isEmpty else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // Create MDLMesh from point cloud
            let allocator = MTKMeshBufferAllocator(device: MTLCreateSystemDefaultDevice()!)
            
            // Create vertices
            var vertices: [SIMD3<Float>] = self.pointCloud
            
            // Simple mesh generation (in production, use proper reconstruction algorithm)
            let vertexBuffer = allocator.newBuffer(
                with: Data(bytes: &vertices, count: vertices.count * MemoryLayout<SIMD3<Float>>.stride),
                type: .vertex
            )
            
            let vertexDescriptor = MDLVertexDescriptor()
            vertexDescriptor.attributes[0] = MDLVertexAttribute(
                name: MDLVertexAttributePosition,
                format: .float3,
                offset: 0,
                bufferIndex: 0
            )
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)
            
            let mdlMesh = MDLMesh(
                vertexBuffer: vertexBuffer,
                vertexCount: vertices.count,
                descriptor: vertexDescriptor,
                submeshes: []
            )
            
            // Export to GLB
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "scan_\(UUID().uuidString).glb"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            let asset = MDLAsset()
            asset.add(mdlMesh)
            
            do {
                try asset.export(to: fileURL)
                DispatchQueue.main.async {
                    completion(fileURL.path)
                }
            } catch {
                print("Error exporting mesh: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func exportScan(scanId: String, format: String, result: @escaping FlutterResult) {
        // Export to different formats
        // This is a placeholder - implement actual conversion
        result(nil)
    }
    
    private func getScanStatistics(result: @escaping FlutterResult) {
        result([
            "pointCount": pointCloud.count,
            "coverage": calculateCoverage(),
            "meshVertices": pointCloud.count,
            "meshFaces": max(0, pointCloud.count - 2)
        ])
    }
    
    private func disposeARSession(result: @escaping FlutterResult) {
        scanTimer?.invalidate()
        arSession?.pause()
        arView = nil
        arSession = nil
        pointCloud.removeAll()
        result(nil)
    }
}
