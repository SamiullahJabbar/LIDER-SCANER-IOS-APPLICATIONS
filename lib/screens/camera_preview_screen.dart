import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../services/platform_service.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  bool _isFlashOn = false;
  bool _isGridVisible = true;
  bool _isFrontCamera = false;
  bool _isLiDARAvailable = false;
  bool _isInitializing = true;
  String _platformInfo = '';
  String _scanningMethod = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final platform = PlatformService.instance;
    
    setState(() {
      _isLiDARAvailable = platform.hasLiDAR;
      _platformInfo = platform.platformName;
      _scanningMethod = platform.scanningMethod;
    });

    // Simulate camera initialization
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() => _isInitializing = false);
      
      // Show platform-specific info
      String message;
      Color bgColor;
      
      if (platform.isIOS) {
        message = 'iOS Detected - LiDAR scanning enabled';
        bgColor = AppColors.success;
      } else if (platform.isAndroid) {
        message = 'Android Detected - ARCore scanning enabled';
        bgColor = AppColors.accentBlue;
      } else {
        message = 'Web Mode - Simulation only (Use mobile device for real scanning)';
        bgColor = AppColors.warning;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _toggleFlash() {
    setState(() => _isFlashOn = !_isFlashOn);
  }

  void _toggleGrid() {
    setState(() => _isGridVisible = !_isGridVisible);
  }

  void _toggleCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      if (_isFrontCamera) {
        _isFlashOn = false; // Front camera usually doesn't have flash
      }
    });
  }

  void _startScanning() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    Navigator.pushNamed(
      context,
      '/live-scanning',
      arguments: args,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final scanName = args?['scanName'] ?? 'New Scan';
    final roomType = args?['roomType'] ?? 'Room';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview (Simulated)
          _buildCameraPreview(),

          // Grid Overlay
          if (_isGridVisible) _buildGridOverlay(),

          // Top Controls
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(scanName, roomType),
                const Spacer(),
                _buildBottomControls(),
              ],
            ),
          ),

          // Loading Overlay
          if (_isInitializing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final platform = PlatformService.instance;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: platform.isIOS 
                    ? AppColors.success.withOpacity(0.2)
                    : platform.isAndroid
                        ? AppColors.accentBlue.withOpacity(0.2)
                        : AppColors.warning.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 80,
                color: platform.isIOS 
                    ? AppColors.success
                    : platform.isAndroid
                        ? AppColors.accentBlue
                        : AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Camera Preview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: platform.isIOS 
                      ? AppColors.success.withOpacity(0.5)
                      : platform.isAndroid
                          ? AppColors.accentBlue.withOpacity(0.5)
                          : AppColors.warning.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    platform.isWeb ? Icons.info_outline_rounded : Icons.check_circle_rounded,
                    color: platform.isIOS 
                        ? AppColors.success
                        : platform.isAndroid
                            ? AppColors.accentBlue
                            : AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _platformInfo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: platform.isIOS 
                          ? AppColors.success
                          : platform.isAndroid
                              ? AppColors.accentBlue
                              : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _scanningMethod,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    platform.isWeb
                        ? 'Deploy to iOS/Android device for real camera'
                        : 'Real camera will activate on device',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridOverlay() {
    return CustomPaint(
      size: Size.infinite,
      painter: GridPainter(),
    );
  }

  Widget _buildTopBar(String scanName, String roomType) {
    return Container(
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
      child: Column(
        children: [
          Row(
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
              // Scan Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scanName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roomType,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isLiDARAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sensors_rounded,
                                  size: 12,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'LiDAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.camera_rounded,
                                  size: 12,
                                  color: AppColors.accentBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ARCore',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Flash Toggle
              if (!_isFrontCamera)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isFlashOn
                        ? AppColors.warning.withOpacity(0.3)
                        : Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _toggleFlash,
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isFlashOn ? AppColors.warning : Colors.white,
                      size: 22,
                    ),
                  ),
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
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Point camera at the space and tap Start to begin scanning',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
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
        children: [
          // Control Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Grid Toggle
              _buildControlButton(
                icon: Icons.grid_on_rounded,
                label: 'Grid',
                isActive: _isGridVisible,
                onTap: _toggleGrid,
              ),
              // Camera Flip
              _buildControlButton(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Flip',
                isActive: false,
                onTap: _toggleCamera,
              ),
              // Settings
              _buildControlButton(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isActive: false,
                onTap: () {
                  // TODO: Show settings
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Start Button
          GestureDetector(
            onTap: _startScanning,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap to Start',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
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

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Initializing Camera...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Checking LiDAR sensor',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Grid Painter for overlay
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Center crosshair
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final crosshairSize = 20.0;

    paint.color = AppColors.accentBlue.withOpacity(0.8);
    paint.strokeWidth = 2;

    // Horizontal line
    canvas.drawLine(
      Offset(centerX - crosshairSize, centerY),
      Offset(centerX + crosshairSize, centerY),
      paint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(centerX, centerY - crosshairSize),
      Offset(centerX, centerY + crosshairSize),
      paint,
    );

    // Center circle
    paint.style = PaintingStyle.stroke;
    canvas.drawCircle(
      Offset(centerX, centerY),
      crosshairSize * 1.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
