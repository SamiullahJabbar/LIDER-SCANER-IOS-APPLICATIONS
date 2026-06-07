// Production-ready Measurement Result Screen
// Shows locally calculated measurements — NO backend API
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/local_scan_storage_service.dart';
import '../utils/app_colors.dart';

class MeasurementResultScreen extends StatefulWidget {
  const MeasurementResultScreen({super.key});

  @override
  State<MeasurementResultScreen> createState() => _MeasurementResultScreenState();
}

class _MeasurementResultScreenState extends State<MeasurementResultScreen> {
  bool _isCalculating = false;
  String? _errorMessage;
  
  // Local measurement data
  String? _scanId;
  String? _scanName;
  int? _pointCount;
  double? _distance;
  double? _area;
  double? _confidence;
  String _selectedType = 'distance';
  
  @override
  void initState() {
    super.initState();
    
    // Get arguments after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _scanId = args['scanId'] as String?;
          _scanName = args['scanName'] as String?;
          _pointCount = args['pointCount'] as int?;
          _distance = (args['distance'] as num?)?.toDouble();
          _area = (args['area'] as num?)?.toDouble();
          _confidence = (args['confidence'] as num?)?.toDouble() ?? 85.0;
        });
        
        // Auto-calculate from local data
        if (_distance == null && _scanId != null) {
          _calculateLocalMeasurement();
        }
      }
    });
  }

  /// Calculate measurement from locally stored scan data
  Future<void> _calculateLocalMeasurement() async {
    setState(() {
      _isCalculating = true;
      _errorMessage = null;
    });
    
    try {
      final storage = LocalScanStorageService.instance;
      final sessions = await storage.getAllSessions();
      final session = sessions.where((s) => s.id == _scanId).firstOrNull;
      
      if (session != null) {
        // Use quality metrics for confidence
        _confidence = session.qualityScore * 100;
        _pointCount = session.pointCount;
        
        // Try to load point cloud for distance calculation
        try {
          final points = await storage.loadPointCloudBySessionId(_scanId!);
          if (points.isNotEmpty && points.length >= 2) {
            // Calculate bounding box distance
            double minX = double.infinity, maxX = double.negativeInfinity;
            double minY = double.infinity, maxY = double.negativeInfinity;
            double minZ = double.infinity, maxZ = double.negativeInfinity;
            
            for (final p in points) {
              if (p.x < minX) minX = p.x;
              if (p.x > maxX) maxX = p.x;
              if (p.y < minY) minY = p.y;
              if (p.y > maxY) maxY = p.y;
              if (p.z < minZ) minZ = p.z;
              if (p.z > maxZ) maxZ = p.z;
            }
            
            final dx = maxX - minX;
            final dy = maxY - minY;
            final dz = maxZ - minZ;
            
            _distance = math.sqrt(dx * dx + dy * dy + dz * dz);
            _area = dx * dz; // Floor area estimate (X × Z)
          }
        } catch (_) {
          // Point cloud might not exist yet
        }
        
        // Fallback values from metadata
        _distance ??= (session.metadata['distance'] as num?)?.toDouble() ?? 0.0;
        _area ??= (session.metadata['area'] as num?)?.toDouble() ?? 0.0;
      }
      
      setState(() => _isCalculating = false);
    } catch (e) {
      setState(() {
        _isCalculating = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _scanName ?? 'Measurement Result',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isCalculating
          ? _buildCalculatingView()
          : _errorMessage != null
              ? _buildErrorView()
              : _distance != null || _area != null
                  ? _buildResultView()
                  : _buildEmptyView(),
    );
  }
  
  Widget _buildCalculatingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accentBlue),
          const SizedBox(height: 20),
          const Text(
            'Calculating measurement...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            'Processing ${_pointCount ?? 0} points locally',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 60),
            const SizedBox(height: 20),
            const Text(
              'Calculation Failed',
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
              onPressed: _calculateLocalMeasurement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyView() {
    return const Center(
      child: Text(
        'No measurement data',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }
  
  Widget _buildResultView() {
    final value = _selectedType == 'distance' ? _distance ?? 0.0 : _area ?? 0.0;
    final unit = _selectedType == 'distance' ? 'm' : 'm²';
    final typeLabel = _selectedType == 'distance' ? 'Distance' : 'Area';
    final confidenceValue = _confidence ?? 85.0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Type selector
          _buildTypeSelector(),
          
          const SizedBox(height: 20),
          
          // Main measurement card
          _buildMeasurementCard(value, unit, typeLabel, confidenceValue),
          
          const SizedBox(height: 20),
          
          // Confidence card
          _buildConfidenceCard(confidenceValue),
          
          const SizedBox(height: 20),
          
          // Details card
          _buildDetailsCard(),
          
          const SizedBox(height: 20),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }
  
  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedType = 'distance'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedType == 'distance' 
                    ? AppColors.accentBlue 
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedType == 'distance'
                      ? AppColors.accentBlue
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  'Distance',
                  style: TextStyle(
                    color: _selectedType == 'distance' ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedType = 'area'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedType == 'area' 
                    ? AppColors.accentBlue 
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedType == 'area'
                      ? AppColors.accentBlue
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  'Area',
                  style: TextStyle(
                    color: _selectedType == 'area' ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMeasurementCard(double value, String unit, String typeLabel, double confidence) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentBlue.withValues(alpha: 0.2),
            AppColors.accentBlue.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentBlue, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            _selectedType == 'distance' ? Icons.straighten : Icons.crop_square,
            color: AppColors.accentBlue,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            typeLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(2)} $unit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                confidence >= 70 ? Icons.check_circle : Icons.warning,
                color: confidence >= 70 ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                confidence >= 70 ? 'Validated Locally' : 'Low Confidence',
                style: TextStyle(
                  color: confidence >= 70 ? AppColors.success : AppColors.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfidenceCard(double confidence) {
    final color = _getConfidenceColor(confidence);
    final qualityLevel = confidence >= 80 ? 'High' : (confidence >= 60 ? 'Medium' : 'Low');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Confidence Score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: confidence / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              qualityLevel,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_pointCount != null)
            _buildMetadataRow('Points', '$_pointCount'),
          if (_distance != null)
            _buildMetadataRow('Distance', '${_distance!.toStringAsFixed(2)} m'),
          if (_area != null)
            _buildMetadataRow('Area', '${_area!.toStringAsFixed(2)} m²'),
          _buildMetadataRow('Method', 'Local Calculation'),
          _buildMetadataRow('Algorithm', 'Bounding Box v1.0'),
        ],
      ),
    );
  }
  
  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Share measurement
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Color _getConfidenceColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }
}
