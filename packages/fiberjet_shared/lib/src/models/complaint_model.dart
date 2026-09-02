class ComplaintModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String status; // 'pending', 'in_progress', 'resolved'
  final String priority; // 'low', 'medium', 'high'
  final String? visitOtp;
  final bool isOtpVerified;
  final DateTime? arrivedAt;
  final DateTime createdAt;

  ComplaintModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.visitOtp,
    this.isOtpVerified = false,
    this.arrivedAt,
    required this.createdAt,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Support Ticket',
      description: json['description'] as String,
      status: json['status'] as String,
      priority: json['priority'] as String? ?? 'medium',
      visitOtp: json['visit_otp'] as String?,
      isOtpVerified: json['is_otp_verified'] as bool? ?? false,
      arrivedAt: json['arrived_at'] != null 
          ? DateTime.tryParse(json['arrived_at'].toString()) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'visit_otp': visitOtp,
      'is_otp_verified': isOtpVerified,
      'arrived_at': arrivedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
