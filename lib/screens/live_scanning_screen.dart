import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../models/scan_model.dart';

class LiveScanningScreen extends StatefulWidget {
  const LiveScanningScreen({super.key});

  @override
  State<LiveScanningScreen> createState() => _LiveScanningScreenState();
}

class _LiveScanningScreenState extends State<LiveScanningScreen> {
  bool _isScanning = false;
  bool _isPaused = false;
  double _coverage = 0.0;
  int _pointsCaptured = 0;
  int _scanDuration = 0;
  Timer? _scanTimer;
  Timer? _coverageTimer;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _coverageTimer?.cancel();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _isPaused = false;
    });

    // Simulate scan duration timer
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _scanDuration++;
        });
      }
    });

    // Simulate coverage increase
    _coverageTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isPaused && _coverage < 100) {
        setState(() {
          _coverage += 2.5;
          _pointsCaptured += 1500;
          if (_coverage > 100) _coverage = 100;
        });
      }
    });
  }

  void _pauseScanning() {
    setState(() => _isPaused = true);
  }

  void _resumeScanning() {
    setState(() => _isPaused = false);
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    _coverageTimer?.cancel();
    
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    // Navigate to quality indicator screen
    Navigator.pushReplacementNamed(
      context,
      '/scan-quality',
      arguments: {
        'coverage': _coverage,
        'points': _pointsCaptured,
        'duration': _scanDuration,
        'scanName': args?['scanName'] ?? 'New Scan',
        'roomType': args?['roomType'] ?? 'Room',
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final scanName = args?['scanName'] ?? 'New Scan';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ARKit Camera View (Simulated)
          _buildARView(),

          // Point Cloud Overlay
          _buildPointCloudOverlay(),

          // UI Overlay
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(scanName),
                const Spacer(),
                _buildStatsPanel(),
                const SizedBox(height: 20),
                _buildControlButtons(),
              ],
            ),
          ),

          // Pause Overlay
          if (_isPaused) _buildPauseOverlay(),
        ],
      ),
    );
  }

  Widget _buildARView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[900]!,
            Colors.grey[800]!,
            Colors.grey[850]!,
          ],
        ),
      ),
    );
  }

  Widget _buildPointCloudOverlay() {
    return CustomPaint(
      size: Size.infinite,
      painter: PointCloudPainter(
        coverage: _coverage,
        isScanning: _isScanning && !_isPaused,
      ),
    );
  }

  Widget _buildTopBar(String scanName) {
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
              // Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isPaused
                      ? AppColors.warning.withOpacity(0.2)
                      : AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isPaused ? AppColors.warning : AppColors.success,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isPaused ? AppColors.warning : AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPaused ? 'PAUSED' : 'SCANNING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _isPaused ? AppColors.warning : AppColors.success,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_scanDuration),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scan Name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.view_in_ar_rounded,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    scanName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Coverage Progress
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Coverage',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '${_coverage.toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _getCoverageColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _coverage / 100,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getCoverageColor(),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Points Captured
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.scatter_plot_rounded,
                  label: 'Points',
                  value: '${(_pointsCaptured / 1000).toStringAsFixed(1)}K',
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.high_quality_rounded,
                  label: 'Quality',
                  value: _getQualityText(),
                  color: _getCoverageColor(),
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop Button
          _buildActionButton(
            icon: Icons.stop_rounded,
            label: 'Stop',
            color: AppColors.error,
            onTap: _stopScanning,
          ),
          // Pause/Resume Button
          _buildActionButton(
            icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: _isPaused ? 'Resume' : 'Pause',
            color: AppColors.warning,
            onTap: _isPaused ? _resumeScanning : _pauseScanning,
            isLarge: true,
          ),
          // Info Button
          _buildActionButton(
            icon: Icons.info_outline_rounded,
            label: 'Info',
            color: AppColors.accentBlue,
            onTap: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    final size = isLarge ? 80.0 : 64.0;
    final iconSize = isLarge ? 36.0 : 28.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.warning,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pause_circle_rounded,
                color: AppColors.warning,
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan Paused',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Resume to continue scanning',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCoverageColor() {
    if (_coverage >= 80) return AppColors.success;
    if (_coverage >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String _getQualityText() {
    if (_coverage >= 80) return 'High';
    if (_coverage >= 50) return 'Medium';
    return 'Low';
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Scanning Tips'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTipItem('Move slowly and steadily'),
            _buildTipItem('Cover all corners and edges'),
            _buildTipItem('Maintain 1-3 meters distance'),
            _buildTipItem('Avoid reflective surfaces'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// Point Cloud Painter
class PointCloudPainter extends CustomPainter {
  final double coverage;
  final bool isScanning;

  PointCloudPainter({
    required this.coverage,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    final random = DateTime.now().millisecondsSinceEpoch;
    final pointCount = (coverage * 50).toInt();

    for (int i = 0; i < pointCount; i++) {
      final x = ((random + i * 123) % size.width.toInt()).toDouble();
      final y = ((random + i * 456) % size.height.toInt()).toDouble();
      
      paint.color = AppColors.accentBlue.withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PointCloudPainter oldDelegate) {
    return coverage != oldDelegate.coverage || isScanning != oldDelegate.isScanning;
  }
}
