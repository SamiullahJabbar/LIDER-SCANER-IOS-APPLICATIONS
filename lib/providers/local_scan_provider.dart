// ============================================================================
// PRODUCTION-READY Local Scan Provider
// State management for scanning — fully offline, NO backend API calls
//
// Manages:
//   • Scan session lifecycle (create → scan → complete)
//   • Real-time quality tracking during scan
//   • Point capture from ARKit/Camera services
//   • Local storage persistence
//   • Export queue for deferred upload
//   • Scan history with search/filter
// ============================================================================
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/scan_point_model.dart';
import '../services/local_scan_storage_service.dart';
import '../services/scan_quality_analyzer.dart';
import '../services/device_detection_service.dart';

class LocalScanProvider with ChangeNotifier {
  final LocalScanStorageService _storage = LocalScanStorageService.instance;
  final DeviceDetectionService _deviceDetection = DeviceDetectionService.instance;

  // ── Current scan session ────────────────────────────────────────────────
  ScanSession? _currentSession;
  final List<ScanPoint> _capturedPoints = [];
  final ScanQualityTracker _qualityTracker = ScanQualityTracker();

  // ── Scanning state ──────────────────────────────────────────────────────
  bool _isScanning = false;
  bool _isInitialized = false;
  bool _isSaving = false;
  DateTime? _scanStartTime;

  // ── Scan history ────────────────────────────────────────────────────────
  List<ScanSession> _scanHistory = [];
  bool _isLoadingHistory = false;
  String _historyFilter = 'all'; // all, completed, exported
  String _searchQuery = '';

  // ── Device info ─────────────────────────────────────────────────────────
  DeviceCapability? _deviceCapability;
  String _deviceModel = 'Unknown';

  // ── Error state ─────────────────────────────────────────────────────────
  String? _errorMessage;

  // ── Storage stats ───────────────────────────────────────────────────────
  Map<String, dynamic> _storageStats = {};

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  ScanSession? get currentSession => _currentSession;
  List<ScanPoint> get capturedPoints => List.unmodifiable(_capturedPoints);
  int get pointCount => _capturedPoints.length;
  int get manualPinCount => _capturedPoints.where((p) => p.isManualPin).length;
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  DeviceCapability? get deviceCapability => _deviceCapability;
  String get deviceModel => _deviceModel;

  // Real-time quality
  ScanQualityTracker get qualityTracker => _qualityTracker;
  double get liveCoverage => _qualityTracker.liveCoveragePercent;
  double get liveStability => _qualityTracker.liveStabilityScore;
  int get outlierCount => _qualityTracker.outlierCount;

  // History
  List<ScanSession> get scanHistory => List.unmodifiable(_scanHistory);
  bool get isLoadingHistory => _isLoadingHistory;
  String get historyFilter => _historyFilter;
  String get searchQuery => _searchQuery;
  Map<String, dynamic> get storageStats => Map.unmodifiable(_storageStats);

  // Scan duration (live)
  int get scanDurationSeconds {
    if (_scanStartTime == null) return 0;
    return DateTime.now().difference(_scanStartTime!).inSeconds;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the provider — call once at app startup
  Future<void> initialize() async {
    try {
      _errorMessage = null;

      // Initialize storage
      await _storage.initialize();

      // Detect device
      _deviceCapability = await _deviceDetection.detectDeviceCapability();
      _deviceModel = await _deviceDetection.getDeviceModel();

      // Load history
      await loadScanHistory();

      // Load storage stats
      await refreshStorageStats();

      _isInitialized = true;
      debugPrint('✅ [LocalScanProvider] Initialized — ${_scanHistory.length} scans on device');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Initialization failed: $e';
      debugPrint('❌ [LocalScanProvider] $_errorMessage');
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCAN SESSION LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new scan session — call when user taps "Start Scan"
  Future<ScanSession?> createScanSession({
    required String name,
    String? roomType,
  }) async {
    try {
      _errorMessage = null;

      if (!_isInitialized) await initialize();

      final session = await _storage.createSession(
        id: const Uuid().v4(),
        name: name,
        roomType: roomType,
        deviceType: _deviceCapability?.backendValue ?? 'UNKNOWN',
        deviceModel: _deviceModel,
      );

      _currentSession = session;
      _capturedPoints.clear();
      _qualityTracker.reset();
      _scanStartTime = null;

      debugPrint('✅ [LocalScanProvider] Session created: ${session.id}');
      notifyListeners();
      return session;
    } catch (e) {
      _errorMessage = 'Failed to create session: $e';
      debugPrint('❌ [LocalScanProvider] $_errorMessage');
      notifyListeners();
      return null;
    }
  }

  /// Start scanning
  void startScanning() {
    _isScanning = true;
    _scanStartTime = DateTime.now();
    _errorMessage = null;
    notifyListeners();
  }

  /// Stop scanning
  void stopScanning() {
    _isScanning = false;
    notifyListeners();
  }

  /// Add a captured point (from ARKit/Camera service) — call during live scan
  void addPoint(ScanPoint point) {
    _capturedPoints.add(point);
    _qualityTracker.addPoint(point);
    // Notify every 5 points to reduce UI rebuild frequency
    if (_capturedPoints.length % 5 == 0 || point.isManualPin) {
      notifyListeners();
    }
  }

  /// Complete scan session — saves everything to local storage
  Future<ScanSession?> completeScanSession({
    Map<String, dynamic>? extraMetadata,
  }) async {
    if (_currentSession == null) {
      _errorMessage = 'No active session';
      notifyListeners();
      return null;
    }

    try {
      _isSaving = true;
      _errorMessage = null;
      notifyListeners();

      final duration = scanDurationSeconds;
      final quality = _qualityTracker.getCurrentQuality();

      final completed = await _storage.completeSession(
        sessionId: _currentSession!.id,
        points: _capturedPoints,
        qualityScore: quality.overallScore,
        coveragePercent: quality.coveragePercent,
        stabilityScore: quality.stabilityScore,
        durationSeconds: duration,
        segments: quality.segments,
        extraMetadata: {
          'pointDensityPerM3': quality.pointDensityPerM3,
          'grade': quality.grade,
          'outlierCount': quality.outlierCount,
          'roomType': _currentSession!.roomType,
          ...?extraMetadata,
        },
      );

      _currentSession = completed;

      // Reload history
      await loadScanHistory();
      await refreshStorageStats();

      debugPrint('✅ [LocalScanProvider] Scan completed: ${completed.id} '
          '— ${completed.pointCount} pts, quality: ${quality.grade}');

      return completed;
    } catch (e) {
      _errorMessage = 'Failed to save scan: $e';
      debugPrint('❌ [LocalScanProvider] $_errorMessage');
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Discard current scan session
  Future<void> discardCurrentSession() async {
    if (_currentSession != null) {
      await _storage.deleteSession(_currentSession!.id);
    }
    _currentSession = null;
    _capturedPoints.clear();
    _qualityTracker.reset();
    _isScanning = false;
    _scanStartTime = null;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCAN HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  /// Load scan history from local storage
  Future<void> loadScanHistory() async {
    try {
      _isLoadingHistory = true;
      notifyListeners();

      ScanStatus? filterStatus;
      if (_historyFilter == 'completed') filterStatus = ScanStatus.completed;
      if (_historyFilter == 'exported') filterStatus = ScanStatus.exported;

      _scanHistory = await _storage.getAllSessions(
        filterStatus: filterStatus,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    } catch (e) {
      debugPrint('❌ [LocalScanProvider] Load history failed: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Set history filter and reload
  Future<void> setHistoryFilter(String filter) async {
    _historyFilter = filter;
    await loadScanHistory();
  }

  /// Set search query and reload
  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    await loadScanHistory();
  }

  /// Get a specific scan session
  Future<ScanSession?> getSession(String id) async {
    return _storage.getSession(id);
  }

  /// Load points for a session (from encrypted file)
  Future<List<ScanPoint>> loadSessionPoints(String sessionId) async {
    final session = await _storage.getSession(sessionId);
    if (session?.filePath == null) return [];
    return _storage.loadPointCloud(session!.filePath!);
  }

  /// Delete a scan session
  Future<void> deleteSession(String id) async {
    try {
      await _storage.deleteSession(id);
      _scanHistory.removeWhere((s) => s.id == id);
      if (_currentSession?.id == id) {
        _currentSession = null;
        _capturedPoints.clear();
      }
      await refreshStorageStats();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Delete failed: $e';
      notifyListeners();
    }
  }

  /// Rename a scan session
  Future<void> renameSession(String id, String newName) async {
    try {
      await _storage.renameSession(id, newName);
      await loadScanHistory();
    } catch (e) {
      _errorMessage = 'Rename failed: $e';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPORT QUEUE
  // ══════════════════════════════════════════════════════════════════════════

  /// Add scan to export queue (for deferred upload when network is available)
  Future<void> queueForExport(String scanId, {String format = 'obj'}) async {
    try {
      await _storage.addToExportQueue(scanId, format: format);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to queue export: $e';
      notifyListeners();
    }
  }

  /// Get pending export count
  Future<int> getPendingExportCount() async {
    final pending = await _storage.getPendingExports();
    return pending.length;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STORAGE STATS
  // ══════════════════════════════════════════════════════════════════════════

  /// Refresh storage statistics
  Future<void> refreshStorageStats() async {
    try {
      _storageStats = await _storage.getStorageStats();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [LocalScanProvider] Stats refresh failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Full reset
  void reset() {
    _currentSession = null;
    _capturedPoints.clear();
    _qualityTracker.reset();
    _isScanning = false;
    _isSaving = false;
    _scanStartTime = null;
    _errorMessage = null;
    notifyListeners();
  }
}
