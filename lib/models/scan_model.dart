import 'dart:convert';

class ScanModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final double quality;
  final String? filePath;
  final bool isUploaded;
  final Map<String, dynamic>? metadata;

  ScanModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.quality,
    this.filePath,
    this.isUploaded = false,
    this.metadata,
  });

  factory ScanModel.fromJson(Map<String, dynamic> json) {
    return ScanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      quality: (json['quality'] as num).toDouble(),
      filePath: json['filePath'] as String?,
      isUploaded: (json['isUploaded'] as int) == 1,
      metadata: json['metadata'] != null
          ? jsonDecode(json['metadata'] as String) as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'quality': quality,
      'filePath': filePath,
      'isUploaded': isUploaded ? 1 : 0,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }

  ScanModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    double? quality,
    String? filePath,
    bool? isUploaded,
    Map<String, dynamic>? metadata,
  }) {
    return ScanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      quality: quality ?? this.quality,
      filePath: filePath ?? this.filePath,
      isUploaded: isUploaded ?? this.isUploaded,
      metadata: metadata ?? this.metadata,
    );
  }
}
