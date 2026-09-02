import '../enums.dart';

class UserModel {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String? passwordHash;
  final String? roleId;
  final Role role;
  final String status;
  final bool isVip;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    this.passwordHash,
    this.roleId,
    this.role = Role.customer,
    this.status = 'active',
    this.isVip = false,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString(),
      phone: json['phone']?.toString() ?? '',
      passwordHash: json['password_hash']?.toString(),
      roleId: json['role_id']?.toString(),
      role: json['role_name'] != null 
          ? Role.fromString(json['role_name'].toString()) 
          : Role.customer,
      status: json['status']?.toString() ?? 'active',
      isVip: json['is_vip'] == true,
      fcmToken: json['fcm_token']?.toString(),
      createdAt: json['created_at'] is DateTime 
          ? json['created_at'] as DateTime
          : (json['created_at'] != null 
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updated_at'] is DateTime
          ? json['updated_at'] as DateTime
          : (json['updated_at'] != null 
              ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      // Strip password_hash for security
      'role_id': roleId,
      'status': status,
      'is_vip': isVip,
      'fcm_token': fcmToken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
