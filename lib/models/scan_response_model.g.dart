// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanResponse _$ScanResponseFromJson(Map<String, dynamic> json) => ScanResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      deviceType: json['device_type'] as String,
      deviceModel: json['device_model'] as String?,
      status: json['status'] as String,
      pointCount: json['point_count'] as int,
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      pointDensity: (json['point_density'] as num?)?.toDouble(),
      fileSizeBytes: json['file_size_bytes'] as int?,
      pointCloudFile: json['point_cloud_file'] as String?,
      meshFile: json['mesh_file'] as String?,
      thumbnail: json['thumbnail'] as String?,
      processingError: json['processing_error'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.parse(json['processed_at'] as String),
    );

Map<String, dynamic> _$ScanResponseToJson(ScanResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'device_type': instance.deviceType,
      'device_model': instance.deviceModel,
      'status': instance.status,
      'point_count': instance.pointCount,
      'confidence_score': instance.confidenceScore,
      'point_density': instance.pointDensity,
      'file_size_bytes': instance.fileSizeBytes,
      'point_cloud_file': instance.pointCloudFile,
      'mesh_file': instance.meshFile,
      'thumbnail': instance.thumbnail,
      'processing_error': instance.processingError,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'processed_at': instance.processedAt?.toIso8601String(),
    };
