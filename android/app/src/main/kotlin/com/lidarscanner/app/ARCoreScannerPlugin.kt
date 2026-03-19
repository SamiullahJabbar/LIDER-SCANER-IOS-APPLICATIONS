package com.lidarscanner.app

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.*
import kotlin.collections.ArrayList

class ARCoreScannerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    private var activity: Activity? = null
    private var arSession: Session? = null
    private val pointCloud = ArrayList<FloatArray>()
    private var isScanning = false
    private var scanStartTime: Long = 0
    private var scanTimer: Timer? = null
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "com.lidarscanner/native")
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(binding.binaryMessenger, "com.lidarscanner/scan_events")
        eventChannel.setStreamHandler(this)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    
    override fun onDetachedFromActivity() {
        activity = null
    }
    
    // MARK: - MethodChannel.MethodCallHandler
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isLiDARAvailable" -> result.success(false) // Android doesn't have LiDAR
            "isARCoreSupported" -> checkARCoreSupport(result)
            "initializeARSession" -> initializeARSession(result)
            "startScanning" -> startScanning(result)
            "pauseScanning" -> pauseScanning(result)
            "resumeScanning" -> resumeScanning(result)
            "stopScanning" -> stopScanning(result)
            "exportScan" -> {
                val scanId = call.argument<String>("scanId")
                val format = call.argument<String>("format")
                if (scanId != null && format != null) {
                    exportScan(scanId, format, result)
                } else {
                    result.error("INVALID_ARGS", "Invalid arguments", null)
                }
            }
            "getScanStatistics" -> getScanStatistics(result)
            "disposeARSession" -> disposeARSession(result)
            else -> result.notImplemented()
        }
    }
    
    // MARK: - EventChannel.StreamHandler
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    // MARK: - ARCore Methods
    
    private fun checkARCoreSupport(result: MethodChannel.Result) {
        val availability = ArCoreApk.getInstance().checkAvailability(activity)
        result.success(availability.isSupported)
    }
    
    private fun initializeARSession(result: MethodChannel.Result) {
        try {
            activity?.let { act ->
                // Check ARCore availability
                when (ArCoreApk.getInstance().requestInstall(act, true)) {
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                        result.error("ARCORE_INSTALL_REQUESTED", "ARCore installation requested", null)
                        return
                    }
                    ArCoreApk.InstallStatus.INSTALLED -> {
                        // Continue
                    }
                }
                
                // Create AR session
                arSession = Session(act)
                
                // Configure session
                val config = Config(arSession)
                config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                
                // Enable depth if supported
                if (arSession?.isDepthModeSupported(Config.DepthMode.AUTOMATIC) == true) {
                    config.depthMode = Config.DepthMode.AUTOMATIC
                }
                
                arSession?.configure(config)
                arSession?.resume()
                
                result.success(true)
            } ?: result.error("NO_ACTIVITY", "Activity not available", null)
        } catch (e: Exception) {
            result.error("INITIALIZATION_FAILED", e.message, null)
        }
    }
    
    private fun startScanning(result: MethodChannel.Result) {
        if (arSession == null) {
            result.error("SESSION_NOT_INITIALIZED", "AR session not initialized", null)
            return
        }
        
        isScanning = true
        scanStartTime = System.currentTimeMillis()
        pointCloud.clear()
        
        // Start timer for real-time updates
        scanTimer = Timer()
        scanTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                updateScanData()
            }
        }, 0, 100)
        
        result.success(true)
    }
    
    private fun pauseScanning(result: MethodChannel.Result) {
        isScanning = false
        scanTimer?.cancel()
        result.success(true)
    }
    
    private fun resumeScanning(result: MethodChannel.Result) {
        isScanning = true
        scanTimer = Timer()
        scanTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                updateScanData()
            }
        }, 0, 100)
        result.success(true)
    }
    
    private fun updateScanData() {
        if (!isScanning || arSession == null) return
        
        try {
            val frame = arSession?.update()
            
            // Extract point cloud from depth
            frame?.acquirePointCloud()?.use { points ->
                val buffer = points.points
                buffer.rewind()
                
                // Sample points (not all for performance)
                val step = 10
                var i = 0
                while (buffer.hasRemaining() && i < buffer.remaining() / 4) {
                    if (i % step == 0) {
                        val x = buffer.float
                        val y = buffer.float
                        val z = buffer.float
                        val confidence = buffer.float
                        
                        if (confidence > 0.5f) {
                            pointCloud.add(floatArrayOf(x, y, z))
                        }
                    } else {
                        buffer.position(buffer.position() + 4)
                    }
                    i++
                }
            }
            
            // Calculate coverage and send to Flutter
            val duration = ((System.currentTimeMillis() - scanStartTime) / 1000).toInt()
            val coverage = calculateCoverage()
            
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf(
                    "pointCount" to pointCloud.size,
                    "coverage" to coverage,
                    "duration" to duration,
                    "isScanning" to isScanning
                ))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun calculateCoverage(): Double {
        val targetPoints = 100000.0
        return minOf(pointCloud.size.toDouble() / targetPoints * 100.0, 100.0)
    }
    
    private fun stopScanning(result: MethodChannel.Result) {
        isScanning = false
        scanTimer?.cancel()
        
        // Generate 3D mesh from point cloud
        generateMesh { filePath ->
            if (filePath != null) {
                val coverage = calculateCoverage()
                val quality = minOf(coverage / 100.0, 1.0)
                
                result.success(mapOf(
                    "filePath" to filePath,
                    "pointCount" to pointCloud.size,
                    "coverage" to coverage,
                    "quality" to quality
                ))
            } else {
                result.error("MESH_GENERATION_FAILED", "Failed to generate mesh", null)
            }
        }
    }
    
    private fun generateMesh(completion: (String?) -> Unit) {
        if (pointCloud.isEmpty()) {
            completion(null)
            return
        }
        
        Thread {
            try {
                // Create GLB file
                val fileName = "scan_${UUID.randomUUID()}.glb"
                val file = File(activity?.filesDir, fileName)
                
                // Simple GLB generation (in production, use proper library)
                FileOutputStream(file).use { fos ->
                    // Write GLB header
                    val header = ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN)
                    header.putInt(0x46546C67) // "glTF" magic
                    header.putInt(2) // version
                    header.putInt(0) // length (will update later)
                    fos.write(header.array())
                    
                    // Write vertex data
                    val vertexBuffer = ByteBuffer.allocate(pointCloud.size * 12).order(ByteOrder.LITTLE_ENDIAN)
                    for (point in pointCloud) {
                        vertexBuffer.putFloat(point[0])
                        vertexBuffer.putFloat(point[1])
                        vertexBuffer.putFloat(point[2])
                    }
                    fos.write(vertexBuffer.array())
                }
                
                Handler(Looper.getMainLooper()).post {
                    completion(file.absolutePath)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                Handler(Looper.getMainLooper()).post {
                    completion(null)
                }
            }
        }.start()
    }
    
    private fun exportScan(scanId: String, format: String, result: MethodChannel.Result) {
        // Export to different formats
        // This is a placeholder - implement actual conversion
        result.success(null)
    }
    
    private fun getScanStatistics(result: MethodChannel.Result) {
        result.success(mapOf(
            "pointCount" to pointCloud.size,
            "coverage" to calculateCoverage(),
            "meshVertices" to pointCloud.size,
            "meshFaces" to maxOf(0, pointCloud.size - 2)
        ))
    }
    
    private fun disposeARSession(result: MethodChannel.Result) {
        scanTimer?.cancel()
        arSession?.pause()
        arSession?.close()
        arSession = null
        pointCloud.clear()
        result.success(null)
    }
}
