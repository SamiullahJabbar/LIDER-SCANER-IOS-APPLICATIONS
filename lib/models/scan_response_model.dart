// Production-ready Scan Response Model
// Matches backend API response exactly
import 'package:json_annotation/json_annotation.dart';

part 'scan_response_model.g.dart';

@JsonSerializable()
class ScanResponse {
  final String id;
  final String name;
  final String? description;
  
  @JsonKey(name: 'device_type')
  final String deviceType;
  
  @JsonKey(name: 'device_model')
  final String? deviceModel;
  
  final String status;
  
  @JsonKey(name: 'point_count')
  final int pointCount;
  
  @JsonKey(name: 'confidence_score')
  final double confidenceScore;
  
  @JsonKey(name: 'point_density')
  final double? pointDensity;
  
  @JsonKey(name: 'file_size_bytes')
  final int? fileSizeBytes;
  
  @JsonKey(name: 'point_cloud_file')
  final String? pointCloudFile;
  
  @JsonKey(name: 'mesh_file')
  final String? meshFile;
  
  final String? thumbnail;
  
  @JsonKey(name: 'processing_error')
  final String? processingError;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  
  @JsonKey(name: 'processed_at')
  final DateTime? processedAt;
  
  ScanResponse({
    required this.id,
    required this.name,
    this.description,
    required this.deviceType,
    this.deviceModel,
    required this.status,
    required this.pointCount,
    required this.confidenceScore,
    this.pointDensity,
    this.fileSizeBytes,
    this.pointCloudFile,
    this.meshFile,
    this.thumbnail,
    this.processingError,
    required this.createdAt,
    required this.updatedAt,
    this.processedAt,
  });
  
  factory ScanResponse.fromJson(Map<String, dynamic> json) => 
      _$ScanResponseFromJson(json);
  
  Map<String, dynamic> toJson() => _$ScanResponseToJson(this);
  
  bool get isCompleted => status == 'COMPLETED';
  bool get isProcessing => status == 'PROCESSING';
  bool get isFailed => status == 'FAILED';
  bool get isUploading => status == 'UPLOADING';
  
  String get statusDisplay {
    switch (status) {
      case 'COMPLETED':
        return 'Completed';
      case 'PROCESSING':
        return 'Processing';
      case 'FAILED':
        return 'Failed';
      case 'UPLOADING':
        return 'Uploading';
      default:
        return status;
    }
  }
  
  String get qualityDisplay {
    if (confidenceScore >= 80) return 'High';
    if (confidenceScore >= 60) return 'Medium';
    return 'Low';
  }
}
