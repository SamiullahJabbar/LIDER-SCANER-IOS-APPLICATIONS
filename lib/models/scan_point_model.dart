// Production-ready Scan Point Model
// Represents a single 3D point in the scan
// Uses dart:math for accurate distance calculations
import 'package:json_annotation/json_annotation.dart';
import 'dart:math' as math;

part 'scan_point_model.g.dart';

@JsonSerializable()
class ScanPoint {
  final double x;
  final double y;
  final double z;
  
  @JsonKey(name: 'sequence_number')
  final int sequenceNumber;
  
  @JsonKey(name: 'is_manual_pin')
  final bool isManualPin;
  
  final double confidence;
  
  @JsonKey(name: 'is_outlier')
  final bool? isOutlier;
  
  @JsonKey(name: 'captured_at')
  final DateTime? capturedAt;
  
  ScanPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.sequenceNumber,
    this.isManualPin = false,
    this.confidence = 1.0,
    this.isOutlier,
    this.capturedAt,
  });
  
  factory ScanPoint.fromJson(Map<String, dynamic> json) => 
      _$ScanPointFromJson(json);
  
  Map<String, dynamic> toJson() => _$ScanPointToJson(this);
  
  /// Create from AR frame data
  factory ScanPoint.fromARFrame({
    required double x,
    required double y,
    required double z,
    required int sequenceNumber,
    bool isManualPin = false,
    double confidence = 0.95,
  }) {
    return ScanPoint(
      x: x,
      y: y,
      z: z,
      sequenceNumber: sequenceNumber,
      isManualPin: isManualPin,
      confidence: confidence,
      capturedAt: DateTime.now(),
    );
  }
  
  /// Calculate Euclidean distance to another point (meters)
  double distanceTo(ScanPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
  
  @override
  String toString() {
    return 'ScanPoint(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, '
           'z: ${z.toStringAsFixed(3)}, seq: $sequenceNumber, manual: $isManualPin, '
           'confidence: ${confidence.toStringAsFixed(2)})';
  }
}
