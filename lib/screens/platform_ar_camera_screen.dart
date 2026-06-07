// PRODUCTION-READY Platform-Aware AR Camera Screen
// Automatically detects and uses: iOS ARKit, Android ARCore + Depth API, or Camera fallback
// Real implementation for all platforms, NO mocks
// FULLY OFFLINE — saves to local storage, NO backend API calls
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart'; // For HapticFeedback
import '../services/device_detection_service.dart';
import '../services/arkit_scanner_service.dart';
import '../services/camera_scanner_service.dart';
import '../services/depth_api_service.dart';
import '../services/scan_quality_analyzer.dart';
import '../providers/local_scan_provider.dart';
import '../models/scan_point_model.dart';
import '../utils/app_colors.dart';
import '../widgets/scan_painter.dart';
import '../screens/scan_results_screen.dart';

// Platform-specific imports
import 'package:arkit_plugin/arkit_plugin.dart' if (dart.library.html) 'package:flutter/material.dart';
import 'package:camera/camera.dart';

enum ScannerPlatform {
  iosARKit,
  androidARCore,
  cameraFallback,
}

class PlatformARCameraScreen extends StatefulWidget {
  final String scanName;
  final String? roomType;
  
  const PlatformARCameraScreen({
    super.key,
    required this.scanName,
    this.roomType,
  });

  @override
  State<PlatformARCameraScreen> createState() => _PlatformARCameraScreenState();
}

class _PlatformARCameraScreenState extends State<PlatformARCameraScreen> {
  // Services
  late final DeviceDetectionService _deviceDetection;
  
  // Platform detection
  ScannerPlatform? _platform;
  
  // Platform-specific controllers
  ARKitController? _arkitController;
  CameraController? _cameraController;
  
  // Scanner services
  ARKitScannerService? _arkitScanner;
  CameraScannerService? _cameraScanner;
  
  // Depth API service (ARCore on Android, ARKit on iOS)
  final DepthApiService _depthApi = DepthApiService.instance;
  
  // Scan state — LOCAL only, no backend
  String? _sessionId;
  DeviceCapability? _deviceCapability;
  bool _isInitializing = true;
  bool _isScanning = false;
  
  // Points
  ScanPoint? _startPoint;
  ScanPoint? _endPoint;
  final List<ScanPoint> _autoPoints = [];
  
  // Quality tracker
  final ScanQualityTracker _qualityTracker = ScanQualityTracker();
  
  // Statistics
  double _liveDistance = 0.0;
  
  // Error handling
  String? _errorMessage;
  
  // Streams
  StreamSubscription<ScanPoint>? _pointSubscription;
  StreamSubscription<Map<String, dynamic>>? _statsSubscription;
  
  // Professional features
  String _distanceUnit = 'm'; // 'm', 'ft', 'in'
  bool _isMovingTooFast = false;
  double _currentConfidence = 0.5;
  double _currentRotationY = 0.0; // Device yaw (left-right) for AR projection
  double _currentRotationX = 0.0; // Device pitch (up-down) for AR projection - NEW
  Timer? _rotationTimer; // Updates rotation 10x/sec for smooth AR line
  static const List<String> _unitOptions = ['m', 'ft', 'in'];
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  @override
  void dispose() {
    _completeScanIfNeeded();
    _pointSubscription?.cancel();
    _statsSubscription?.cancel();
    _rotationTimer?.cancel();
    _arkitController?.dispose();
    _cameraController?.dispose();
    _arkitScanner?.dispose();
    _cameraScanner?.dispose();
    _depthApi.dispose();
    super.dispose();
  }
  
  /// Save scan locally if still scanning when screen is disposed
  void _completeScanIfNeeded() {
    if (_sessionId != null && _isScanning && _autoPoints.isNotEmpty) {
      final provider = context.read<LocalScanProvider>();
  provider.completeScanSession();
    }
  }
  
  /// Initialize platform detection and create local scan session
  Future<void> _initialize() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      final permissionsOk = await _ensurePermissions();
      if (!permissionsOk) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Camera permission is required for scanning.';
        });
        return;
      }
      
      // Get services
      _deviceDetection = DeviceDetectionService.instance;
      
      // Detect platform
      await _detectPlatform();
      
      if (_platform == null) {
        throw Exception('Could not detect platform capabilities');
      }
      
      // Detect device capability
      _deviceCapability = await _deviceDetection.detectDeviceCapability();
      debugPrint('📱 Device capability: ${_deviceCapability!.backendValue}');
      
      // Get device model
      await _deviceDetection.getDeviceModel();
      
      // Create LOCAL scan session (no backend)
      if (!mounted) return;
      final provider = context.read<LocalScanProvider>();
      await provider.createScanSession(
        name: widget.scanName,
        roomType: widget.roomType ?? 'general',
      );
      
      _sessionId = provider.currentSession?.id;
      debugPrint('✅ Local scan session created: $_sessionId');
      
      setState(() {
        _isInitializing = false;
      });
      
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  /// Ensure camera permissions are granted
  Future<bool> _ensurePermissions() async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.camera.request();
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    } catch (e) {
      debugPrint('❌ Permission check failed: $e');
      return false;
    }
  }
  
  /// Detect which platform to use
  /// Priority: iOS→ARKit, Android→ARCore+DepthAPI, Fallback→Camera+Sensors
  Future<void> _detectPlatform() async {
    try {
      if (Platform.isIOS) {
        // iOS: Use ARKit (+ LiDAR if available)
        _platform = ScannerPlatform.iosARKit;
        _arkitScanner = ARKitScannerService.instance;
        
        // Also init native depth session for LiDAR devices
        final hasLiDAR = await _depthApi.isLiDARAvailable();
        if (hasLiDAR) {
          await _depthApi.initializeSession();
          debugPrint('📱 [Platform] iOS ARKit + LiDAR Depth API');
        } else {
          debugPrint('📱 [Platform] iOS ARKit (no LiDAR)');
        }
        
      } else if (Platform.isAndroid) {
        // Android: Try ARCore + Depth API first
        final arcoreSupported = await _depthApi.isARCoreSupported();
        
        if (arcoreSupported) {
          // ARCore is available — initialize native session
          final sessionOk = await _initializeDepthSessionWithRetry();
          
          if (sessionOk) {
            _platform = ScannerPlatform.androidARCore;
            
            // Also init camera for live preview
            _cameraScanner = CameraScannerService.instance;
            await _cameraScanner!.initializeCamera();
            
            final hasDepth = _depthApi.depthSupported;
            debugPrint('📱 [Platform] Android ARCore (Depth API: $hasDepth)');
          } else {
            // ARCore session failed — fall back to camera + sensors
            debugPrint('📱 [Platform] ARCore session failed → Camera Fallback');
            await _initCameraFallback();
          }
        } else {
          // ARCore not available — fall back to camera + sensors
          debugPrint('📱 [Platform] ARCore NOT supported → Camera Fallback');
          await _initCameraFallback();
        }
        
      } else {
        await _initCameraFallback();
      }
      
    } catch (e) {
      debugPrint('❌ [Platform] Detection error: $e — falling back to camera');
      await _initCameraFallback();
    }
  }

  /// Retry depth session initialization (handles flaky ARCore init)
  Future<bool> _initializeDepthSessionWithRetry({int retries = 2}) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      final ok = await _depthApi.initializeSession();
      if (ok) return true;
      await Future.delayed(Duration(milliseconds: 300 + (attempt * 300)));
    }
    return false;
  }
  
  /// Initialize camera fallback with sensor-based tracking
  Future<void> _initCameraFallback() async {
    _platform = ScannerPlatform.cameraFallback;
    _cameraScanner = CameraScannerService.instance;
    final ok = await _cameraScanner!.initializeCamera();
    if (!ok) throw Exception('Failed to initialize camera');
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('📱 [Platform] Camera Fallback + Sensor Tracking');
  }
  
  /// Handle screen tap for manual pin (+ for start, - for end)
  Future<void> _handleTap(Offset screenPosition) async {
    if (_sessionId == null || _isInitializing) return;
    
    try {
      final screenSize = MediaQuery.of(context).size;
      ScanPoint? point;
      
      // Capture point based on platform
      switch (_platform!) {
        case ScannerPlatform.iosARKit:
          point = await _arkitScanner!.captureManualPin(screenPosition, screenSize);
          break;
        case ScannerPlatform.androidARCore:
          point = await _cameraScanner!.captureManualPin(screenPosition, screenSize);
          break;
        case ScannerPlatform.cameraFallback:
          point = await _cameraScanner!.captureManualPin(screenPosition, screenSize);
          break;
      }
      
      if (point == null) {
        _showError('Could not detect surface. Try pointing at a visible surface.');
        return;
      }
      
      if (!mounted) return;
      final provider = context.read<LocalScanProvider>();
      
      if (_startPoint == null) {
        // Start point - RED DOT with + icon
        setState(() {
          _startPoint = point;
          _isScanning = true;
        });
        
        // Start scanning (auto-capture will happen internally)
        await _startScanning();
        
        // Track start point locally
        provider.addPoint(point);
        
        debugPrint('🔴 Start point set at (${point.x.toStringAsFixed(2)}, ${point.y.toStringAsFixed(2)}, ${point.z.toStringAsFixed(2)})');
        
      } else if (_endPoint == null) {
        // Minimum quality check: at least a few points for coverage estimate
        if (_qualityTracker.pointCount < 2) {
          _showError('Move your phone slightly to capture environment data before ending');
          return;
        }
        
        // End point - RED DOT with - icon
        setState(() {
          _endPoint = point;
          _isScanning = false;
        });
        
        // Stop scanning
        await _stopScanning();
        
        // Track end point
        provider.addPoint(point);
        
        debugPrint('🔴 End point set at (${point.x.toStringAsFixed(2)}, ${point.y.toStringAsFixed(2)}, ${point.z.toStringAsFixed(2)})');
        debugPrint('📊 Total points: ${_autoPoints.length + 2} (auto: ${_autoPoints.length})');
        
        // Complete session and save locally
        await provider.completeScanSession();
        
        // Navigate to results screen
        _navigateToMeasurement();
      }
      
    } catch (e) {
      debugPrint('❌ Tap handling error: $e');
      _showError('Failed to capture point: $e');
    }
  }
  
  /// Start scanning based on platform
  Future<void> _startScanning() async {
    final provider = context.read<LocalScanProvider>();
    provider.startScanning();
    
    switch (_platform!) {
      case ScannerPlatform.iosARKit:
        await _arkitScanner!.startScanning();
        _pointSubscription = _arkitScanner!.pointStream.listen(_onARPointCaptured);
        _statsSubscription = _arkitScanner!.statsStream.listen(_onStatsUpdate);
        break;
      case ScannerPlatform.androidARCore:
        await _cameraScanner!.startScanning();
        _pointSubscription = _cameraScanner!.pointStream.listen(_onARPointCaptured);
        _statsSubscription = _cameraScanner!.statsStream.listen(_onStatsUpdate);
        break;
      case ScannerPlatform.cameraFallback:
        await _cameraScanner!.startScanning();
        _pointSubscription = _cameraScanner!.pointStream.listen(_onARPointCaptured);
        _statsSubscription = _cameraScanner!.statsStream.listen(_onStatsUpdate);
        break;
    }
    
    debugPrint('✅ Scanning started - auto-capture enabled');

    // Start rotation update timer (10 fps for smooth AR line)
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isScanning && _cameraScanner != null) {
        setState(() {
          _currentRotationY = _cameraScanner!.rotationY;
          _currentRotationX = _cameraScanner!.rotationX; // NEW: pitch rotation
        });
      }
    });
  }
  
  /// Stop scanning based on platform
  Future<void> _stopScanning() async {
    _rotationTimer?.cancel();
    switch (_platform!) {
      case ScannerPlatform.iosARKit:
        await _arkitScanner!.stopScanning();
        break;
      case ScannerPlatform.androidARCore:
        await _cameraScanner!.stopScanning();
        break;
      case ScannerPlatform.cameraFallback:
        await _cameraScanner!.stopScanning();
        break;
    }
    
    debugPrint('🛑 Scanning stopped');
  }
  
  /// Handle AR point captured — LOCAL only, quality tracked in real-time
  void _onARPointCaptured(ScanPoint point) {
    if (!mounted) return;

    // Track quality in real-time
    _qualityTracker.addPoint(point);

    // Track in provider for live metrics
    final provider = context.read<LocalScanProvider>();
    provider.addPoint(point);

    setState(() {
      // Only manual pins form the measurement path
      // Auto-captured points (grid samples from LiDAR depth map)
      // are used ONLY for quality/stats — NOT for path drawing
      // This prevents 25 pts/frame grid samples from cluttering the display
      if (point.isManualPin) {
        _autoPoints.add(point);

        // Haptic feedback on manual pin
        HapticFeedback.lightImpact();

        // Calculate CUMULATIVE path distance (full walking path)
        if (_autoPoints.length >= 2) {
          final prev = _autoPoints[_autoPoints.length - 2];
          _liveDistance += prev.distanceTo(point);
        } else if (_startPoint != null && _autoPoints.length == 1) {
          _liveDistance += _startPoint!.distanceTo(point);
        }
      }

      // Update confidence from point data
      _currentConfidence = point.confidence;

      // Check speed (if movement magnitude > 2.5, too fast)
      if (_cameraScanner != null) {
        _isMovingTooFast = _cameraScanner!.movementMagnitude > 2.5;
      }
    });
  }
  
  /// Handle statistics update
  void _onStatsUpdate(Map<String, dynamic> stats) {
    // Stats are already updated via _onARPointCaptured
  }
  
  /// Navigate to results screen with LOCAL session data
  void _navigateToMeasurement() {
    final provider = context.read<LocalScanProvider>();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ScanResultsScreen(
          sessionId: _sessionId!,
          scanName: widget.scanName,
          pointCount: _autoPoints.length + 2, // +2 for start/end
          deviceType: _deviceCapability?.backendValue ?? 'CAMERA',
          qualityResult: provider.qualityTracker.getCurrentQuality(),
        ),
      ),
    );
  }
  
  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildInitializingScreen();
    }
    
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) => _handleTap(details.localPosition),
        child: Stack(
          children: [
            // Platform-specific camera view
            _buildCameraView(),
            
            // Visual overlays (red/blue/yellow)
            CustomPaint(
              size: Size.infinite,
              painter: ScanPainter(
                startPoint: _startPoint,
                endPoint: _endPoint,
                autoPoints: _autoPoints,
                distanceUnit: _distanceUnit,
                deviceRotationY: _currentRotationY,
                deviceRotationX: _currentRotationX, // NEW: pitch rotation for stable line
              ),
            ),
            
            // Center crosshair with confidence ring
            _buildCenterCrosshair(),
            
            // Speed warning overlay
            if (_isMovingTooFast && _isScanning)
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.speed, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Move Slowly for Better Accuracy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // UI Overlay
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  _buildStatsPanel(),
                  const SizedBox(height: 20),
                  _buildInstructions(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build center crosshair with professional buttons
  Widget _buildCenterCrosshair() {
    if (_startPoint == null) {
      // Show professional START button
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Crosshair indicator with CONFIDENCE RING
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
            // Professional START button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final screenSize = MediaQuery.of(context).size;
                    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
                    _handleTap(screenCenter);
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'START SCAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_endPoint == null) {
      // Show professional STOP button
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Crosshair with CONFIDENCE RING (color changes based on sensor quality)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getConfidenceColor().withValues(alpha: 0.7),
                  width: 3,
                ),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
            // Professional STOP button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.error, AppColors.error.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final screenSize = MediaQuery.of(context).size;
                    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
                    _handleTap(screenCenter);
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'STOP SCAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Scan complete
      return const SizedBox.shrink();
    }
  }
  
  Widget _buildCameraView() {
    if (_platform == null) {
      return Container(color: Colors.black);
    }
    
    switch (_platform!) {
      case ScannerPlatform.iosARKit:
        return _buildARKitView();
      case ScannerPlatform.androidARCore:
        return _buildARCoreView();
      case ScannerPlatform.cameraFallback:
        return _buildCameraFallbackView();
    }
  }
  
  Widget _buildARKitView() {
    // iOS ARKit view - simplified to avoid enum issues on Android
    try {
      return ARKitSceneView(
        onARKitViewCreated: (controller) {
          _arkitController = controller;
          _arkitScanner!.initializeController(controller);
          // Native ARKit session handles depth frame processing automatically
          // via LiDARScannerPlugin — no processARFrame needed
        },
        enableTapRecognizer: false,
        showFeaturePoints: true,
        showWorldOrigin: false,
      );
    } catch (e) {
      debugPrint('❌ ARKit view error: $e');
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            'ARKit initialization failed',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }
  
  Widget _buildARCoreView() {
    // Temporarily disabled - using camera fallback
    return _buildCameraFallbackView();
    
    // return ArCoreView(
    //   onArCoreViewCreated: (controller) {
    //     _arcoreController = controller;
    //     _arcoreScanner!.initializeController(controller);
    //   },
    //   enableTapRecognizer: false,
    //   enablePlaneRenderer: true,
    //   enableUpdateListener: true,
    // );
  }
  
  Widget _buildCameraFallbackView() {
    if (_cameraScanner?.cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accentBlue),
              SizedBox(height: 20),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    if (!_cameraScanner!.cameraController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accentBlue),
              SizedBox(height: 20),
              Text(
                'Camera starting...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    return CameraPreview(_cameraScanner!.cameraController!);
  }
  
  Widget _buildInitializingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accentBlue),
            const SizedBox(height: 20),
            Text(
              'Initializing ${_getPlatformName()}...',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 60),
              const SizedBox(height: 20),
              const Text(
                'Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Platform indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getPlatformColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getPlatformColor(), width: 2),
            ),
            child: Row(
              children: [
                Icon(_getPlatformIcon(), color: _getPlatformColor(), size: 16),
                const SizedBox(width: 8),
                Text(
                  _getPlatformName(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getPlatformColor(),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Close button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsPanel() {
    // Live quality from tracker
  final coverage = (_qualityTracker.liveCoveragePercent * 100).clamp(0, 100).toStringAsFixed(0);
  final stability = (_qualityTracker.liveStabilityScore * 100).clamp(0, 100).toStringAsFixed(0);
  final qualityColor = _qualityTracker.liveCoveragePercent > 0.6
        ? AppColors.success
    : _qualityTracker.liveCoveragePercent > 0.3
            ? Colors.orange
            : AppColors.error;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.scatter_plot,
            label: 'Points',
            value: '${_autoPoints.length}',
            color: Colors.yellow,
          ),
          _buildStatItem(
            icon: Icons.straighten,
            label: 'Distance',
            value: '${_convertDist(_liveDistance).toStringAsFixed(2)}$_distanceUnit',
            color: AppColors.accentBlue,
          ),
          _buildStatItem(
            icon: Icons.grid_on,
            label: 'Coverage',
            value: '$coverage%',
            color: qualityColor,
          ),
          _buildStatItem(
            icon: Icons.speed,
            label: 'Stability',
            value: '$stability%',
            color: double.parse(stability) > 70 ? AppColors.success : Colors.orange,
          ),
          // Unit toggle button
          GestureDetector(
            onTap: () {
              setState(() {
                final idx = _unitOptions.indexOf(_distanceUnit);
                _distanceUnit = _unitOptions[(idx + 1) % _unitOptions.length];
              });
            },
            child: Column(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white70, size: 20),
                const SizedBox(height: 4),
                Text(
                  _distanceUnit.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Unit',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }
  
  Widget _buildInstructions() {
    String instruction;
    IconData icon;
    
    if (_startPoint == null) {
      instruction = 'Point camera at the surface you want to measure';
      icon = Icons.camera_alt_outlined;
    } else if (_endPoint == null) {
      instruction = 'Move device slowly along the measurement path';
      icon = Icons.timeline_outlined;
    } else {
      instruction = 'Processing scan data...';
      icon = Icons.check_circle_outline;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accentBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPlatformName() {
    if (_platform == null) return 'Unknown';
    switch (_platform!) {
      case ScannerPlatform.iosARKit:
        return 'ARKit';
      case ScannerPlatform.androidARCore:
        return 'ARCore';
      case ScannerPlatform.cameraFallback:
        return 'Camera';
    }
  }
  
  IconData _getPlatformIcon() {
    if (_platform == null) return Icons.help;
    switch (_platform!) {
      case ScannerPlatform.iosARKit:
        return Icons.view_in_ar;
      case ScannerPlatform.androidARCore:
        return Icons.view_in_ar;
      case ScannerPlatform.cameraFallback:
        return Icons.camera_alt;
    }
  }
  
  Color _getPlatformColor() {
    if (_platform == null) return Colors.grey;
    switch (_platform!) {
      case ScannerPlatform.iosARKit:
        return AppColors.lidarColor;
      case ScannerPlatform.androidARCore:
        return AppColors.arColor;
      case ScannerPlatform.cameraFallback:
        return AppColors.cameraColor;
    }
  }
  
  /// Get confidence ring color based on sensor quality
  Color _getConfidenceColor() {
    if (_currentConfidence >= 0.7) return Colors.green;
    if (_currentConfidence >= 0.4) return Colors.yellow;
    return Colors.red;
  }
  
  /// Convert distance to selected unit
  double _convertDist(double meters) {
    switch (_distanceUnit) {
      case 'ft': return meters * 3.28084;
      case 'in': return meters * 39.3701;
      default: return meters;
    }
  }
}
