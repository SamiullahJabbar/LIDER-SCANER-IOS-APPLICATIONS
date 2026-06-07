// PRODUCTION-READY Camera Scanner Service
// For Android devices without ARCore or as fallback
// Uses camera + device sensors (accelerometer/gyroscope) for real movement detection
// NO mocks, NO fake random data — real sensor-based coordinate estimation
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/scan_point_model.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class CameraScannerService {
  CameraController? _cameraController;
  StreamController<ScanPoint>? _pointStreamController;
  StreamController<Map<String, dynamic>>? _statsStreamController;

  bool _isScanning = false;
  int _sequenceNumber = 0;
  final List<ScanPoint> _capturedPoints = [];

  // Camera state
  DateTime? _lastCaptureTime;

  // Auto-capture timer
  Timer? _autoCaptureTimer;

  // --- REAL SENSOR DATA ---
  // Accelerometer for detecting device movement
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Current device orientation from gyroscope (cumulative rotation in radians)
  double _rotationX = 0.0; // Pitch (tilt up/down)
  double _rotationY = 0.0; // Yaw (turn left/right)
  double _rotationZ = 0.0; // Roll

  // Current acceleration data
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 0.0;

  // Estimated position from integrating acceleration (simplified dead reckoning)
  double _positionX = 0.0;
  double _positionY = 0.0;
  double _positionZ = 0.0;

  // Velocity estimate
  double _velocityX = 0.0;
  double _velocityY = 0.0;
  double _velocityZ = 0.0;

  // Last sensor timestamp
  DateTime? _lastSensorTime;

  // Movement detection
  bool _isDeviceMoving = false;
  double _movementMagnitude = 0.0;
  double get movementMagnitude => _movementMagnitude;
  
  // Public rotation getters (for AR-like projection in painter)
  double get rotationX => _rotationX;
  double get rotationY => _rotationY;
  double get rotationZ => _rotationZ;

  // Device capability tracking
  String _deviceModel = 'Unknown';
  String _arCapability = 'Camera'; // Camera, ARKit, or LiDAR

  // Configuration
  static const double minPointDistance = 0.02; // 2cm minimum between points
  static const double defaultDepth = 1.5; // 1.5 meter default depth
  static const int autoCaptureIntervalMs = 150; // 150ms (~7 points/sec)
  static const double movementThreshold = 0.08; // LOWERED: detect even small movement
  static const double gravityMagnitude = 9.81;

  // Low-pass filter coefficient (0 = max smooth, 1 = no filter)
  // 0.5 = balanced — smooth enough but still responsive to movement
  static const double _lpfAlpha = 0.5;

  // Filtered sensor values
  double _filteredAccelX = 0.0;
  double _filteredAccelY = 0.0;
  double _filteredAccelZ = 0.0;

  // Time-based fallback capture (even when stationary)
  int _stationaryFrameCount = 0;
  static const int _maxStationaryFramesBeforeCapture = 15; // Capture every ~2s even if still

  // Singleton
  static CameraScannerService? _instance;
  static CameraScannerService get instance {
    _instance ??= CameraScannerService._();
    return _instance!;
  }

  CameraScannerService._();

  /// Initialize camera with device capability detection
  Future<bool> initializeCamera() async {
    try {
      // Detect device capability
      await _detectDeviceCapability();
      
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint('📷 [CameraScanner] ❌ No cameras available');
        return false;
      }

      // Prefer back camera
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      
      debugPrint('📷 [CameraScanner] ✅ Camera initialized ($_deviceModel, $_arCapability)');
      
      return true;
    } catch (e) {
      debugPrint('📷 [CameraScanner] ❌ Init failed: $e');
      return false;
    }
  }

  /// Detect device capability for camera fallback mode
  Future<void> _detectDeviceCapability() async {
    try {
      if (Platform.isIOS) {
        _deviceModel = await _getIOSDeviceModel();
        
        // Check if device supports ARKit
        if (_deviceModel.contains('iPhone 7') ||
            _deviceModel.contains('iPhone 8') ||
            _deviceModel.contains('iPhone X') ||
            _deviceModel.contains('iPhone 1')) {
          _arCapability = 'ARKit';
          
          // Check for LiDAR
          if (_deviceModel.contains('Pro') && 
              (_deviceModel.contains('12') || _deviceModel.contains('13') ||
               _deviceModel.contains('14') || _deviceModel.contains('15'))) {
            _arCapability = 'LiDAR';
          }
        }
      } else if (Platform.isAndroid) {
        _deviceModel = await _getAndroidDeviceModel();
        _arCapability = 'ARCore'; // Assume ARCore for modern Android
      }
      
      debugPrint('📱 [CameraScanner] Device: $_deviceModel, Capability: $_arCapability');
    } catch (e) {
      debugPrint('⚠️ [CameraScanner] Device detection failed: $e');
      _deviceModel = 'Unknown';
      _arCapability = 'Camera';
    }
  }

  /// Get iOS device model
  Future<String> _getIOSDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.name} ${iosInfo.model}';
    } catch (e) {
      return 'iPhone';
    }
  }

  /// Get Android device model
  Future<String> _getAndroidDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } catch (e) {
      return 'Android';
    }
  }

  /// Get camera controller
  CameraController? get cameraController => _cameraController;

  /// Start scanning with sensor-based auto-capture
  Future<bool> startScanning() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('📷 [CameraScanner] ❌ Camera not initialized');
      return false;
    }

    if (_isScanning) {
      debugPrint('📷 [CameraScanner] ⚠️ Already scanning');
      return false;
    }

    try {
      _isScanning = true;
      // NOTE: Do NOT reset _sequenceNumber here!
      // The start point has already been captured with a sequence number.
      // Resetting would cause UNIQUE constraint violation in the backend.
      _lastCaptureTime = null;
      _lastSensorTime = null;

      // Reset position tracking (but NOT sequence number)
      _positionX = 0.0;
      _positionY = 0.0;
      _positionZ = 0.0;
      _velocityX = 0.0;
      _velocityY = 0.0;
      _velocityZ = 0.0;
      _rotationX = 0.0;
      _rotationY = 0.0;
      _rotationZ = 0.0;

      // Start listening to device sensors for real movement
      _startSensorListening();

      // Start auto-capture timer
      _startAutoCaptureTimer();

      debugPrint('📷 [CameraScanner] ✅ Scanning started with sensor-based tracking');

      return true;
    } catch (e) {
      debugPrint('📷 [CameraScanner] ❌ Failed to start scanning: $e');
      _isScanning = false;
      return false;
    }
  }

  /// Start listening to device sensors
  void _startSensorListening() {
    // Accelerometer — detects linear movement
    _accelerometerSubscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen(
      (UserAccelerometerEvent event) {
        // Apply low-pass filter to smooth raw sensor data
        // This eliminates jitter that causes jagged blue lines
        _filteredAccelX = _lpfAlpha * event.x + (1 - _lpfAlpha) * _filteredAccelX;
        _filteredAccelY = _lpfAlpha * event.y + (1 - _lpfAlpha) * _filteredAccelY;
        _filteredAccelZ = _lpfAlpha * event.z + (1 - _lpfAlpha) * _filteredAccelZ;

        // Use filtered values (not raw)
        _accelX = _filteredAccelX;
        _accelY = _filteredAccelY;
        _accelZ = _filteredAccelZ;

        // Calculate movement magnitude from filtered data
        _movementMagnitude = math.sqrt(
          _accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ,
        );

        _isDeviceMoving = _movementMagnitude > movementThreshold;

        // Update position estimate using dead reckoning (filtered)
        if (_isDeviceMoving && _lastSensorTime != null) {
          final now = DateTime.now();
          final dt = now.difference(_lastSensorTime!).inMicroseconds / 1000000.0;

          // Integrate filtered acceleration → velocity
          // NOTE: Android accelerometer reports REACTION force (opposite direction)
          // Negate X so RIGHT movement = positive X on screen
          _velocityX -= _accelX * dt;
          _velocityY += _accelY * dt;
          _velocityZ -= _accelZ * dt;

          // Apply velocity damping to prevent drift
          _velocityX *= 0.95;
          _velocityY *= 0.95;
          _velocityZ *= 0.95;

          // Integrate velocity → position
          _positionX += _velocityX * dt;
          _positionY += _velocityY * dt;
          _positionZ += _velocityZ * dt;
        }
      },
      onError: (error) {
        debugPrint('📷 [CameraScanner] ⚠️ Accelerometer error: $error');
      },
    );

    // Gyroscope — detects rotation
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen(
      (GyroscopeEvent event) {
        final now = DateTime.now();
        if (_lastSensorTime != null) {
          final dt = now.difference(_lastSensorTime!).inMicroseconds / 1000000.0;
          // Integrate angular velocity to get rotation
          _rotationX += event.x * dt;
          _rotationY += event.y * dt;
          _rotationZ += event.z * dt;
        }
        _lastSensorTime = now;
      },
      onError: (error) {
        debugPrint('📷 [CameraScanner] ⚠️ Gyroscope error: $error');
      },
    );

    debugPrint('📷 [CameraScanner] 📡 Sensor listeners started');
  }

  /// Stop sensor listeners
  void _stopSensorListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    debugPrint('📷 [CameraScanner] 📡 Sensor listeners stopped');
  }

  /// Start auto-capture timer for continuous scanning
  void _startAutoCaptureTimer() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = Timer.periodic(
      Duration(milliseconds: autoCaptureIntervalMs),
      (timer) {
        if (_isScanning && _cameraController != null) {
          _captureAutomaticPoint();
        }
      },
    );
  }

  /// Capture automatic point based on REAL sensor data
  /// Captures when moving (primary) OR after timeout (fallback for slow scans)
  Future<void> _captureAutomaticPoint() async {
    if (!_isScanning || _cameraController == null) return;

    try {
      // Throttle captures
      if (_lastCaptureTime != null) {
        final elapsed = DateTime.now().difference(_lastCaptureTime!);
        if (elapsed.inMilliseconds < autoCaptureIntervalMs) return;
      }

      // Primary: capture when device is moving
      // Fallback: capture every ~2 seconds even if stationary (for slow scans)
      if (!_isDeviceMoving) {
        _stationaryFrameCount++;
        if (_stationaryFrameCount < _maxStationaryFramesBeforeCapture) {
          return; // Not moving AND haven't waited long enough
        }
        _stationaryFrameCount = 0; // Reset counter, force-capture below
      } else {
        _stationaryFrameCount = 0;
      }

      // Calculate 3D position from sensor data
      // Use device orientation (gyro) to project forward from camera
      final forwardX = math.sin(_rotationY) * defaultDepth;
      final forwardY = math.sin(_rotationX) * defaultDepth;
      final forwardZ = math.cos(_rotationY) * defaultDepth;

      // Combine sensor-estimated position with projected forward direction
      final x = _positionX + forwardX;
      final y = _positionY + forwardY;
      final z = _positionZ + forwardZ;

      // Calculate confidence based on movement stability
      final confidence = _calculateConfidence();

      final point = ScanPoint.fromARFrame(
        x: x,
        y: y,
        z: z,
        sequenceNumber: _sequenceNumber++,
        isManualPin: false,
        confidence: confidence,
      );

      // Only keep if far enough from last point (or first point)
      if (_capturedPoints.isEmpty || _shouldCapturePoint(point)) {
        _capturedPoints.add(point);
        _pointStreamController?.add(point);
        _lastCaptureTime = DateTime.now();
        _emitStatistics();
        debugPrint('📷 [CameraScanner] 📍 Point #${_capturedPoints.length} captured at (${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})');
      }
    } catch (e) {
      debugPrint('📷 [CameraScanner] ❌ Error auto-capturing point: $e');
    }
  }

  /// Calculate confidence score based on sensor quality
  double _calculateConfidence() {
    // Higher movement = lower confidence (hand shake)
    // Moderate movement = higher confidence (smooth pan)
    if (_movementMagnitude < 0.1) return 0.5; // Too still (noise)
    if (_movementMagnitude < 0.5) return 0.7; // Smooth movement
    if (_movementMagnitude < 1.5) return 0.6; // Moderate movement
    return 0.4; // Fast/shaky movement
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    _isScanning = false;
    _autoCaptureTimer?.cancel();
    _stopSensorListening();
    debugPrint('📷 [CameraScanner] 🛑 Scanning stopped. Total points: ${_capturedPoints.length}');
  }

  /// Capture manual pin point
  Future<ScanPoint?> captureManualPin(Offset screenPosition, Size screenSize) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('📷 [CameraScanner] ❌ Camera not initialized');
      return null;
    }

    try {
      // Convert screen position to normalized coordinates (-1 to 1)
      final normalizedX = (screenPosition.dx / screenSize.width) * 2 - 1;
      final normalizedY = (screenPosition.dy / screenSize.height) * 2 - 1;

      // Use current sensor-estimated depth
      final depth = defaultDepth;

      // Calculate 3D position using screen position + depth
      final x = normalizedX * depth + _positionX;
      final y = -normalizedY * depth + _positionY;
      final z = depth + _positionZ;

      final point = ScanPoint.fromARFrame(
        x: x,
        y: y,
        z: z,
        sequenceNumber: _sequenceNumber++,
        isManualPin: true,
        confidence: 0.7,
      );

      _capturedPoints.add(point);
      _pointStreamController?.add(point);

      debugPrint('📷 [CameraScanner] 📍 Manual pin captured: '
          '(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)}) '
          'seq: ${point.sequenceNumber}');

      return point;
    } catch (e) {
      debugPrint('📷 [CameraScanner] ❌ Error capturing manual pin: $e');
      return null;
    }
  }

  /// Auto-capture point (DEPRECATED — kept for backward compatibility)
  Future<ScanPoint?> autoCapturePoint(Offset currentPosition, Size screenSize) async {
    return null;
  }

  /// Check if point should be captured based on distance
  bool _shouldCapturePoint(ScanPoint point) {
    if (_capturedPoints.isNotEmpty) {
      final lastPoint = _capturedPoints.last;
      final distance = point.distanceTo(lastPoint);
      if (distance < minPointDistance) {
        return false;
      }
    }
    return true;
  }

  /// Emit statistics
  void _emitStatistics() {
    if (_statsStreamController == null || _statsStreamController!.isClosed) return;

    _statsStreamController!.add({
      'pointCount': _capturedPoints.length,
      'isScanning': _isScanning,
      'sequenceNumber': _sequenceNumber,
      'isMoving': _isDeviceMoving,
      'movementMagnitude': _movementMagnitude,
      'positionX': _positionX,
      'positionY': _positionY,
      'positionZ': _positionZ,
    });
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

  /// Clear all points (only called when starting a brand new scan)
  void clearPoints() {
    _capturedPoints.clear();
    _sequenceNumber = 0;
    _positionX = 0.0;
    _positionY = 0.0;
    _positionZ = 0.0;
    debugPrint('📷 [CameraScanner] 🗑️ All points cleared');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isScanning = false;
    _autoCaptureTimer?.cancel();
    _stopSensorListening();
    _pointStreamController?.close();
    _statsStreamController?.close();
    _capturedPoints.clear();
    await _cameraController?.dispose();
    debugPrint('📷 [CameraScanner] 🧹 Service disposed');
  }
}
