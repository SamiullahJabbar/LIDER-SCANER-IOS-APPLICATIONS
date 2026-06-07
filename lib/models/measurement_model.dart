// Production-ready Measurement Model
// Represents calculated measurements from backend
import 'package:json_annotation/json_annotation.dart';

part 'measurement_model.g.dart';

@JsonSerializable()
class Measurement {
  final String id;
  
  @JsonKey(name: 'measurement_type')
  final String measurementType;
  
  final double value;
  final String unit;
  
  @JsonKey(name: 'confidence_score')
  final double confidenceScore;
  
  @JsonKey(name: 'is_validated')
  final bool isValidated;
  
  @JsonKey(name: 'validation_method')
  final String? validationMethod;
  
  @JsonKey(name: 'algorithm_version')
  final String? algorithmVersion;
  
  @JsonKey(name: 'processing_time_ms')
  final int? processingTimeMs;
  
  final Map<String, dynamic>? metadata;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  Measurement({
    required this.id,
    required this.measurementType,
    required this.value,
    required this.unit,
    required this.confidenceScore,
    required this.isValidated,
    this.validationMethod,
    this.algorithmVersion,
    this.processingTimeMs,
    this.metadata,
    required this.createdAt,
  });
  
  factory Measurement.fromJson(Map<String, dynamic> json) => 
      _$MeasurementFromJson(json);
  
  Map<String, dynamic> toJson() => _$MeasurementToJson(this);
  
  String get typeDisplay {
    switch (measurementType) {
      case 'DISTANCE':
        return 'Distance';
      case 'AREA':
        return 'Area';
      case 'VOLUME':
        return 'Volume';
      default:
        return measurementType;
    }
  }
  
  String get unitDisplay {
    switch (unit) {
      case 'meters':
        return 'm';
      case 'square_meters':
        return 'm²';
      case 'cubic_meters':
        return 'm³';
      default:
        return unit;
    }
  }
  
  String get formattedValue {
    return '${value.toStringAsFixed(2)} $unitDisplay';
  }
  
  String get confidenceDisplay {
    return '${confidenceScore.toStringAsFixed(1)}%';
  }
  
  String get qualityLevel {
    if (confidenceScore >= 80) return 'High';
    if (confidenceScore >= 60) return 'Medium';
    return 'Low';
  }
  
  // Metadata helpers
  int? get pointCount => metadata?['point_count'] as int?;
  int? get outlierCount => metadata?['outlier_count'] as int?;
  double? get consistencyScore => (metadata?['consistency_score'] as num?)?.toDouble();
  double? get straightnessScore => (metadata?['straightness_score'] as num?)?.toDouble();
  double? get directDistance => (metadata?['direct_distance'] as num?)?.toDouble();
  double? get pathDistance => (metadata?['path_distance'] as num?)?.toDouble();
  
  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;
}
