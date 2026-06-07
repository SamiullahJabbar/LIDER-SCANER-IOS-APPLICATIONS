import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class NativeScannerService {
  static const MethodChannel _channel = MethodChannel('com.lidarscanner/native');
  static const EventChannel _eventChannel = EventChannel('com.lidarscanner/scan_events');

  static NativeScannerService? _instance;
  static NativeScannerService get instance {
    _instance ??= NativeScannerService._();
    return _instance!;
  }

  NativeScannerService._();

  Stream<Map<String, dynamic>>? _scanStream;

  // Check if LiDAR is available (iOS only)
  Future<bool> isLiDARAvailable() async {
    try {
      final bool result = await _channel.invokeMethod('isLiDARAvailable');
      return result;
    } catch (e) {
      debugPrint('Error checking LiDAR availability: $e');
      return false;
    }
  }

  // Check if ARCore is supported (Android only)
  Future<bool> isARCoreSupported() async {
    try {
      final bool result = await _channel.invokeMethod('isARCoreSupported');
      return result;
    } catch (e) {
      debugPrint('Error checking ARCore support: $e');
      return false;
    }
  }

  // Initialize AR session
  Future<bool> initializeARSession() async {
    try {
      final bool result = await _channel.invokeMethod('initializeARSession');
      return result;
    } catch (e) {
      debugPrint('Error initializing AR session: $e');
      return false;
    }
  }

  // Start LiDAR/ARCore scanning
  Future<bool> startScanning() async {
    try {
      final bool result = await _channel.invokeMethod('startScanning');
      return result;
    } catch (e) {
      debugPrint('Error starting scan: $e');
      return false;
    }
  }

  // Pause scanning
  Future<bool> pauseScanning() async {
    try {
      final bool result = await _channel.invokeMethod('pauseScanning');
      return result;
    } catch (e) {
      debugPrint('Error pausing scan: $e');
      return false;
    }
  }

  // Resume scanning
  Future<bool> resumeScanning() async {
    try {
      final bool result = await _channel.invokeMethod('resumeScanning');
      return result;
    } catch (e) {
      debugPrint('Error resuming scan: $e');
      return false;
    }
  }

  // Stop scanning and generate 3D model
  Future<Map<String, dynamic>?> stopScanning() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('stopScanning');
      return {
        'filePath': result['filePath'] as String,
        'pointCount': result['pointCount'] as int,
        'coverage': result['coverage'] as double,
        'quality': result['quality'] as double,
      };
    } catch (e) {
      debugPrint('Error stopping scan: $e');
      return null;
    }
  }

  // Get real-time scan data stream
  Stream<Map<String, dynamic>> getScanDataStream() {
    _scanStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return {
        'pointCount': event['pointCount'] as int,
        'coverage': event['coverage'] as double,
        'duration': event['duration'] as int,
        'isScanning': event['isScanning'] as bool,
      };
    });
    return _scanStream!;
  }

  // Export scan to different formats
  Future<String?> exportScan({
    required String scanId,
    required String format, // 'glb', 'gltf', 'obj', 'fbx'
  }) async {
    try {
      final String? filePath = await _channel.invokeMethod('exportScan', {
        'scanId': scanId,
        'format': format,
      });
      return filePath;
    } catch (e) {
      debugPrint('Error exporting scan: $e');
      return null;
    }
  }

  // Get scan statistics
  Future<Map<String, dynamic>?> getScanStatistics() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getScanStatistics');
      return {
        'pointCount': result['pointCount'] as int,
        'coverage': result['coverage'] as double,
        'meshVertices': result['meshVertices'] as int,
        'meshFaces': result['meshFaces'] as int,
      };
    } catch (e) {
      debugPrint('Error getting scan statistics: $e');
      return null;
    }
  }

  // Clean up AR session
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('disposeARSession');
    } catch (e) {
      debugPrint('Error disposing AR session: $e');
    }
  }
}
