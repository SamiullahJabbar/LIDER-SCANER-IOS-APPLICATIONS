// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_point_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanPoint _$ScanPointFromJson(Map<String, dynamic> json) => ScanPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      sequenceNumber: json['sequence_number'] as int,
      isManualPin: json['is_manual_pin'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      isOutlier: json['is_outlier'] as bool?,
      capturedAt: json['captured_at'] == null
          ? null
          : DateTime.parse(json['captured_at'] as String),
    );

Map<String, dynamic> _$ScanPointToJson(ScanPoint instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'z': instance.z,
      'sequence_number': instance.sequenceNumber,
      'is_manual_pin': instance.isManualPin,
      'confidence': instance.confidence,
      'is_outlier': instance.isOutlier,
      'captured_at': instance.capturedAt?.toIso8601String(),
    };
