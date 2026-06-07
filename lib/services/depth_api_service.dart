// Production-ready Depth API Service
// Platform channel bridge to native ARCore (Android) and ARKit (iOS) depth APIs
// Provides real depth data, AR session management, and depth queries
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

// Depth API service — communicates with native ARCore/ARKit via platform channels
class DepthApiService {
  static const MethodChannel _channel = MethodChannel('com.lidarscanner/native');
  static const EventChannel _eventChannel = EventChannel('com.lidarscanner/scan_events');

  StreamSubscription? _eventSubscription;
  Function(Map<String, dynamic>)? _onScanUpdate;

  bool _isInitialized = false;
  bool _isScanning = false;
  bool _depthSupported = false;

  // Singleton
  static DepthApiService? _instance;
  static DepthApiService get instance {
    _instance ??= DepthApiService._();
    return _instance!;
  }
  DepthApiService._();

  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get depthSupported => _depthSupported;

  /// Check if device has LiDAR sensor (iOS Pro models)
  Future<bool> isLiDARAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLiDARAvailable');
      debugPrint('🔍 [DepthAPI] LiDAR available: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] LiDAR check failed: ${e.message}');
      return false;
    }
  }

  /// Check if ARCore is supported (Android)
  Future<bool> isARCoreSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isARCoreSupported');
      debugPrint('🔍 [DepthAPI] ARCore supported: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ARCore check failed: ${e.message}');
      return false;
    }
  }

  /// Check if Depth API is supported on this device
  Future<bool> isDepthApiSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDepthSupported');
      _depthSupported = result ?? false;
      debugPrint('🔍 [DepthAPI] Depth API supported: $_depthSupported');
      return _depthSupported;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] Depth check failed: ${e.message}');
      return false;
    }
  }

  /// Initialize native AR session (ARCore on Android, ARKit on iOS)
  Future<bool> initializeSession() async {
    try {
      final result = await _channel.invokeMethod<bool>('initializeARSession');
      _isInitialized = result ?? false;

      if (_isInitialized) {
        // Check depth support after session init
        _depthSupported = await isDepthApiSupported();
      }

      debugPrint('🔍 [DepthAPI] Session initialized: $_isInitialized (depth: $_depthSupported)');
      return _isInitialized;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ❌ Session init failed: ${e.code} — ${e.message}');
      _isInitialized = false;
      return false;
    }
  }

  /// Start AR scanning
  Future<bool> startScanning({
    Function(Map<String, dynamic>)? onUpdate,
  }) async {
    if (!_isInitialized) {
      debugPrint('🔍 [DepthAPI] ❌ Cannot start scanning — session not initialized');
      return false;
    }
    try {
      _onScanUpdate = onUpdate;

      // Listen to event stream
      _eventSubscription = _eventChannel
          .receiveBroadcastStream()
          .listen(
            (event) {
              if (event is Map) {
                final data = Map<String, dynamic>.from(event);
                _onScanUpdate?.call(data);
              }
            },
            onError: (error) {
              debugPrint('🔍 [DepthAPI] ⚠️ Event stream error: $error');
            },
          );

      final result = await _channel.invokeMethod<bool>('startScanning');
      _isScanning = result ?? false;
      debugPrint('🔍 [DepthAPI] ✅ Scanning started: $_isScanning');
      return _isScanning;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ❌ Start scanning failed: ${e.message}');
      return false;
    }
  }

  /// Pause scanning
  Future<void> pauseScanning() async {
    try {
      await _channel.invokeMethod('pauseScanning');
      _isScanning = false;
      debugPrint('🔍 [DepthAPI] ⏸️ Scanning paused');
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ⚠️ Pause failed: ${e.message}');
    }
  }

  /// Resume scanning
  Future<void> resumeScanning() async {
    try {
      await _channel.invokeMethod('resumeScanning');
      _isScanning = true;
      debugPrint('🔍 [DepthAPI] ▶️ Scanning resumed');
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ⚠️ Resume failed: ${e.message}');
    }
  }

  /// Stop scanning and get final results
  Future<Map<String, dynamic>?> stopScanning() async {
    try {
      final result = await _channel.invokeMethod<Map>('stopScanning');
      _isScanning = false;
      _eventSubscription?.cancel();
      _eventSubscription = null;

      final data = result != null ? Map<String, dynamic>.from(result) : null;
      debugPrint('🔍 [DepthAPI] 🛑 Scanning stopped: $data');
      return data;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ❌ Stop failed: ${e.message}');
      _isScanning = false;
      return null;
    }
  }

  /// Get depth at a specific normalized screen point (0..1, 0..1)
  /// Returns depth in meters and confidence score
  Future<DepthResult> getDepthAtPoint(double normalizedX, double normalizedY) async {
    try {
      final result = await _channel.invokeMethod<Map>('getDepthAtPoint', {
        'x': normalizedX,
        'y': normalizedY,
      });

      if (result != null) {
        final data = Map<String, dynamic>.from(result);
        return DepthResult(
          depth: (data['depth'] as num).toDouble(),
          confidence: (data['confidence'] as num).toDouble(),
        );
      }

      return DepthResult.unknown();
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ⚠️ Depth query failed: ${e.message}');
      return DepthResult.unknown();
    }
  }

  /// Perform a real raycast hit-test at normalized screen coordinates.
  /// Returns a 3D world coordinate map: { x, y, z, confidence, sequenceNumber }
  Future<Map<String, dynamic>?> performHitTest(
      double normalizedX, double normalizedY) async {
    try {
      final result = await _channel.invokeMethod<Map>('performHitTest', {
        'x': normalizedX,
        'y': normalizedY,
      });
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ⚠️ Hit test failed: ${e.code} — ${e.message}');
      return null;
    }
  }

  /// Get scan statistics
  Future<Map<String, dynamic>?> getScanStatistics() async {
    try {
      final result = await _channel.invokeMethod<Map>('getScanStatistics');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ⚠️ Stats failed: ${e.message}');
      return null;
    }
  }

  /// Dispose native AR session
  Future<void> dispose() async {
    try {
      _eventSubscription?.cancel();
      _eventSubscription = null;
      await _channel.invokeMethod('disposeARSession');
      _isInitialized = false;
      _isScanning = false;
      debugPrint('🔍 [DepthAPI] 🧹 Disposed');
    } on PlatformException catch (e) {
      debugPrint('🔍 [DepthAPI] ⚠️ Dispose failed: ${e.message}');
    }
  }
}

// Result of a depth query
class DepthResult {
  final double depth; // meters
  final double confidence; // 0.0 to 1.0

  DepthResult({required this.depth, required this.confidence});

  /// Unknown/default depth result
  factory DepthResult.unknown() => DepthResult(depth: 1.5, confidence: 0.0);

  /// Is this result reliable enough for measurement?
  bool get isReliable => confidence >= 0.5 && depth > 0.05 && depth < 10.0;

  @override
  String toString() => 'DepthResult(depth: ${depth.toStringAsFixed(3)}m, '
      'confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}
