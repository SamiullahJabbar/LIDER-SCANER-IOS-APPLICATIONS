// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  email: json['email'] as String,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  phoneNumber: json['phone_number'] as String?,
  companyName: json['company_name'] as String?,
  jobTitle: json['job_title'] as String?,
  profilePicture: json['profile_picture'] as String?,
  storageQuotaGb: (json['storage_quota_gb'] as num).toInt(),
  storageUsedGb: (json['storage_used_gb'] as num?)?.toDouble(),
  storageAvailableGb: (json['storage_available_gb'] as num?)?.toDouble(),
  storageUsagePercentage: (json['storage_usage_percentage'] as num?)
      ?.toDouble(),
  isVerified: json['is_verified'] as bool,
  isActive: json['is_active'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  lastLoginAt: json['last_login_at'] == null
      ? null
      : DateTime.parse(json['last_login_at'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'email': instance.email,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'phone_number': instance.phoneNumber,
  'company_name': instance.companyName,
  'job_title': instance.jobTitle,
  'profile_picture': instance.profilePicture,
  'storage_quota_gb': instance.storageQuotaGb,
  'storage_used_gb': instance.storageUsedGb,
  'storage_available_gb': instance.storageAvailableGb,
  'storage_usage_percentage': instance.storageUsagePercentage,
  'is_verified': instance.isVerified,
  'is_active': instance.isActive,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'last_login_at': instance.lastLoginAt?.toIso8601String(),
};
