// PRODUCTION-READY Scan Results Screen
// Professional UI with quality analysis, segmentation, and detailed report
// Fully OFFLINE — all data from local storage + quality analyzer
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../utils/app_colors.dart';
import '../providers/theme_provider.dart';
import '../services/local_scan_storage_service.dart';
import '../services/scan_quality_analyzer.dart';
import '../models/scan_point_model.dart';

class ScanResultsScreen extends StatefulWidget {
  final String sessionId;
  final String scanName;
  final int pointCount;
  final String deviceType;
  final ScanQualityResult? qualityResult;
  
  const ScanResultsScreen({
    super.key,
    required this.sessionId,
    required this.scanName,
    required this.pointCount,
    required this.deviceType,
    this.qualityResult,
  });

  @override
  State<ScanResultsScreen> createState() => _ScanResultsScreenState();
}

class _ScanResultsScreenState extends State<ScanResultsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = true;
  bool _hasError = false;
  String? _errorMessage;
  
  // Local processing results
  ScanQualityResult? _qualityResult;
  ScanSession? _session;
  List<ScanPoint> _loadedPoints = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _processLocally();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  /// Process scan data locally — NO backend
  Future<void> _processLocally() async {
    try {
      setState(() {
        _isProcessing = true;
        _hasError = false;
      });
      
      final storage = LocalScanStorageService.instance;
      
      // Load session metadata
      final sessions = await storage.getAllSessions();
      _session = sessions.firstWhere(
        (s) => s.id == widget.sessionId,
        orElse: () => throw Exception('Session not found: ${widget.sessionId}'),
      );
      
      // If quality result was passed directly, use it
      if (widget.qualityResult != null) {
        _qualityResult = widget.qualityResult;
      } else {
        // Load point cloud and analyze locally
        _loadedPoints = await storage.loadPointCloudBySessionId(widget.sessionId);
        
        if (_loadedPoints.isNotEmpty) {
          _qualityResult = ScanQualityAnalyzer.analyze(
            _loadedPoints,
          );
        }
      }
      
      setState(() {
        _isProcessing = false;
      });
      
    } catch (e) {
      debugPrint('❌ Local processing error: $e');
      setState(() {
        _isProcessing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.charcoal;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(textColor, cardColor),
            if (_isProcessing)
              _buildProcessingView(textColor)
            else if (_hasError)
              _buildErrorView(textColor)
            else
              Expanded(
                child: Column(
                  children: [
                    _buildTabBar(textColor, cardColor),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(textColor, cardColor),
                          _buildSegmentsTab(textColor, cardColor),
                          _buildDetailsTab(textColor, cardColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(cardColor),
    );
  }
  
  Widget _buildAppBar(Color textColor, Color cardColor) {
    final grade = _qualityResult?.grade ?? 'N/A';
    final gradeColor = _getGradeColor(grade);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_rounded, color: textColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.scanName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.pointCount} points • ${widget.deviceType}',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // Quality grade badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gradeColor, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: gradeColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Grade $grade',
                  style: TextStyle(
                    color: gradeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProcessingView(Color textColor) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Analyzing Scan Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Running quality analysis and segmentation...',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorView(Color textColor) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: AppColors.error),
              const SizedBox(height: 24),
              Text(
                'Analysis Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'An error occurred',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _processLocally,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabBar(Color textColor, Color cardColor) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textColor.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Segments'),
          Tab(text: 'Details'),
        ],
      ),
    );
  }
  
  Widget _buildOverviewTab(Color textColor, Color cardColor) {
    if (_qualityResult == null) {
      return Center(
        child: Text('No quality data available', style: TextStyle(color: textColor)),
      );
    }
    
    final q = _qualityResult!;
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Quality Score Card
        _buildQualityScoreCard(q, textColor, cardColor),
        const SizedBox(height: 16),
        // Quality Metrics Breakdown
        _buildQualityMetricsCard(q, textColor, cardColor),
        const SizedBox(height: 16),
        // Segment Summary
        _buildSegmentSummaryCard(q, textColor, cardColor),
      ],
    );
  }
  
  Widget _buildQualityScoreCard(ScanQualityResult q, Color textColor, Color cardColor) {
    final scoreColor = _getGradeColor(q.grade);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Big circular quality score
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: q.overallScore,
                    strokeWidth: 10,
                    backgroundColor: scoreColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(q.overallScore * 100).toInt()}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      'Grade ${q.grade}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Overall Quality Score',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q.overallScore >= 0.8
                ? 'Excellent scan quality — ready for professional use'
                : q.overallScore >= 0.6
                    ? 'Good scan quality — suitable for most applications'
                    : q.overallScore >= 0.4
                        ? 'Fair quality — consider rescanning for better results'
                        : 'Low quality — rescanning recommended',
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildQualityMetricsCard(ScanQualityResult q, Color textColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quality Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildMetricBar('Coverage', q.coveragePercent, AppColors.accentBlue, textColor),
          const SizedBox(height: 16),
          _buildMetricBar('Stability', q.stabilityScore, AppColors.success, textColor),
          const SizedBox(height: 16),
          _buildMetricBar('Density', q.densityScore, AppColors.warning, textColor),
        ],
      ),
    );
  }
  
  Widget _buildMetricBar(String label, double value, Color color, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSegmentSummaryCard(ScanQualityResult q, Color textColor, Color cardColor) {
    final segments = q.segments;
    final wallCount = segments.where((s) => s.type == SegmentType.wall).length;
    final floorCount = segments.where((s) => s.type == SegmentType.floor).length;
    final ceilingCount = segments.where((s) => s.type == SegmentType.ceiling).length;
    final objectCount = segments.where((s) => s.type == SegmentType.object).length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auto-Segmentation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${segments.length} segments detected',
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _buildSurfaceRow('Walls', wallCount, AppColors.accentBlue, textColor),
          const SizedBox(height: 12),
          _buildSurfaceRow('Floors', floorCount, AppColors.success, textColor),
          const SizedBox(height: 12),
          _buildSurfaceRow('Ceilings', ceilingCount, AppColors.warning, textColor),
          const SizedBox(height: 12),
          _buildSurfaceRow('Objects', objectCount, AppColors.mint, textColor),
        ],
      ),
    );
  }
  
  Widget _buildSegmentsTab(Color textColor, Color cardColor) {
    if (_qualityResult == null || _qualityResult!.segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, size: 60, color: textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No segments detected',
              style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }
    
    final segments = _qualityResult!.segments;
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        return _buildSegmentCard(segment, index, textColor, cardColor);
      },
    );
  }
  
  Widget _buildSegmentCard(SegmentInfo segment, int index, Color textColor, Color cardColor) {
    final color = _getSegmentColor(segment.type);
    final typeName = segment.type.name.toUpperCase();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  typeName,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSegmentDetail('Points', '${segment.pointCount}', textColor),
              const SizedBox(width: 24),
              _buildSegmentDetail(
                'Confidence',
                '${(segment.confidence * 100).toInt()}%',
                textColor,
              ),
              const SizedBox(width: 24),
              _buildSegmentDetail(
                'Area',
                '${segment.areaM2.toStringAsFixed(2)} m²',
                textColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSegmentDetail(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailsTab(Color textColor, Color cardColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildDetailSection('Scan Information', [
          {'label': 'Session ID', 'value': widget.sessionId.substring(0, 8)},
          {'label': 'Device Type', 'value': widget.deviceType},
          {'label': 'Total Points', 'value': '${widget.pointCount}'},
          {'label': 'Room Type', 'value': _session?.roomType ?? 'general'},
        ], textColor, cardColor),
        const SizedBox(height: 16),
        _buildDetailSection('Quality Analysis', [
          {'label': 'Overall Score', 'value': _qualityResult != null ? '${(_qualityResult!.overallScore * 100).toInt()}%' : 'N/A'},
          {'label': 'Grade', 'value': _qualityResult?.grade ?? 'N/A'},
          {'label': 'Coverage', 'value': _qualityResult != null ? '${(_qualityResult!.coveragePercent * 100).toInt()}%' : 'N/A'},
          {'label': 'Stability', 'value': _qualityResult != null ? '${(_qualityResult!.stabilityScore * 100).toInt()}%' : 'N/A'},
          {'label': 'Density', 'value': _qualityResult != null ? '${(_qualityResult!.densityScore * 100).toInt()}%' : 'N/A'},
        ], textColor, cardColor),
        const SizedBox(height: 16),
        _buildDetailSection('Storage', [
          {'label': 'Saved Locally', 'value': 'Yes (Encrypted)'},
          {'label': 'Encryption', 'value': 'AES-256'},
          {'label': 'File Format', 'value': 'LSCN Binary'},
          {'label': 'Segments', 'value': '${_qualityResult?.segments.length ?? 0}'},
        ], textColor, cardColor),
      ],
    );
  }
  
  Widget _buildDetailSection(
    String title,
    List<Map<String, String>> items,
    Color textColor,
    Color cardColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['label']!,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  item['value']!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildSurfaceRow(String label, int count, Color color, Color textColor) {
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBottomActions(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: Upload + Export
            Row(
              children: [
                // Upload to Vault
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_session != null) {
                        Navigator.pushNamed(
                          context,
                          '/scan-vault-upload',
                          arguments: {'session': _session},
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.warning, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_rounded, color: AppColors.warning, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Upload',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Export scan
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_session != null) {
                        Navigator.pushNamed(
                          context,
                          '/scan-upload',
                          arguments: {'session': _session},
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.success, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_download_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Export',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Bottom row: 3D View + Done
            Row(
              children: [
                // View 3D
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Load points for 3D viewer
                      List<ScanPoint> points = _loadedPoints;
                      if (points.isEmpty) {
                        points = await LocalScanStorageService.instance.loadPointCloudBySessionId(widget.sessionId);
                      }
                      if (mounted) {
                        Navigator.pushNamed(
                          context,
                          '/3d-viewer',
                          arguments: {
                            'session': _session,
                            'points': points,
                          },
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      side: const BorderSide(
                        color: Color(0xFF00E5FF),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.view_in_ar, color: Color(0xFF00E5FF), size: 18),
                        SizedBox(width: 6),
                        Text(
                          '3D View',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Done
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.accentBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getSegmentColor(SegmentType type) {
    switch (type) {
      case SegmentType.wall:
        return AppColors.accentBlue;
      case SegmentType.floor:
        return AppColors.success;
      case SegmentType.ceiling:
        return AppColors.warning;
      case SegmentType.object:
        return AppColors.mint;
      case SegmentType.unknown:
        return AppColors.mediumGray;
    }
  }
  
  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A': return AppColors.success;
      case 'B': return const Color(0xFF4CAF50);
      case 'C': return AppColors.warning;
      case 'D': return Colors.orange;
      case 'F': return AppColors.error;
      default: return AppColors.mediumGray;
    }
  }
}
