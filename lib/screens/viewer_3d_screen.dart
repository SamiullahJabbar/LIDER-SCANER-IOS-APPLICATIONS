// ============================================================================
// PRODUCTION-READY 3D Viewer Screen
// Interactive 3D point cloud viewer for scanned data
//
// Features:
//   • Real point cloud rendering from scan data (CustomPainter)
//   • Multi-touch rotation + pinch zoom
//   • Color modes: confidence, height, uniform
//   • Grid, axes, bounding box toggles
//   • Measurement overlay with real bounding dimensions
//   • Export/Share (OBJ, PLY, CSV) via share_plus
//   • Auto-rotate toggle
//
// Uses actual scan point cloud data — NO hardcoded models
// ============================================================================
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/local_scan_storage_service.dart';
import '../services/scan_export_service.dart';
import '../models/scan_point_model.dart';
import '../widgets/point_cloud_viewer.dart';

class Viewer3DScreen extends StatefulWidget {
  const Viewer3DScreen({super.key});

  @override
  State<Viewer3DScreen> createState() => _Viewer3DScreenState();
}

class _Viewer3DScreenState extends State<Viewer3DScreen> {
  final bool _showControls = true;
  bool _showMeasurements = false;
  bool _autoRotate = true;
  bool _showGrid = true;
  bool _showAxes = true;
  bool _showBoundingBox = true;
  PointCloudColorMode _colorMode = PointCloudColorMode.confidence;
  double _pointSize = 3.0;

  // Data
  List<ScanPoint> _points = [];
  bool _isLoading = true;
  String? _errorMessage;
  ScanSession? _scan;

  // Export state
  bool _isExporting = false;

  final GlobalKey<PointCloudViewerState> _viewerKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadScanData();
    }
  }

  Future<void> _loadScanData() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    _scan = args['scan'] as ScanSession? ?? args['session'] as ScanSession?;

    if (_scan == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Scan not found';
      });
      return;
    }

    try {
      // Check if points were passed directly
      final passedPoints = args['points'] as List<ScanPoint>?;
      if (passedPoints != null && passedPoints.isNotEmpty) {
        setState(() {
          _points = passedPoints;
          _isLoading = false;
        });
        return;
      }

      // Load from encrypted file
      if (_scan!.filePath != null && _scan!.filePath!.isNotEmpty) {
        final points = await LocalScanStorageService.instance.loadPointCloud(_scan!.filePath!);
        setState(() {
          _points = points;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No point cloud data available for this scan';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load scan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accentBlue),
              const SizedBox(height: 16),
              Text(
                'Loading 3D scan...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, color: AppColors.error, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 3D Point Cloud Viewer
          PointCloudViewer(
            key: _viewerKey,
            points: _points,
            autoRotate: _autoRotate,
            showGrid: _showGrid,
            showAxes: _showAxes,
            showBoundingBox: _showBoundingBox,
            colorMode: _colorMode,
            pointSize: _pointSize,
            onInteraction: () {
              if (_autoRotate) {
                setState(() => _autoRotate = false);
              }
            },
          ),

          // Top Bar
          if (_showControls) _buildTopBar(),

          // Bottom Controls
          if (_showControls) _buildBottomControls(),

          // Measurement Overlay
          if (_showMeasurements) _buildMeasurementOverlay(),

          // Export loading overlay
          if (_isExporting) _buildExportingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Container(
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
            // Back Button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            // Scan Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _scan?.name ?? 'Scan',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_points.length} points  •  ${_scan?.qualityLabel ?? ''}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            // Color Mode Toggle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _cycleColorMode,
                icon: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
                tooltip: 'Color mode',
              ),
            ),
            const SizedBox(width: 8),
            // Share Button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _showShareOptions,
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Point size slider
              Row(
                children: [
                  Icon(Icons.circle, color: Colors.white.withValues(alpha: 0.5), size: 8),
                  Expanded(
                    child: Slider(
                      value: _pointSize,
                      min: 1.0,
                      max: 8.0,
                      activeColor: AppColors.accentBlue,
                      inactiveColor: Colors.white.withValues(alpha: 0.2),
                      onChanged: (v) => setState(() => _pointSize = v),
                    ),
                  ),
                  Icon(Icons.circle, color: Colors.white.withValues(alpha: 0.5), size: 16),
                ],
              ),
              const SizedBox(height: 8),
              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: Icons.straighten_rounded,
                    label: 'Measure',
                    isActive: _showMeasurements,
                    onTap: () => setState(() => _showMeasurements = !_showMeasurements),
                  ),
                  _buildControlButton(
                    icon: Icons.refresh_rounded,
                    label: 'Rotate',
                    isActive: _autoRotate,
                    onTap: () => setState(() => _autoRotate = !_autoRotate),
                  ),
                  _buildControlButton(
                    icon: Icons.center_focus_strong_rounded,
                    label: 'Reset',
                    isActive: false,
                    onTap: () => _viewerKey.currentState?.resetCamera(),
                  ),
                  _buildControlButton(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isActive: false,
                    onTap: _showViewerSettings,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Instructions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded, color: AppColors.accentBlue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Drag to rotate • Pinch to zoom • Tap to hide controls',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accentBlue.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.accentBlue : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(icon, color: isActive ? AppColors.accentBlue : Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.accentBlue : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementOverlay() {
    final dims = _viewerKey.currentState?.boundingDimensions ?? {
      'width': _scan?.metadata['boundingBox']?['sizeX']?.toDouble() ?? 0.0,
      'height': _scan?.metadata['boundingBox']?['sizeY']?.toDouble() ?? 0.0,
      'depth': _scan?.metadata['boundingBox']?['sizeZ']?.toDouble() ?? 0.0,
    };

    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentBlue, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.straighten_rounded, color: AppColors.accentBlue, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Bounding Dimensions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Measured from point cloud bounding box',
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildMeasurementItem('Width (X)', '${dims['width']!.toStringAsFixed(3)} m'),
              const SizedBox(height: 12),
              _buildMeasurementItem('Height (Y)', '${dims['height']!.toStringAsFixed(3)} m'),
              const SizedBox(height: 12),
              _buildMeasurementItem('Depth (Z)', '${dims['depth']!.toStringAsFixed(3)} m'),
              const SizedBox(height: 12),
              _buildMeasurementItem('Points', '${_points.length}'),
              const SizedBox(height: 12),
              _buildMeasurementItem('Quality', '${(_scan?.qualityScore ?? 0) * 100 ~/ 1}%'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() => _showMeasurements = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accentBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildExportingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accentBlue),
            const SizedBox(height: 16),
            const Text(
              'Exporting scan...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleColorMode() {
    setState(() {
      final modes = PointCloudColorMode.values;
      final idx = (modes.indexOf(_colorMode) + 1) % modes.length;
      _colorMode = modes[idx];
    });

    final modeNames = {
      PointCloudColorMode.confidence: 'Confidence',
      PointCloudColorMode.height: 'Height',
      PointCloudColorMode.uniform: 'Uniform',
      PointCloudColorMode.segment: 'Segment',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Color: ${modeNames[_colorMode]}'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Export & Share',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${_points.length} points • ${_scan?.name ?? 'Scan'}',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 20),
            _buildShareTile(Icons.file_download_rounded, 'Export as OBJ', 'Wavefront OBJ — universal 3D format',
                () => _exportAndShare(ExportFormat.obj)),
            _buildShareTile(Icons.file_download_rounded, 'Export as PLY', 'Stanford PLY — with confidence data',
                () => _exportAndShare(ExportFormat.ply)),
            _buildShareTile(Icons.table_chart_rounded, 'Export as CSV', 'Spreadsheet — all point properties',
                () => _exportAndShare(ExportFormat.csv)),
            _buildShareTile(Icons.data_object_rounded, 'Export Metadata', 'JSON — scan info & quality metrics',
                () => _exportAndShare(ExportFormat.json)),
            _buildShareTile(Icons.folder_zip_rounded, 'Export Full Bundle', 'OBJ + PLY + Metadata',
                _exportBundle),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accentBlue),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _exportAndShare(ExportFormat format) async {
    if (_scan == null || _points.isEmpty) return;
    final origin = ScanExportService.getShareOrigin(context);

    setState(() => _isExporting = true);
    try {
      final result = await ScanExportService.instance.exportAndShare(
        format: format,
        sessionId: _scan!.id,
        scanName: _scan!.name,
        points: _points,
        session: _scan,
        sharePositionOrigin: origin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${result.fileSizeFormatted} in ${result.exportDuration.inMilliseconds}ms'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportBundle() async {
    if (_scan == null || _points.isEmpty) return;
    final origin = ScanExportService.getShareOrigin(context);

    setState(() => _isExporting = true);
    try {
      final results = await ScanExportService.instance.exportBundle(
        sessionId: _scan!.id,
        scanName: _scan!.name,
        points: _points,
        session: _scan!,
        sharePositionOrigin: origin,
      );

      if (mounted) {
        final totalSize = results.fold<int>(0, (sum, r) => sum + r.fileSize);
        final totalFormatted = totalSize < 1024 * 1024
            ? '${(totalSize / 1024).toStringAsFixed(1)} KB'
            : '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bundle exported: ${results.length} files ($totalFormatted)'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showViewerSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Viewer Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Show Grid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                value: _showGrid,
                activeThumbColor: AppColors.accentBlue,
                onChanged: (v) {
                  setModalState(() {});
                  setState(() => _showGrid = v);
                },
              ),
              SwitchListTile(
                title: const Text('Show Axes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                value: _showAxes,
                activeThumbColor: AppColors.accentBlue,
                onChanged: (v) {
                  setModalState(() {});
                  setState(() => _showAxes = v);
                },
              ),
              SwitchListTile(
                title: const Text('Show Bounding Box', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                value: _showBoundingBox,
                activeThumbColor: AppColors.accentBlue,
                onChanged: (v) {
                  setModalState(() {});
                  setState(() => _showBoundingBox = v);
                },
              ),
              SwitchListTile(
                title: const Text('Auto Rotate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                value: _autoRotate,
                activeThumbColor: AppColors.accentBlue,
                onChanged: (v) {
                  setModalState(() {});
                  setState(() => _autoRotate = v);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
