// ============================================================================
// PRODUCTION-READY ARKit Scanner Service
// Real ARKit integration via native platform channels
//
// • Manual pin: real raycast hit-test → true 3D world coordinates
// • Auto-capture: native ARSession depth sampling streamed via EventChannel
// • NO mocks, NO simulations, NO fake depth
// ============================================================================
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/scan_point_model.dart';

class ARKitScannerService {
  // Platform channel — same name as native plugin
  static const MethodChannel _channel =
      MethodChannel('com.lidarscanner/native');
  static const EventChannel _eventChannel =
      EventChannel('com.lidarscanner/scan_events');

  // Streams
  StreamController<ScanPoint>? _pointStreamController;
  StreamController<Map<String, dynamic>>? _statsStreamController;
  StreamSubscription? _eventSubscription;

  bool _isScanning = false;
  bool _isInitialized = false;
  int _sequenceNumber = 0;
  final List<ScanPoint> _capturedPoints = [];

  // Configuration
  static const double minPointDistance = 0.005; // 5mm
  static const double maxDepth = 8.0; // 8m
  static const double minConfidence = 0.5;

  // Singleton
  static ARKitScannerService? _instance;
  static ARKitScannerService get instance {
    _instance ??= ARKitScannerService._();
    return _instance!;
  }

  ARKitScannerService._();

  // ── Public getters ─────────────────────────────────────────────────

  Stream<ScanPoint> get pointStream {
    _pointStreamController ??= StreamController<ScanPoint>.broadcast();
    return _pointStreamController!.stream;
  }

  Stream<Map<String, dynamic>> get statsStream {
    _statsStreamController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _statsStreamController!.stream;
  }

  List<ScanPoint> get capturedPoints => List.unmodifiable(_capturedPoints);
  int get pointCount => _capturedPoints.length;
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;

  // ── Initialization ─────────────────────────────────────────────────

  /// Initialize native ARKit session (real ARWorldTrackingConfiguration)
  Future<bool> initializeSession() async {
    try {
      _pointStreamController ??= StreamController<ScanPoint>.broadcast();
      _statsStreamController ??= StreamController<Map<String, dynamic>>.broadcast();

      final result = await _channel.invokeMethod<bool>('initializeARSession');
      _isInitialized = result ?? false;

      if (_isInitialized) {
        debugPrint('🍎 [ARKitService] ✅ Native ARKit session initialized');
      }
      return _isInitialized;
    } on PlatformException catch (e) {
      debugPrint('🍎 [ARKitService] ❌ Init failed: ${e.code} — ${e.message}');
      _isInitialized = false;
      return false;
    }
  }

  /// Initialize from ARKit plugin controller (legacy compat)
  /// This now also initializes the native session for real depth/hit-test.
  void initializeController(dynamic controller) {
    debugPrint('🍎 [ARKitService] initializeController called — initializing native session');
    initializeSession();
  }

  /// Check if device has LiDAR
  Future<bool> hasLiDAR() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLiDARAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ── Scanning lifecycle ─────────────────────────────────────────────

  /// Start scanning — native ARKit begins depth frame processing
  Future<bool> startScanning() async {
    if (!_isInitialized) {
      debugPrint('🍎 [ARKitService] ❌ Not initialized, cannot start');
      return false;
    }
    if (_isScanning) {
      debugPrint('🍎 [ARKitService] ⚠️ Already scanning');
      return false;
    }

    try {
      // Start listening to native event channel for auto-captured points
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleNativeEvent,
        onError: (error) {
          debugPrint('🍎 [ARKitService] ⚠️ Event stream error: $error');
        },
      );

      final result = await _channel.invokeMethod<bool>('startScanning');
      _isScanning = result ?? false;

      if (_isScanning) {
        debugPrint('🍎 [ARKitService] ✅ Scanning started (seq: $_sequenceNumber)');
      }
      return _isScanning;
    } on PlatformException catch (e) {
      debugPrint('🍎 [ARKitService] ❌ Start failed: ${e.message}');
      _isScanning = false;
      return false;
    }
  }

  /// Stop scanning — returns final stats
  Future<Map<String, dynamic>?> stopScanning() async {
    _isScanning = false;
    _eventSubscription?.cancel();
    _eventSubscription = null;

    try {
      final result = await _channel.invokeMethod<Map>('stopScanning');
      final data = result != null ? Map<String, dynamic>.from(result) : null;
      debugPrint('🍎 [ARKitService] 🛑 Stopped — ${_capturedPoints.length} points');
      return data;
    } on PlatformException catch (e) {
      debugPrint('🍎 [ARKitService] ⚠️ Stop failed: ${e.message}');
      return null;
    }
  }

  // ── Manual Pin Capture (real hit-test) ─────────────────────────────

  /// Capture manual pin at screen position using REAL native raycast.
  /// Returns a real 3D world coordinate from ARKit hit-test.
  Future<ScanPoint?> captureManualPin(
      Offset screenPosition, Size screenSize) async {
    if (!_isInitialized) {
      debugPrint('🍎 [ARKitService] ❌ Not initialized');
      return null;
    }

    try {
      // Normalize screen coords (0..1)
      final normalizedX = screenPosition.dx / screenSize.width;
      final normalizedY = screenPosition.dy / screenSize.height;

      // Call native performHitTest — real ARKit raycast
      final result = await _channel.invokeMethod<Map>('performHitTest', {
        'x': normalizedX,
        'y': normalizedY,
      });

      if (result == null) {
        debugPrint('🍎 [ARKitService] ⚠️ Hit test returned null');
        return null;
      }

      final data = Map<String, dynamic>.from(result);
      final x = (data['x'] as num).toDouble();
      final y = (data['y'] as num).toDouble();
      final z = (data['z'] as num).toDouble();
      final confidence = (data['confidence'] as num).toDouble();

      // Validate
      final dist = (x * x + y * y + z * z);
      if (dist > maxDepth * maxDepth) {
        debugPrint('🍎 [ARKitService] ⚠️ Hit point too far');
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
      _emitStatistics();

      debugPrint(
          '📍 [ARKitService] Manual pin: (${x.toStringAsFixed(3)}, '
          '${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)}) '
          'conf=${confidence.toStringAsFixed(2)}');

      return point;
    } on PlatformException catch (e) {
      if (e.code == 'NO_HIT') {
        debugPrint('🍎 [ARKitService] ⚠️ No surface detected at tap point');
      } else {
        debugPrint('🍎 [ARKitService] ❌ Hit test error: ${e.code} — ${e.message}');
      }
      return null;
    }
  }

  // ── Auto-capture (from native event stream) ────────────────────────

  /// Auto-capture point via native depth query at screen center.
  /// Fallback for when the native auto-capture event stream is not producing.
  Future<ScanPoint?> autoCapturePoint(
      Offset screenCenter, Size screenSize) async {
    if (!_isScanning || !_isInitialized) return null;

    try {
      // Query real depth at screen center
      final depthResult = await _channel.invokeMethod<Map>('getDepthAtPoint', {
        'x': 0.5, // center
        'y': 0.5,
      });

      if (depthResult == null) return null;

      final data = Map<String, dynamic>.from(depthResult);
      final depth = (data['depth'] as num).toDouble();
      final confidence = (data['confidence'] as num).toDouble();

      if (depth < 0.05 || depth > maxDepth || confidence < minConfidence) {
        return null;
      }

      // Use hit-test for real 3D world coordinate at center
      final hitResult = await _channel.invokeMethod<Map>('performHitTest', {
        'x': 0.5,
        'y': 0.5,
      });

      if (hitResult == null) return null;

      final hit = Map<String, dynamic>.from(hitResult);
      final x = (hit['x'] as num).toDouble();
      final y = (hit['y'] as num).toDouble();
      final z = (hit['z'] as num).toDouble();

      // Distance filter
      if (_capturedPoints.isNotEmpty) {
        final last = _capturedPoints.last;
        final dx = x - last.x;
        final dy = y - last.y;
        final dz = z - last.z;
        final dist = (dx * dx + dy * dy + dz * dz);
        if (dist < minPointDistance * minPointDistance) return null;
      }

      final point = ScanPoint.fromARFrame(
        x: x,
        y: y,
        z: z,
        sequenceNumber: _sequenceNumber++,
        isManualPin: false,
        confidence: confidence,
      );

      _capturedPoints.add(point);
      _pointStreamController?.add(point);
      _emitStatistics();

      return point;
    } on PlatformException catch (e) {
      debugPrint('🍎 [ARKitService] Auto-capture error: ${e.message}');
      return null;
    }
  }

  // ── Native Event Handler ───────────────────────────────────────────

  /// Process events streamed from native ARKit (auto-captured point batches)
  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final data = Map<String, dynamic>.from(event);
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'points':
        _handlePointsBatch(data);
        break;
      case 'error':
        debugPrint('🍎 [ARKitService] Native error: ${data['message']}');
        break;
      case 'interrupted':
        debugPrint('🍎 [ARKitService] ⚠️ AR session interrupted');
        break;
      case 'resumed':
        debugPrint('🍎 [ARKitService] ✅ AR session resumed');
        break;
    }
  }

  /// Process a batch of auto-captured points from native
  void _handlePointsBatch(Map<String, dynamic> data) {
    final points = data['points'] as List? ?? [];
    final totalCount = data['totalPointCount'] as int? ?? 0;
    final coverage = (data['coverage'] as num?)?.toDouble() ?? 0.0;

    for (final raw in points) {
      if (raw is! Map) continue;
      final pt = Map<String, dynamic>.from(raw);

      final x = (pt['x'] as num).toDouble();
      final y = (pt['y'] as num).toDouble();
      final z = (pt['z'] as num).toDouble();
      final confidence = (pt['confidence'] as num).toDouble();

      final point = ScanPoint.fromARFrame(
        x: x,
        y: y,
        z: z,
        sequenceNumber: _sequenceNumber++,
        isManualPin: false,
        confidence: confidence,
      );

      _capturedPoints.add(point);
      _pointStreamController?.add(point);
    }

    // Emit combined stats
    _statsStreamController?.add({
      'pointCount': _capturedPoints.length,
      'nativePointCount': totalCount,
      'coverage': coverage,
      'isScanning': _isScanning,
      'sequenceNumber': _sequenceNumber,
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _emitStatistics() {
    if (_statsStreamController == null || _statsStreamController!.isClosed) {
      return;
    }
    _statsStreamController!.add({
      'pointCount': _capturedPoints.length,
      'isScanning': _isScanning,
      'sequenceNumber': _sequenceNumber,
    });
  }

  /// Clear all captured points (for new scan)
  void clearPoints() {
    _capturedPoints.clear();
    _sequenceNumber = 0;
    debugPrint('🗑️ [ARKitService] Points cleared');
  }

  /// Dispose everything
  void dispose() {
    _isScanning = false;
    _isInitialized = false;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _pointStreamController?.close();
    _pointStreamController = null;
    _statsStreamController?.close();
    _statsStreamController = null;
    _capturedPoints.clear();

    try {
      _channel.invokeMethod('disposeARSession');
    } catch (_) {}

    debugPrint('🧹 [ARKitService] Disposed');
  }
}
