import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../models/scan_model.dart';
import '../services/platform_service.dart';

class Viewer3DScreen extends StatefulWidget {
  const Viewer3DScreen({super.key});

  @override
  State<Viewer3DScreen> createState() => _Viewer3DScreenState();
}

class _Viewer3DScreenState extends State<Viewer3DScreen> {
  bool _showControls = true;
  bool _showMeasurements = false;
  bool _autoRotate = true;
  bool _showGrid = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final scan = args['scan'] as ScanModel?;

    if (scan == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Error: Scan not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 3D Model Viewer
          _build3DViewer(scan),

          // Top Bar
          if (_showControls) _buildTopBar(scan),

          // Bottom Controls
          if (_showControls) _buildBottomControls(),

          // Measurement Overlay
          if (_showMeasurements) _buildMeasurementOverlay(),
        ],
      ),
    );
  }

  Widget _build3DViewer(ScanModel scan) {
    final platform = PlatformService.instance;
    
    // Use sample 3D model URL (you can replace with your own)
    final modelUrl = 'https://modelviewer.dev/shared-assets/models/Astronaut.glb';
    
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
      },
      child: ModelViewer(
        src: modelUrl,
        alt: scan.name,
        ar: platform.isIOS || platform.isAndroid,
        autoRotate: _autoRotate,
        cameraControls: true,
        backgroundColor: Colors.black,
        loading: Loading.eager,
        autoPlay: true,
        cameraOrbit: "0deg 75deg 105%",
        minCameraOrbit: "auto auto 5%",
        maxCameraOrbit: "auto auto 500%",
        interpolationDecay: 200,
      ),
    );
  }

  Widget _buildTopBar(ScanModel scan) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
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
                    scan.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3D Model Viewer',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Share Button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _showShareOptions,
                icon: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
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
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: Icons.straighten_rounded,
                    label: 'Measure',
                    isActive: _showMeasurements,
                    onTap: () {
                      setState(() => _showMeasurements = !_showMeasurements);
                    },
                  ),
                  _buildControlButton(
                    icon: Icons.refresh_rounded,
                    label: 'Rotate',
                    isActive: _autoRotate,
                    onTap: () {
                      setState(() => _autoRotate = !_autoRotate);
                    },
                  ),
                  _buildControlButton(
                    icon: Icons.screenshot_rounded,
                    label: 'Capture',
                    isActive: false,
                    onTap: _captureScreenshot,
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
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      color: AppColors.accentBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drag to rotate • Pinch to zoom • Tap to hide controls',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                      ),
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
                  ? AppColors.accentBlue.withOpacity(0.3)
                  : Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.accentBlue : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.accentBlue : Colors.white,
              size: 24,
            ),
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
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentBlue,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.straighten_rounded,
                color: AppColors.accentBlue,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Measurement Tool',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap two points on the model to measure distance',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildMeasurementItem('Width', '3.5 m'),
              const SizedBox(height: 12),
              _buildMeasurementItem('Height', '2.8 m'),
              const SizedBox(height: 12),
              _buildMeasurementItem('Depth', '4.2 m'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _showMeasurements = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  void _captureScreenshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Screenshot saved to gallery'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Share 3D Model',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildShareOption(Icons.file_download_rounded, 'Export as OBJ'),
            _buildShareOption(Icons.file_download_rounded, 'Export as FBX'),
            _buildShareOption(Icons.share_rounded, 'Share Link'),
            _buildShareOption(Icons.email_rounded, 'Send via Email'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accentBlue),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label - Coming soon'),
            backgroundColor: AppColors.accentBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  void _showViewerSettings() {
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Viewer Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingOption('Show Grid', true),
            _buildSettingOption('Show Axes', false),
            _buildSettingOption('Wireframe Mode', false),
            _buildSettingOption('Auto Rotate', false),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingOption(String label, bool value) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      value: value,
      activeColor: AppColors.accentBlue,
      onChanged: (val) {
        Navigator.pop(context);
      },
    );
  }
}

// 3D Model Painter (Simulated)
class Model3DPainter extends CustomPainter {
  final double rotationX;
  final double rotationY;
  final double zoom;
  final double quality;

  Model3DPainter({
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.quality,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseSize = 100.0 * zoom;

    // Draw 3D cube (simulated)
    paint.color = AppColors.accentBlue.withOpacity(0.8);
    
    // Front face
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: baseSize,
        height: baseSize,
      ),
      paint,
    );

    // Back face (offset for 3D effect)
    final offset = 30.0 * zoom;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX + offset, centerY - offset),
        width: baseSize,
        height: baseSize,
      ),
      paint,
    );

    // Connecting lines
    paint.color = AppColors.accentBlue.withOpacity(0.4);
    canvas.drawLine(
      Offset(centerX - baseSize / 2, centerY - baseSize / 2),
      Offset(centerX - baseSize / 2 + offset, centerY - baseSize / 2 - offset),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + baseSize / 2, centerY - baseSize / 2),
      Offset(centerX + baseSize / 2 + offset, centerY - baseSize / 2 - offset),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - baseSize / 2, centerY + baseSize / 2),
      Offset(centerX - baseSize / 2 + offset, centerY + baseSize / 2 - offset),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + baseSize / 2, centerY + baseSize / 2),
      Offset(centerX + baseSize / 2 + offset, centerY + baseSize / 2 - offset),
      paint,
    );

    // Draw point cloud
    paint.style = PaintingStyle.fill;
    final pointCount = (quality * 100).toInt();
    for (int i = 0; i < pointCount; i++) {
      final x = centerX + (i % 20 - 10) * 10 * zoom;
      final y = centerY + (i ~/ 20 - 5) * 10 * zoom;
      paint.color = AppColors.accentBlue.withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant Model3DPainter oldDelegate) {
    return rotationX != oldDelegate.rotationX ||
        rotationY != oldDelegate.rotationY ||
        zoom != oldDelegate.zoom;
  }
}
