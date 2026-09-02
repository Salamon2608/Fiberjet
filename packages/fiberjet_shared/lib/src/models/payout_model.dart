class PayoutModel {
  final String id;
  final String userId;
  final double amount;
  final String status; // 'pending', 'approved', 'rejected'
  final String? approvedBy;
  final DateTime createdAt;

  PayoutModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.status,
    this.approvedBy,
    required this.createdAt,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> json) {
    return PayoutModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: json['amount'] is num 
          ? (json['amount'] as num).toDouble() 
          : (double.tryParse(json['amount']?.toString() ?? '') ?? 0.0),
      status: json['status'] as String,
      approvedBy: json['approved_by'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'status': status,
      'approved_by': approvedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
