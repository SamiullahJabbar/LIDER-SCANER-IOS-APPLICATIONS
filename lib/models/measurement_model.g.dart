// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Measurement _$MeasurementFromJson(Map<String, dynamic> json) => Measurement(
      id: json['id'] as String,
      measurementType: json['measurement_type'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      isValidated: json['is_validated'] as bool,
      validationMethod: json['validation_method'] as String?,
      algorithmVersion: json['algorithm_version'] as String?,
      processingTimeMs: json['processing_time_ms'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$MeasurementToJson(Measurement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'measurement_type': instance.measurementType,
      'value': instance.value,
      'unit': instance.unit,
      'confidence_score': instance.confidenceScore,
      'is_validated': instance.isValidated,
      'validation_method': instance.validationMethod,
      'algorithm_version': instance.algorithmVersion,
      'processing_time_ms': instance.processingTimeMs,
      'metadata': instance.metadata,
      'created_at': instance.createdAt.toIso8601String(),
    };
