import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  final int id;
  final String username;
  final String email;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  @JsonKey(name: 'company_name')
  final String? companyName;
  @JsonKey(name: 'job_title')
  final String? jobTitle;
  @JsonKey(name: 'profile_picture')
  final String? profilePicture;
  @JsonKey(name: 'storage_quota_gb')
  final int storageQuotaGb;
  @JsonKey(name: 'storage_used_gb')
  final double? storageUsedGb;
  @JsonKey(name: 'storage_available_gb')
  final double? storageAvailableGb;
  @JsonKey(name: 'storage_usage_percentage')
  final double? storageUsagePercentage;
  @JsonKey(name: 'is_verified')
  final bool isVerified;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'last_login_at')
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.companyName,
    this.jobTitle,
    this.profilePicture,
    required this.storageQuotaGb,
    this.storageUsedGb,
    this.storageAvailableGb,
    this.storageUsagePercentage,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return username;
  }

  double get storageUsed {
    return storageUsedGb ?? 0.0;
  }

  double get storageAvailable {
    return storageAvailableGb ?? storageQuotaGb.toDouble();
  }

  double get storagePercentage {
    return storageUsagePercentage ?? 0.0;
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? companyName,
    String? jobTitle,
    String? profilePicture,
    int? storageQuotaGb,
    double? storageUsedGb,
    double? storageAvailableGb,
    double? storageUsagePercentage,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      companyName: companyName ?? this.companyName,
      jobTitle: jobTitle ?? this.jobTitle,
      profilePicture: profilePicture ?? this.profilePicture,
      storageQuotaGb: storageQuotaGb ?? this.storageQuotaGb,
      storageUsedGb: storageUsedGb ?? this.storageUsedGb,
      storageAvailableGb: storageAvailableGb ?? this.storageAvailableGb,
      storageUsagePercentage: storageUsagePercentage ?? this.storageUsagePercentage,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
