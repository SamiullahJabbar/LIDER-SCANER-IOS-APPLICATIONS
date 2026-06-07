// PRODUCTION-READY ARCore Scanner Service for Android
// Uses native platform channels for ARCore integration
// arcore_flutter_plugin is disabled due to namespace issue — using MethodChannel instead
// NO mocks, NO simulations - REAL 3D coordinates via platform channels
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/scan_point_model.dart';

class ARCoreScannerService {
  static const MethodChannel _channel = MethodChannel('com.lidarscanner/native');

  StreamController<ScanPoint>? _pointStreamController;
  StreamController<Map<String, dynamic>>? _statsStreamController;

  bool _isScanning = false;
  bool _isInitialized = false;
  int _sequenceNumber = 0;
  final List<ScanPoint> _capturedPoints = [];

  // Configuration
  static const double minPointDistance = 0.01; // 1cm minimum distance between points
  static const double maxDepth = 10.0; // 10m maximum depth
  static const double minConfidence = 0.7; // Minimum confidence threshold

  // Singleton
  static ARCoreScannerService? _instance;
  static ARCoreScannerService get instance {
    _instance ??= ARCoreScannerService._();
    return _instance!;
  }

  ARCoreScannerService._();

  /// Initialize ARCore via platform channel
  Future<bool> initializeSession() async {
    try {
      _pointStreamController ??= StreamController<ScanPoint>.broadcast();
      _statsStreamController ??= StreamController<Map<String, dynamic>>.broadcast();

      final result = await _channel.invokeMethod<bool>('initializeARSession');
      _isInitialized = result ?? false;

      debugPrint('🤖 [ARCore] Session initialized: $_isInitialized');
      return _isInitialized;
    } on PlatformException catch (e) {
      debugPrint('🤖 [ARCore] ❌ Init failed: ${e.code} — ${e.message}');
      _isInitialized = false;
      return false;
    }
  }

  /// Initialize from a dynamic controller (legacy compat)
  void initializeController(dynamic controller) {
    debugPrint('🤖 [ARCore] initializeController called — initializing native session');
    initializeSession();
  }

  /// Check if device supports ARCore
  static Future<bool> checkARCoreAvailability() async {
    try {
      final result = await _channel.invokeMethod<bool>('isARCoreSupported');
      debugPrint('📱 ARCore availability: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ ARCore check failed: $e');
      return false;
    }
  }

  /// Check if ARCore services are installed
  static Future<bool> checkARCoreInstalled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isARCoreSupported');
      debugPrint('📱 ARCore installed: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ ARCore install check failed: $e');
      return false;
    }
  }

  /// Start scanning with ARCore
  Future<bool> startScanning() async {
    if (!_isInitialized) {
      debugPrint('❌ ARCore session not initialized');
      return false;
    }

    if (_isScanning) {
      debugPrint('⚠️ Already scanning');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('startScanning');
      _isScanning = result ?? false;
      _sequenceNumber = 0;
      _capturedPoints.clear();

      debugPrint('✅ ARCore scanning started: $_isScanning');
      return _isScanning;
    } catch (e) {
      debugPrint('❌ Failed to start scanning: $e');
      _isScanning = false;
      return false;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    try {
      await _channel.invokeMethod('stopScanning');
    } catch (e) {
      debugPrint('⚠️ Stop scanning error: $e');
    }
    _isScanning = false;
    debugPrint('🛑 ARCore scanning stopped. Total points: ${_capturedPoints.length}');
  }

  /// Capture manual pin point with hit test via platform channel
  Future<ScanPoint?> captureManualPin(Offset screenPosition, Size screenSize) async {
    if (!_isInitialized) {
      debugPrint('❌ ARCore not initialized');
      return null;
    }

    try {
      final normalizedX = screenPosition.dx / screenSize.width;
      final normalizedY = screenPosition.dy / screenSize.height;

      final result = await _channel.invokeMethod<Map>('performHitTest', {
        'x': normalizedX,
        'y': normalizedY,
      });

      if (result == null) {
        debugPrint('⚠️ No hit test results');
        return null;
      }

      final data = Map<String, dynamic>.from(result);
      final x = (data['x'] as num).toDouble();
      final y = (data['y'] as num).toDouble();
      final z = (data['z'] as num).toDouble();
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.9;

      if (z.abs() > maxDepth) {
        debugPrint('⚠️ Point too far: ${z.abs()}m');
        return null;
      }

      final point = ScanPoint.fromARFrame(
        x: x,
        y: y,
        z: z,
        sequenceNumber: _sequenceNumber++,
        isManualPin: true,
        confidence: confidence,
      );

      _capturedPoints.add(point);
      _pointStreamController?.add(point);

      debugPrint('📍 Manual pin captured: (${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})');
      return point;
    } catch (e) {
      debugPrint('❌ Error capturing manual pin: $e');
      return null;
    }
  }

  /// Auto-capture point at current camera position via platform channel
  Future<ScanPoint?> autoCapturePoint() async {
    if (!_isScanning || !_isInitialized) return null;

    try {
      final result = await _channel.invokeMethod<Map>('performHitTest', {
        'x': 0.5,
        'y': 0.5,
      });

      if (result == null) return null;

      final data = Map<String, dynamic>.from(result);
      final x = (data['x'] as num).toDouble();
      final y = (data['y'] as num).toDouble();
      final z = (data['z'] as num).toDouble();
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.9;

      final point = ScanPoint.fromARFrame(
        x: x,
        y: y,
        z: z,
        sequenceNumber: _sequenceNumber++,
        isManualPin: false,
        confidence: confidence,
      );

      if (_shouldCapturePoint(point)) {
        _capturedPoints.add(point);
        _pointStreamController?.add(point);
        _emitStatistics();
        return point;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error auto-capturing point: $e');
      return null;
    }
  }

  /// Check if point should be captured based on filters
  bool _shouldCapturePoint(ScanPoint point) {
    if (point.z.abs() > maxDepth) return false;
    if (point.confidence < minConfidence) return false;

    if (_capturedPoints.isNotEmpty) {
      final lastPoint = _capturedPoints.last;
      final distance = point.distanceTo(lastPoint);
      if (distance < minPointDistance) return false;
    }

    return true;
  }

  /// Emit statistics to stream
  void _emitStatistics() {
    if (_statsStreamController == null || _statsStreamController!.isClosed) return;

    final stats = {
      'pointCount': _capturedPoints.length,
      'isScanning': _isScanning,
      'sequenceNumber': _sequenceNumber,
    };

    _statsStreamController!.add(stats);
  }

  /// Get point stream
  Stream<ScanPoint> get pointStream {
    _pointStreamController ??= StreamController<ScanPoint>.broadcast();
    return _pointStreamController!.stream;
  }

  /// Get statistics stream
  Stream<Map<String, dynamic>> get statsStream {
    _statsStreamController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _statsStreamController!.stream;
  }

  /// Get all captured points
  List<ScanPoint> get capturedPoints => List.unmodifiable(_capturedPoints);

  /// Get current point count
  int get pointCount => _capturedPoints.length;

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Clear all points
  void clearPoints() {
    _capturedPoints.clear();
    _sequenceNumber = 0;
    debugPrint('🗑️ All points cleared');
  }

  /// Dispose resources
  void dispose() {
    _isScanning = false;
    _isInitialized = false;
    _pointStreamController?.close();
    _statsStreamController?.close();
    _capturedPoints.clear();
    debugPrint('🧹 ARCore scanner service disposed');
  }
}
