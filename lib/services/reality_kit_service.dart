// ============================================================================
// PRODUCTION-READY RealityKit Service
// Flutter ↔ Native RealityKit bridge via platform channels
//
// Works on top of ARKit scanning:
//   1. ARKit  → captures real 3D point cloud (LiDARScannerPlugin)
//   2. RealityKit → renders it as 3D mesh + measurement pins + exports
//
// Channel: "com.lidarscanner/realitykit"
// Events:  "com.lidarscanner/realitykit_events"
// ============================================================================

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/scan_point_model.dart';

// ── Render mode enum ─────────────────────────────────────────────────────────
enum RealityKitRenderMode { solid, wireframe, pointCloud, xray }

extension RealityKitRenderModeExtension on RealityKitRenderMode {
  String get value {
    switch (this) {
      case RealityKitRenderMode.solid:
        return 'solid';
      case RealityKitRenderMode.wireframe:
        return 'wireframe';
      case RealityKitRenderMode.pointCloud:
        return 'pointCloud';
      case RealityKitRenderMode.xray:
        return 'xray';
    }
  }
}

// ── Pin result ───────────────────────────────────────────────────────────────
class RealityKitPin {
  final String pinId;
  final double x;
  final double y;
  final double z;
  final bool isManualPin;

  const RealityKitPin({
    required this.pinId,
    required this.x,
    required this.y,
    required this.z,
    required this.isManualPin,
  });

  factory RealityKitPin.fromMap(Map<String, dynamic> map) => RealityKitPin(
        pinId: map['pinId'] as String,
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        z: (map['z'] as num).toDouble(),
        isManualPin: map['isManualPin'] as bool? ?? true,
      );
}

// ── Measurement line result ──────────────────────────────────────────────────
class RealityKitLine {
  final String lineId;
  final double distanceMeters;
  final double distanceCm;
  final double distanceInches;

  const RealityKitLine({
    required this.lineId,
    required this.distanceMeters,
    required this.distanceCm,
    required this.distanceInches,
  });

  factory RealityKitLine.fromMap(Map<String, dynamic> map) => RealityKitLine(
        lineId: map['lineId'] as String,
        distanceMeters: (map['distance'] as num).toDouble(),
        distanceCm: (map['distanceCm'] as num).toDouble(),
        distanceInches: (map['distanceInches'] as num).toDouble(),
      );
}

// ── Export result ────────────────────────────────────────────────────────────
class RealityKitExport {
  final String filePath;
  final int fileSize;
  final String format;

  const RealityKitExport({
    required this.filePath,
    required this.fileSize,
    required this.format,
  });
}

// ── Main service ─────────────────────────────────────────────────────────────
class RealityKitService {
  static const MethodChannel _channel =
      MethodChannel('com.lidarscanner/realitykit');
  static const EventChannel _eventChannel =
      EventChannel('com.lidarscanner/realitykit_events');

  StreamSubscription? _eventSubscription;
  StreamController<Map<String, dynamic>>? _eventsController;

  bool _isInitialized = false;
  bool _isSupported = false;
  RealityKitRenderMode _currentMode = RealityKitRenderMode.solid;

  // Pin tracking
  final List<RealityKitPin> _placedPins = [];
  final List<RealityKitLine> _placedLines = [];

  // Singleton
  static RealityKitService? _instance;
  static RealityKitService get instance {
    _instance ??= RealityKitService._();
    return _instance!;
  }

  RealityKitService._();

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isInitialized => _isInitialized;
  bool get isSupported => _isSupported;
  RealityKitRenderMode get currentRenderMode => _currentMode;
  List<RealityKitPin> get placedPins => List.unmodifiable(_placedPins);
  List<RealityKitLine> get placedLines => List.unmodifiable(_placedLines);
  int get pinCount => _placedPins.length;

  Stream<Map<String, dynamic>> get events {
    _eventsController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _eventsController!.stream;
  }

  // ── Capability check ───────────────────────────────────────────────────────

  /// Check if RealityKit 2 is available (iOS 15+)
  Future<bool> isRealityKitSupported() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isRealityKitSupported');
      _isSupported = result ?? false;
      debugPrint('🌍 [RealityKit] Supported: $_isSupported');
      return _isSupported;
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] Support check failed: ${e.message}');
      return false;
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Initialize RealityKit native session
  Future<bool> initialize() async {
    try {
      _eventsController ??=
          StreamController<Map<String, dynamic>>.broadcast();

      // Start event stream
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            final data = Map<String, dynamic>.from(event);
            _eventsController?.add(data);
            _handleNativeEvent(data);
          }
        },
        onError: (error) {
          debugPrint('🌍 [RealityKit] ⚠️ Event error: $error');
        },
      );

      final result =
          await _channel.invokeMethod<bool>('initializeRealityKit');
      _isInitialized = result ?? false;

      debugPrint('🌍 [RealityKit] ✅ Initialized: $_isInitialized');
      return _isInitialized;
    } on PlatformException catch (e) {
      debugPrint(
          '🌍 [RealityKit] ❌ Init failed: ${e.code} — ${e.message}');
      _isInitialized = false;
      return false;
    }
  }

  /// Dispose RealityKit session
  Future<void> dispose() async {
    _isInitialized = false;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventsController?.close();
    _eventsController = null;
    _placedPins.clear();
    _placedLines.clear();

    try {
      await _channel.invokeMethod('disposeRealityKit');
    } catch (_) {}

    debugPrint('🌍 [RealityKit] 🧹 Disposed');
  }

  // ── Mesh rendering ─────────────────────────────────────────────────────────

  /// Show scan mesh from ARKit point cloud
  /// Call after stopScanning() with the captured points
  Future<Map<String, dynamic>?> showScanMesh(
    List<ScanPoint> points, {
    RealityKitRenderMode renderMode = RealityKitRenderMode.solid,
  }) async {
    if (!_isInitialized) {
      debugPrint('🌍 [RealityKit] ❌ Not initialized');
      return null;
    }
    if (points.isEmpty) {
      debugPrint('🌍 [RealityKit] ⚠️ No points to render');
      return null;
    }

    try {
      final pointMaps = points
          .map((p) => {
                'x': p.x,
                'y': p.y,
                'z': p.z,
                'confidence': p.confidence,
                'isManualPin': p.isManualPin,
              })
          .toList();

      final result = await _channel.invokeMethod<Map>('showScanMesh', {
        'points': pointMaps,
        'renderMode': renderMode.value,
      });

      _currentMode = renderMode;
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ❌ showScanMesh: ${e.message}');
      return null;
    }
  }

  /// Update existing mesh with new points (live update during scan)
  Future<void> updateScanMesh(List<ScanPoint> points) async {
    if (!_isInitialized || points.isEmpty) return;
    try {
      final pointMaps = points
          .map((p) =>
              {'x': p.x, 'y': p.y, 'z': p.z, 'confidence': p.confidence})
          .toList();
      await _channel.invokeMethod('updateScanMesh', {'points': pointMaps});
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ⚠️ updateScanMesh: ${e.message}');
    }
  }

  /// Clear 3D scan mesh
  Future<void> clearScanMesh() async {
    try {
      await _channel.invokeMethod('clearScanMesh');
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ⚠️ clearScanMesh: ${e.message}');
    }
  }

  // ── Measurement pins ───────────────────────────────────────────────────────

  /// Place a real 3D sphere at world coordinates
  Future<RealityKitPin?> placeMeasurementPin(
    double x,
    double y,
    double z, {
    String? label,
    bool isManualPin = true,
  }) async {
    if (!_isInitialized) {
      debugPrint('🌍 [RealityKit] ❌ Not initialized');
      return null;
    }

    try {
      final result =
          await _channel.invokeMethod<Map>('placeMeasurementPin', {
        'x': x,
        'y': y,
        'z': z,
        'label': label,
        'isManualPin': isManualPin,
      });

      if (result == null) return null;
      final pin = RealityKitPin.fromMap(Map<String, dynamic>.from(result));
      _placedPins.add(pin);
      return pin;
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ❌ placeMeasurementPin: ${e.message}');
      return null;
    }
  }

  /// Place pin from a ScanPoint (convenience)
  Future<RealityKitPin?> placePinFromScanPoint(ScanPoint point,
      {String? label}) async {
    return placeMeasurementPin(
      point.x,
      point.y,
      point.z,
      label: label ?? (point.isManualPin ? 'Pin ${_placedPins.length + 1}' : null),
      isManualPin: point.isManualPin,
    );
  }

  /// Place measurement line between two 3D points + get real distance
  Future<RealityKitLine?> placeMeasurementLine(
    ScanPoint from,
    ScanPoint to, {
    String? label,
  }) async {
    if (!_isInitialized) return null;

    try {
      final result =
          await _channel.invokeMethod<Map>('placeMeasurementLine', {
        'point1': {'x': from.x, 'y': from.y, 'z': from.z},
        'point2': {'x': to.x, 'y': to.y, 'z': to.z},
        'label': label,
      });

      if (result == null) return null;
      final line =
          RealityKitLine.fromMap(Map<String, dynamic>.from(result));
      _placedLines.add(line);
      return line;
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ❌ placeMeasurementLine: ${e.message}');
      return null;
    }
  }

  /// Clear all measurement pins and lines
  Future<void> clearMeasurementPins() async {
    try {
      await _channel.invokeMethod('clearMeasurementPins');
      _placedPins.clear();
      _placedLines.clear();
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ⚠️ clearMeasurementPins: ${e.message}');
    }
  }

  /// Clear everything (mesh + pins + lines)
  Future<void> clearScene() async {
    try {
      await _channel.invokeMethod('clearScene');
      _placedPins.clear();
      _placedLines.clear();
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ⚠️ clearScene: ${e.message}');
    }
  }

  // ── Render modes ───────────────────────────────────────────────────────────

  Future<bool> setRenderMode(RealityKitRenderMode mode) async {
    try {
      await _channel
          .invokeMethod('setRenderMode', {'mode': mode.value});
      _currentMode = mode;
      return true;
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ⚠️ setRenderMode: ${e.message}');
      return false;
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Export scan as OBJ file — uses real ARKit mesh anchors
  Future<RealityKitExport?> exportMeshAsOBJ() async {
    if (!_isInitialized) return null;
    try {
      final result =
          await _channel.invokeMethod<Map>('exportMeshAsOBJ');
      if (result == null) return null;
      final data = Map<String, dynamic>.from(result);
      return RealityKitExport(
        filePath: data['filePath'] as String,
        fileSize: data['fileSize'] as int? ?? 0,
        format: 'obj',
      );
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ❌ exportOBJ: ${e.message}');
      return null;
    }
  }

  /// Export scan as USDZ — AR QuickLook ready
  Future<RealityKitExport?> exportMeshAsUSDZ() async {
    if (!_isInitialized) return null;
    try {
      final result =
          await _channel.invokeMethod<Map>('exportMeshAsUSDZ');
      if (result == null) return null;
      final data = Map<String, dynamic>.from(result);
      return RealityKitExport(
        filePath: data['filePath'] as String,
        fileSize: data['fileSize'] as int? ?? 0,
        format: 'usdz',
      );
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ❌ exportUSDZ: ${e.message}');
      return null;
    }
  }

  // ── Status ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final result =
          await _channel.invokeMethod<Map>('getRealityKitStatus');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      debugPrint('🌍 [RealityKit] ⚠️ getStatus: ${e.message}');
      return null;
    }
  }

  // ── Private: handle native events ─────────────────────────────────────────

  void _handleNativeEvent(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    switch (type) {
      case 'meshShown':
        debugPrint(
            '🌍 [RealityKit] Mesh shown — ${data['pointCount']} points');
        break;
      case 'pinPlaced':
        debugPrint(
            '🌍 [RealityKit] Pin placed — total: ${data['totalPins']}');
        break;
      case 'linePlaced':
        debugPrint(
            '🌍 [RealityKit] Line placed — ${data['distanceCm']}cm');
        break;
      default:
        break;
    }
  }
}
