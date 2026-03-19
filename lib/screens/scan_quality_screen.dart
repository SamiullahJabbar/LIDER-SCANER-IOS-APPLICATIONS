import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../models/scan_model.dart';

class ScanQualityScreen extends StatefulWidget {
  const ScanQualityScreen({super.key});

  @override
  State<ScanQualityScreen> createState() => _ScanQualityScreenState();
}

class _ScanQualityScreenState extends State<ScanQualityScreen> {
  bool _isSaving = false;

  Future<void> _saveScan(Map<String, dynamic> args) async {
    if (_isSaving) return; // Prevent double tap
    
    setState(() => _isSaving = true);

    try {
      final coverage = args['coverage'] as double;
      final points = args['points'] as int;
      final duration = args['duration'] as int;
      final scanName = args['scanName'] ?? 'New Scan';
      final roomType = args['roomType'] ?? 'Room';

      // Create scan model
      final scan = ScanModel(
        id: const Uuid().v4(),
        name: scanName,
        createdAt: DateTime.now(),
        quality: coverage / 100,
        filePath: '/scans/${const Uuid().v4()}.glb',
        isUploaded: false,
        metadata: {
          'points': points,
          'duration': duration,
          'roomType': roomType,
          'coverage': coverage,
        },
      );

      // Save to database
      await DatabaseService.instance.createScan(scan);

      // Navigate to preview screen
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/scan-preview',
          arguments: {
            'scan': scan,
            'coverage': coverage,
            'points': points,
            'duration': duration,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving scan: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _rescan() {
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.charcoal;
    final subtitleColor = isDark ? Colors.white70 : AppColors.darkGray;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final coverage = args['coverage'] as double? ?? 0.0;
    final points = args['points'] as int? ?? 0;
    final duration = args['duration'] as int? ?? 0;

    final qualityScore = coverage.toInt();
    final qualityText = _getQualityText(coverage);
    final qualityColor = _getQualityColor(coverage);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(textColor),

            // Content
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 20),

                  // Quality Score Card
                  _buildQualityScoreCard(
                    qualityScore,
                    qualityText,
                    qualityColor,
                    cardColor,
                    textColor,
                  ),

                  const SizedBox(height: 24),

                  // Coverage Map
                  _buildCoverageMap(coverage, cardColor, textColor),

                  const SizedBox(height: 24),

                  // Stats
                  _buildStatsCards(points, duration, cardColor, textColor, subtitleColor),

                  const SizedBox(height: 24),

                  // Suggestions
                  _buildSuggestions(coverage, cardColor, textColor, subtitleColor),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(cardColor, args),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assessment_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Scan Quality',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityScoreCard(
    int score,
    String text,
    Color color,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getQualityIcon(score.toDouble()),
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getQualityMessage(score.toDouble()),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageMap(double coverage, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Coverage Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Simulated coverage map
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.lightGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                painter: CoverageMapPainter(coverage: coverage),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Good', AppColors.success),
              _buildLegendItem('Medium', AppColors.warning),
              _buildLegendItem('Missing', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(
    int points,
    int duration,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.scatter_plot_rounded,
            label: 'Points Captured',
            value: '${(points / 1000).toStringAsFixed(1)}K',
            color: AppColors.accentBlue,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time_rounded,
            label: 'Duration',
            value: '${duration}s',
            color: AppColors.lavender,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subtitleColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(
    double coverage,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final suggestions = _getSuggestions(coverage);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_right_rounded,
                      color: AppColors.accentBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(Color cardColor, Map<String, dynamic> args) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Rescan Button
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: _rescan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: AppColors.charcoal,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Rescan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Continue Button
            Expanded(
              flex: 2,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveScan(args),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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

  String _getQualityText(double coverage) {
    if (coverage >= 80) return 'Excellent';
    if (coverage >= 60) return 'Good';
    if (coverage >= 40) return 'Fair';
    return 'Poor';
  }

  Color _getQualityColor(double coverage) {
    if (coverage >= 80) return AppColors.success;
    if (coverage >= 60) return AppColors.accentBlue;
    if (coverage >= 40) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getQualityIcon(double coverage) {
    if (coverage >= 80) return Icons.check_circle_rounded;
    if (coverage >= 60) return Icons.thumb_up_rounded;
    if (coverage >= 40) return Icons.warning_rounded;
    return Icons.error_rounded;
  }

  String _getQualityMessage(double coverage) {
    if (coverage >= 80) return 'Great scan quality!';
    if (coverage >= 60) return 'Good coverage achieved';
    if (coverage >= 40) return 'Consider rescanning';
    return 'Low coverage detected';
  }

  List<String> _getSuggestions(double coverage) {
    if (coverage >= 80) {
      return [
        'Excellent coverage! Your scan is ready to use.',
        'All areas have been captured successfully.',
      ];
    } else if (coverage >= 60) {
      return [
        'Good coverage overall.',
        'Consider scanning corners more thoroughly.',
        'Check for any missed areas.',
      ];
    } else if (coverage >= 40) {
      return [
        'Some areas need more coverage.',
        'Move closer to walls and corners.',
        'Scan at a slower pace for better results.',
      ];
    } else {
      return [
        'Low coverage detected.',
        'Rescan the space more thoroughly.',
        'Ensure good lighting conditions.',
        'Move slowly and cover all areas.',
      ];
    }
  }
}

// Coverage Map Painter
class CoverageMapPainter extends CustomPainter {
  final double coverage;

  CoverageMapPainter({required this.coverage});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw grid
    final gridSize = 20.0;
    final cols = (size.width / gridSize).ceil();
    final rows = (size.height / gridSize).ceil();

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final random = (i * cols + j) % 100;
        Color color;
        
        if (random < coverage * 0.7) {
          color = AppColors.success.withOpacity(0.6);
        } else if (random < coverage * 0.9) {
          color = AppColors.warning.withOpacity(0.6);
        } else {
          color = AppColors.error.withOpacity(0.3);
        }

        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            j * gridSize,
            i * gridSize,
            gridSize - 2,
            gridSize - 2,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CoverageMapPainter oldDelegate) {
    return coverage != oldDelegate.coverage;
  }
}
