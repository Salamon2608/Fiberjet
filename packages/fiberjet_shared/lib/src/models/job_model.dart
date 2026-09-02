class JobModel {
  final String id;
  final String? customerId;
  final String? technicianId;
  final String type; // 'installation', 'repair', 'maintenance'
  final String status; // 'assigned', 'in_progress', 'completed', 'cancelled'
  final String? notes;
  final String? visitOtp;
  final bool isOtpVerified;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  JobModel({
    required this.id,
    this.customerId,
    this.technicianId,
    required this.type,
    required this.status,
    this.notes,
    this.visitOtp,
    this.isOtpVerified = false,
    this.scheduledAt,
    this.completedAt,
    required this.createdAt,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      technicianId: json['technician_id'] as String?,
      type: json['type'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      visitOtp: json['visit_otp'] as String?,
      isOtpVerified: json['is_otp_verified'] as bool? ?? false,
      scheduledAt: json['scheduled_at'] != null 
          ? DateTime.parse(json['scheduled_at'] as String) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'technician_id': technicianId,
      'type': type,
      'status': status,
      'notes': notes,
      'visit_otp': visitOtp,
      'is_otp_verified': isOtpVerified,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
